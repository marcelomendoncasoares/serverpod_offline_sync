// Comparison of the current report against the last benchmark note on main.
//
// CI stores every benchmark report as a git note (refs/notes/benchmarks, see
// .github/workflows/ci.yaml). This module loads the note of the most recent
// main commit that has one and appends a delta to each metric line of the
// current report, so the evolution against main is visible at a glance.

import 'dart:io';

import 'conversion.dart';

/// The benchmark report stored as a git note on the latest annotated commit
/// reachable from the main branch.
class BaselineNote {
  const BaselineNote({required this.commit, required this.text});

  final String commit;
  final String text;

  String get shortCommit => commit.substring(0, 7);

  /// Walks main from its tip and returns the first benchmark note found,
  /// fetching the notes ref when it is not available locally. Returns null
  /// when no main ref or note can be resolved (e.g. offline on a fresh clone).
  static Future<BaselineNote?> load() async {
    const notesRef = 'refs/notes/benchmarks';

    String? mainRef;
    for (final ref in const [
      'upstream/HEAD',
      'upstream/main',
      'origin/HEAD',
      'origin/main',
      'main',
    ]) {
      if (await _git(['rev-parse', '--verify', '--quiet', ref]) != null) {
        mainRef = ref;
        break;
      }
    }
    if (mainRef == null) return null;

    if (await _git(['rev-parse', '--verify', '--quiet', notesRef]) == null) {
      final remote = mainRef.contains('/') ? mainRef.split('/').first : 'origin';
      await _git(['fetch', remote, '$notesRef:$notesRef']);
    }

    final notesList = await _git(['notes', '--ref=benchmarks', 'list']);
    if (notesList == null || notesList.isEmpty) return null;
    final annotatedCommits = {
      for (final line in notesList.split('\n')) line.split(' ').last,
    };

    final commits = await _git(['rev-list', '--max-count=100', mainRef]);
    if (commits == null || commits.isEmpty) return null;

    for (final commit in commits.split('\n')) {
      if (!annotatedCommits.contains(commit)) continue;
      final text = await _git(['notes', '--ref=benchmarks', 'show', commit]);
      if (text != null) return BaselineNote(commit: commit, text: text);
    }
    return null;
  }

  static Future<String?> _git(List<String> args) async {
    try {
      final result = await Process.run(
        'git',
        args,
        environment: {'GIT_TERMINAL_PROMPT': '0'},
      );
      if (result.exitCode != 0) return null;
      return (result.stdout as String).trim();
    } on ProcessException {
      return null;
    }
  }
}

/// Prints report lines, appending a `[Δ ...]` annotation to every metric line
/// that also appears in the [baseline] note.
///
/// Deltas are relative changes, except for metrics that are themselves
/// percentages, which use percentage points (pp). Lines are matched by their
/// section headers and label, so a baseline produced with a different row
/// count (different `##` headers) yields no deltas.
class BenchmarkReport {
  BenchmarkReport(this.baseline) {
    for (final line in (baseline?.text ?? '').split('\n')) {
      final metric = _baselineContext.process(line);
      if (metric != null) _baselineMetrics[metric.key] = metric;
    }
  }

  final BaselineNote? baseline;
  final _baselineContext = _ReportContext();
  final _currentContext = _ReportContext();
  final _baselineMetrics = <String, _Metric>{};

  bool get hasBaseline => _baselineMetrics.isNotEmpty;

  /// Prints [text], annotating each metric line with its delta vs baseline.
  void print(String text) {
    for (final line in text.split('\n')) {
      final metric = _currentContext.process(line);
      final reference = _baselineMetrics[metric?.key];
      final delta = metric == null || reference == null
          ? null
          : _formatDelta(metric, reference);
      stdout.writeln(delta == null ? line : '$line [Δ $delta]');
    }
  }

  String? _formatDelta(_Metric current, _Metric reference) {
    if (current.kind != reference.kind) return null;
    if (current.kind == _UnitKind.percent) {
      return '${_signed(current.value - reference.value)}pp';
    }
    if (reference.value == 0) return null;
    final change = (current.value - reference.value) / reference.value.abs() * 100;
    return '${_signed(change)}%';
  }

  String _signed(double value) =>
      '${value < 0 ? '-' : '+'}${formatter2.format(value.abs())}';
}

enum _UnitKind { time, storage, percent, count }

class _Metric {
  const _Metric({required this.key, required this.value, required this.kind});

  final String key;
  final double value;
  final _UnitKind kind;
}

/// Tracks the section headers seen so far so metric lines can be keyed
/// identically when parsing the baseline note and the current report.
class _ReportContext {
  String? _header;
  String? _section;
  String? _subsection;

  static final _deltaSuffix = RegExp(r'\s*\[Δ[^\]]*\]\s*$');
  static final _metricLine = RegExp(r'^\s+([^:]+):\s+(\S.*)$');
  static final _numberWithUnit = RegExp(
    r'([+-]?\d[\d,]*(?:\.\d+)?)\s?(μs|ms|min|h|s|MB|KB|B|%)?(?=[\s).,]|$)',
  );

  /// Updates the section context with [rawLine] and returns the parsed metric
  /// when the line is a comparable `label: value` report line.
  _Metric? process(String rawLine) {
    final line = rawLine.replaceFirst(_deltaSuffix, '');
    final trimmed = line.trim();
    if (trimmed.isEmpty || trimmed == '```') return null;

    if (trimmed.startsWith('## ')) {
      _header = trimmed;
      _section = null;
      _subsection = null;
      return null;
    }

    const sectionMarkers = ['📊', '💽', '🔀'];
    if (sectionMarkers.any(trimmed.startsWith)) {
      _section = trimmed;
      _subsection = null;
      return null;
    }

    final metricMatch = _metricLine.firstMatch(line);
    if (metricMatch == null) {
      if (line.startsWith('  ') && trimmed.endsWith(':')) {
        _subsection = trimmed;
      }
      return null;
    }

    final label = metricMatch.group(1)!.trim();
    if (label.startsWith('-') || label == 'Batch') return null;

    final numbers = _numberWithUnit.allMatches(metricMatch.group(2)!);
    if (numbers.isEmpty) return null;

    // The last number of the line is its primary metric (e.g. the overhead
    // in "Time: 11.51 ms --> 11.61 ms (93.17 μs)").
    final number = numbers.last;
    final value = double.parse(number.group(1)!.replaceAll(',', ''));
    final (kind, factor) = switch (number.group(2)) {
      'μs' => (_UnitKind.time, 1),
      'ms' => (_UnitKind.time, Duration.microsecondsPerMillisecond),
      's' => (_UnitKind.time, Duration.microsecondsPerSecond),
      'min' => (_UnitKind.time, Duration.microsecondsPerMinute),
      'h' => (_UnitKind.time, Duration.microsecondsPerHour),
      'B' => (_UnitKind.storage, 1),
      'KB' => (_UnitKind.storage, 1024),
      'MB' => (_UnitKind.storage, 1024 * 1024),
      '%' => (_UnitKind.percent, 1),
      _ => (_UnitKind.count, 1),
    };

    return _Metric(
      key: [_header, _section, _subsection, label].join(' | '),
      value: value * factor,
      kind: kind,
    );
  }
}
