/// Failed test.
class TestFailure {
  final String name;
  final String? suite;
  final String? message;

  /// `true` if it's a failure of the suite loading (compilation error)
  /// and not of a test itself.
  final bool isLoadFailure;

  const TestFailure({
    required this.name,
    this.suite,
    this.message,
    this.isLoadFailure = false,
  });

  Map<String, dynamic> toJson() => <String, dynamic>{
        'name': name,
        if (suite != null) 'suite': suite,
        if (message != null) 'message': message,
        if (isLoadFailure) 'loadFailure': true,
      };

  @override
  String toString() => suite != null ? '$name ($suite)' : name;
}

/// Result of the tests run.
class TestRunResult {
  final int passed;
  final int failed;
  final int skipped;
  final List<TestFailure> failures;

  /// `true` if the run was completed (the `done` event was received).
  ///
  /// `false` means that the test runner has crashed or its output
  /// was not recognized.
  final bool completed;

  const TestRunResult({
    required this.passed,
    required this.failed,
    required this.skipped,
    this.failures = const [],
    this.completed = true,
  });

  /// Result for a run without any recognized output.
  const TestRunResult.unknown()
      : passed = 0,
        failed = 0,
        skipped = 0,
        failures = const [],
        completed = false;

  int get total => passed + failed + skipped;

  bool get isSuccess => completed && failed == 0;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'passed': passed,
        'failed': failed,
        'skipped': skipped,
        'total': total,
        'completed': completed,
        'failures': failures.map((f) => f.toJson()).toList(),
      };
}
