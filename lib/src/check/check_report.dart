/// Exit code if the analyze gate failed.
const kExitCodeAnalyzeFailed = 10;

/// Exit code if the test gate failed.
const kExitCodeTestFailed = 11;

/// Exit code if the build gate failed.
const kExitCodeBuildFailed = 12;

/// Quality gate of the `alex code check` command.
enum CheckGate {
  analyze('analyze', kExitCodeAnalyzeFailed),
  test('test', kExitCodeTestFailed),
  build('build', kExitCodeBuildFailed);

  final String key;

  /// Exit code of the command if this gate failed.
  final int failureExitCode;

  const CheckGate(this.key, this.failureExitCode);
}

/// Status of a quality gate.
enum CheckGateStatus {
  passed,
  failed,
  skipped;

  bool get isFailed => this == CheckGateStatus.failed;
}

/// Result of a single quality gate.
class CheckGateResult {
  final CheckGate gate;
  final CheckGateStatus status;

  /// Duration of the gate run in milliseconds, `null` if it was skipped.
  final int? durationMs;

  /// Short human readable summary, for example `2 issues`.
  final String summary;

  /// Gate specific data.
  final Map<String, dynamic>? details;

  /// Output of the failed command (filtered from noise).
  ///
  /// Provided only if there is no structured [details] to explain a failure.
  final String? output;

  const CheckGateResult({
    required this.gate,
    required this.status,
    required this.summary,
    this.durationMs,
    this.details,
    this.output,
  });

  const CheckGateResult.skipped(this.gate, {this.summary = 'skipped'})
      : status = CheckGateStatus.skipped,
        durationMs = null,
        details = null,
        output = null;

  bool get isFailed => status.isFailed;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'name': gate.key,
        'status': status.name,
        'summary': summary,
        if (durationMs != null) 'durationMs': durationMs,
        if (details != null) ...details!,
        if (output != null) 'output': output,
      };
}

/// Report of the `alex code check` run.
class CheckReport {
  /// Version of alex.
  final String alexVersion;

  /// Results of the gates in the order of the run.
  final List<CheckGateResult> gates;

  const CheckReport({
    required this.alexVersion,
    required this.gates,
  });

  /// `true` if no gate failed.
  bool get ok => gates.every((g) => !g.isFailed);

  /// Exit code of the command: a code of the first failed gate or `0`.
  int get exitCode {
    for (final gate in gates) {
      if (gate.isFailed) return gate.gate.failureExitCode;
    }
    return 0;
  }

  /// Short summary of all gates, for example
  /// `analyze: 2 issues | test: 40 passed | build: skipped`.
  String get summary =>
      gates.map((g) => '${g.gate.key}: ${g.summary}').join(' | ');

  Map<String, dynamic> toJson() => <String, dynamic>{
        'alex': alexVersion,
        'command': 'code check',
        'ok': ok,
        'exitCode': exitCode,
        'summary': summary,
        'gates': gates.map((g) => g.toJson()).toList(),
      };
}
