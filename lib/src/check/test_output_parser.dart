import 'dart:convert';

import 'package:alex/src/check/test_run_result.dart';

/// Parser of the `flutter test --reporter=json` output.
///
/// See the format description in the `package:test` documentation:
/// each line of the output is a JSON object with an event.
class TestOutputParser {
  /// Maximum count of lines of a failure message to keep.
  ///
  /// Messages of the failed tests can be huge (a diff, a long stack trace),
  /// and the report is expected to be readable - both for a human
  /// and for a machine.
  static const maxMessageLines = 30;

  const TestOutputParser._();

  /// Parses the test runner [output].
  static TestRunResult parse(String output) {
    final suites = <int, String>{};
    final tests = <int, _TestInfo>{};
    final errors = <int, String>{};

    var passed = 0;
    var failed = 0;
    var skipped = 0;
    var completed = false;
    var hasEvents = false;

    final failures = <TestFailure>[];

    for (final line in output.split('\n')) {
      final event = _decode(line);
      if (event == null) continue;
      hasEvents = true;

      switch (event['type'] as String?) {
        case 'suite':
          final suite = event['suite'] as Map<String, dynamic>?;
          final id = suite?['id'] as int?;
          final path = suite?['path'] as String?;
          if (id != null && path != null) suites[id] = path;
          break;
        case 'testStart':
          final test = event['test'] as Map<String, dynamic>?;
          final id = test?['id'] as int?;
          if (id == null) break;
          tests[id] = _TestInfo(
            name: test?['name'] as String? ?? 'unknown',
            suiteId: test?['suiteID'] as int?,
          );
          break;
        case 'error':
          final id = event['testID'] as int?;
          if (id == null) break;
          final error = (event['error'] as String?)?.trim();
          if (error != null && error.isNotEmpty) {
            errors.putIfAbsent(id, () => _trimMessage(error));
          }
          break;
        case 'testDone':
          final id = event['testID'] as int?;
          if (id == null) break;

          final isHidden = event['hidden'] as bool? ?? false;
          final isSkipped = event['skipped'] as bool? ?? false;
          final result = event['result'] as String? ?? 'success';
          final isSuccess = result == 'success';

          if (isSuccess) {
            // Hidden tests are internal (suite loading), don't count them.
            if (isHidden) break;
            if (isSkipped) {
              skipped++;
            } else {
              passed++;
            }
            break;
          }

          failed++;

          final info = tests[id];
          final suiteId = info?.suiteId;
          failures.add(TestFailure(
            name: info?.name ?? 'unknown',
            suite: suiteId != null ? suites[suiteId] : null,
            message: errors[id],
            isLoadFailure: isHidden,
          ));
          break;
        case 'done':
          completed = true;
          break;
      }
    }

    if (!hasEvents) return const TestRunResult.unknown();

    return TestRunResult(
      passed: passed,
      failed: failed,
      skipped: skipped,
      failures: failures,
      completed: completed,
    );
  }

  static String _trimMessage(String message) {
    final lines = message.split('\n');
    if (lines.length <= maxMessageLines) return message;

    return [
      ...lines.take(maxMessageLines),
      '... ${lines.length - maxMessageLines} line(s) more',
    ].join('\n');
  }

  static Map<String, dynamic>? _decode(String line) {
    final value = line.trim();
    if (!value.startsWith('{') || !value.endsWith('}')) return null;

    try {
      final decoded = jsonDecode(value);
      return decoded is Map<String, dynamic> ? decoded : null;
    } on FormatException catch (_) {
      return null;
    }
  }
}

class _TestInfo {
  final String name;
  final int? suiteId;

  const _TestInfo({required this.name, this.suiteId});
}
