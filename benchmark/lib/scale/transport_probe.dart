// Internal benchmark tooling, not a published library API.
// ignore_for_file: public_member_api_docs

/// A regular Serverpod method stream with no database or Offline Sync work.
class TransportProbe {
  int opened = 0;
  int closed = 0;
  int messages = 0;

  Stream<String> echo(Stream<String> input) async* {
    opened++;
    try {
      yield* input.map((message) {
        messages++;
        return message;
      });
    } finally {
      closed++;
    }
  }

  Map<String, int> sample() => {
    'open': opened - closed,
    'openedTotal': opened,
    'closedTotal': closed,
    'messagesTotal': messages,
  };
}
