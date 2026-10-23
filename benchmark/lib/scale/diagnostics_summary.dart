// Internal benchmark tooling, not a published library API.
// ignore_for_file: public_member_api_docs, type_annotate_public_apis

/// Matches endpoint timelines without subtracting clocks on different hosts.
/// Detailed records remain in events.jsonl; the in-memory report is bounded.
class DiagnosticsSummary {
  final _pending = <String, Map<String, Map<String, dynamic>>>{};
  final _slowest = <Map<String, dynamic>>[];
  final _rounds = <Map<String, dynamic>>[];
  final _batches = <Map<String, dynamic>>[];
  int _batchCount = 0;
  var paired = 0;
  var unmatchedEvicted = 0;
  var lostServerRecords = 0;
  var serverSamples = 0;
  var fanoutDeliveries = 0;
  var maxFanoutMicros = 0;
  final _instances = <String>{};

  void add(Map<String, dynamic> event) {
    switch (event['type']) {
      case 'syncBatchTrace':
        _batchCount++;
        if (event['side'] == 'server') {
          _batches
            ..add(event)
            ..sort(
              (a, b) => (b['acknowledgementWaitMicros'] as int).compareTo(
                a['acknowledgementWaitMicros'] as int,
              ),
            );
          if (_batches.length > 20) _batches.removeLast();
        }
      case 'syncTrace':
        if (event['once'] != true) return;
        final requestId = event['requestId'] as String;
        final pair = _pending.putIfAbsent(requestId, () => {});
        pair[event['side'] as String] = event;
        if (pair['server'] != null && pair['client'] != null) {
          _pending.remove(requestId);
          paired++;
          final server = pair['server']!;
          final client = pair['client']!;
          final timings = server['timings'] as Map;
          final transactions = server['transactionTotals'] as Map;
          final stages = server['stages'] as Map;
          final breakdown = <String, int>{
            'queueUserOrSpace': timings['queue.userOrSpace'] as int? ?? 0,
            'queueGlobalCapacity': timings['queue.globalCapacity'] as int? ?? 0,
            'connectionWaitAndBegin':
                transactions['connectionWaitAndBeginMicros'] as int? ?? 0,
            'transactionBody': transactions['bodyMicros'] as int? ?? 0,
            'commitOrRollbackAndRelease':
                transactions['commitOrRollbackAndReleaseMicros'] as int? ?? 0,
            'initialPeerWait': stages['handshake.waitForPeerConnect'] as int? ?? 0,
            'outboundCapture': timings['sync.outboundCapture'] as int? ?? 0,
            'inboundBatch': timings['sync.inboundBatch'] as int? ?? 0,
          };
          _slowest
            ..add({
              'requestId': requestId,
              'userId': client['userId'],
              'deviceId': client['deviceId'],
              'phase': client['phase'],
              'clientMicros': client['micros'],
              'serverMicros': server['micros'],
              'serverWorkerElapsedMicros': breakdown,
              'arrivalToDispatchMicros': server['arrivalToDispatchMicros'],
              'queueUserOrSpaceMicros': timings['queue.userOrSpace'] ?? 0,
              'queueGlobalCapacityMicros': timings['queue.globalCapacity'] ?? 0,
              'serverTransactions': server['transactionTotals'],
              'serverStages': server['stages'],
              'afterLastTransactionToLastYieldMicros':
                  server['afterLastTransactionToLastYieldMicros'],
              'clientStages': client['stages'],
              'clientTimings': client['timings'],
              'clientBatchesReceived': client['batchesReceived'],
              'serverBatchesReceived': server['batchesReceived'],
              'wire': client['wire'],
              'outcome': client['outcome'],
            })
            ..sort(
              (a, b) => (b['clientMicros'] as int).compareTo(a['clientMicros'] as int),
            );
          if (_slowest.length > 20) _slowest.removeLast();
        }
        while (_pending.length > 2048) {
          _pending.remove(_pending.keys.first);
          unmatchedEvicted++;
        }
      case 'verifyRound':
        _rounds.add({
          for (final key in [
            'user',
            'rounds',
            'roundMicros',
            'micros',
            'ok',
            'problems',
            'nextRoundReason',
            'backoffMicros',
          ])
            key: event[key],
        });
        _rounds.sort(
          (a, b) => (b['roundMicros'] as int).compareTo(a['roundMicros'] as int),
        );
        if (_rounds.length > 20) _rounds.removeLast();
      case 'serverDiagnosticsGap':
        lostServerRecords += event['lost'] as int;
      case 'serverProcess':
        serverSamples++;
        _instances.add(event['instanceId'] as String);
      case 'fanoutDelivery':
        fanoutDeliveries++;
        final micros = event['maxCommitToYieldMicros'] as int;
        if (micros > maxFanoutMicros) maxFanoutMicros = micros;
    }
  }

  Map<String, dynamic> toJson() => {
    'pairedOnceRequests': paired,
    'unpairedOnceRequests': _pending.length,
    'unmatchedEvicted': unmatchedEvicted,
    'lostServerRecords': lostServerRecords,
    'serverProcessSamples': serverSamples,
    'serverInstances': _instances.toList(),
    'slowestOnceRequests': _slowest,
    'acknowledgedBatchCount': _batchCount,
    'slowestServerBatches': _batches,
    'slowestVerifyRounds': _rounds,
    'fanoutDeliveries': fanoutDeliveries,
    'maxCommitToOtherStreamYieldMicros': maxFanoutMicros,
    'queuePolicy':
        'Per server instance: serialize same user or space, then a shared global concurrency limit. Different users can wait for capacity.',
    'measurementNotes': [
      'Connection wait includes BEGIN; commit/rollback includes connection release.',
      'SQL durations include driver/network/scheduling. Unattributed transaction body time is outside logged SQL, not necessarily CPU.',
      'Server stages partition endpoint time. Independent capture and merge spans overlap; queue and transaction measurements are nested. Worker sums do not partition wall time.',
      'Client and server clocks are independent. No one-way network latency is inferred by subtracting their timestamps.',
      'Payload bytes count application JSON only. Rows count distinct rows per chunk; retransmissions can be counted again.',
      'Fan-out uses local commit hints with periodic recovery. Delivery measurements end at server yield, not socket flush or client apply.',
      'Diagnostics retrieval is instance-local; multiple replicas require collecting each instance or central logs. Gaps and unmatched requests are reported.',
    ],
  };
}
