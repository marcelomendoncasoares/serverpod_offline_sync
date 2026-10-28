import argparse
import asyncio
import json
import signal
import ssl
import struct

parser = argparse.ArgumentParser()
parser.add_argument('--listen-port', type=int, required=True)
parser.add_argument('--database-port', type=int, required=True)
parser.add_argument('--delay-ms', type=float, required=True)
parser.add_argument('--cert', required=True)
parser.add_argument('--key', required=True)
args = parser.parse_args()
ssl_context = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
ssl_context.load_cert_chain(args.cert, args.key)
counts = {'connections': 0, 'databaseResponseChunks': 0, 'databaseResponseBytes': 0}


async def relay(reader, writer, delay):
    queue = asyncio.Queue(maxsize=64)
    loop = asyncio.get_running_loop()

    async def receive():
        try:
            while data := await reader.read(65536):
                if delay:
                    counts['databaseResponseChunks'] += 1
                    counts['databaseResponseBytes'] += len(data)
                # Timestamp arrival before waiting for buffer space. Chunks
                # received together share a deadline instead of accumulating
                # one extra delay per read() call.
                await queue.put((loop.time() + delay, data))
        finally:
            await queue.put(None)

    receiving = asyncio.create_task(receive())
    try:
        while entry := await queue.get():
            deadline, data = entry
            remaining = deadline - loop.time()
            if remaining > 0:
                await asyncio.sleep(remaining)
            writer.write(data)
            await writer.drain()
    finally:
        receiving.cancel()
        await asyncio.gather(receiving, return_exceptions=True)
        writer.close()
        try:
            await writer.wait_closed()
        except (ConnectionError, OSError):
            pass


async def connection(reader, writer):
    counts['connections'] += 1
    request = await reader.readexactly(8)
    if request != struct.pack('!II', 8, 80877103):
        writer.close()
        await writer.wait_closed()
        return
    writer.write(b'S')
    await writer.drain()
    await writer.start_tls(ssl_context)
    upstream_reader, upstream_writer = await asyncio.open_connection('127.0.0.1', args.database_port)
    tasks = [asyncio.create_task(relay(reader, upstream_writer, 0)),
             asyncio.create_task(relay(upstream_reader, writer, args.delay_ms / 1000))]
    try:
        await asyncio.gather(*tasks)
    except (ConnectionError, OSError):
        for task in tasks:
            task.cancel()
        await asyncio.gather(*tasks, return_exceptions=True)


async def main():
    stop = asyncio.Event()
    loop = asyncio.get_running_loop()
    for sig in [signal.SIGTERM, signal.SIGINT]:
        loop.add_signal_handler(sig, stop.set)
    server = await asyncio.start_server(connection, '127.0.0.1', args.listen_port)
    print(json.dumps({'ready': True, 'delayFromDatabaseResponseArrivalMs': args.delay_ms}), flush=True)
    async with server:
        await stop.wait()
    print(json.dumps(counts), flush=True)


asyncio.run(main())
