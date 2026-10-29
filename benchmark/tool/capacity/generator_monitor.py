import os
import signal
import threading
import time
from pathlib import Path


class GeneratorMonitor:
    """Read-only process-group samples; abort this client on host memory pressure."""

    def __init__(self):
        self.samples = []
        self.errors = []
        self.guard_reason = None
        self.done = threading.Event()
        self.thread = None

    def start(self, process_group):
        self.process_group = process_group
        self.thread = threading.Thread(target=self._collect, daemon=True)
        self.thread.start()

    def _collect(self):
        while not self.done.is_set():
            try:
                processes = []
                for path in Path('/proc').glob('[0-9]*/stat'):
                    try:
                        content = path.read_text()
                        fields = content[content.rfind(')') + 2:].split()
                        if int(fields[2]) != self.process_group:
                            continue
                        processes.append({
                            'pid': int(path.parent.name),
                            'startTicks': int(fields[19]),
                            'cpuTicks': int(fields[11]) + int(fields[12]),
                            'rssBytes': int(fields[21]) * os.sysconf('SC_PAGE_SIZE'),
                        })
                    except (FileNotFoundError, ProcessLookupError, PermissionError):
                        continue

                memory = {}
                for line in Path('/proc/meminfo').read_text().splitlines():
                    key, value = line.split(':', 1)
                    if key in ['MemAvailable', 'SwapTotal', 'SwapFree']:
                        memory[key + 'Bytes'] = int(value.split()[0]) * 1024

                self.samples.append({
                    'monotonicSeconds': time.clock_gettime(time.CLOCK_MONOTONIC_RAW),
                    'processes': processes,
                    'sumRssBytes': sum(p['rssBytes'] for p in processes),
                    **memory,
                })
                if memory.get('MemAvailableBytes', 2**63) < 4 * 1024**3 and not self.guard_reason:
                    self.guard_reason = 'Generator host has less than 4 GiB available memory'
                    try:
                        os.killpg(self.process_group, signal.SIGTERM)
                    except ProcessLookupError:
                        pass
            except Exception as error:
                self.errors.append(str(error))

            self.done.wait(1)

    def stop(self):
        self.done.set()
        if self.thread:
            self.thread.join(timeout=5)

    def summary(self):
        available = [s['MemAvailableBytes'] for s in self.samples if 'MemAvailableBytes' in s]
        return {
            'samples': len(self.samples),
            'peakSumRssBytes': max((s['sumRssBytes'] for s in self.samples), default=None),
            'minimumHostAvailableBytes': min(available, default=None),
            'guardReason': self.guard_reason,
            'errors': self.errors,
            'note': 'Sum of process RSS can count shared memory more than once.',
        }
