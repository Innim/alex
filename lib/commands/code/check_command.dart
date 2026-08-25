import 'dart:convert';
import 'dart:io';

import 'package:alex/internal/print.dart' as print;
import 'package:alex/runner/alex_command.dart';
import 'package:alex/src/check/analyze_output_parser.dart';
import 'package:alex/src/check/check_report.dart';
import 'package:alex/src/check/output_filter.dart';
import 'package:alex/src/check/test_output_parser.dart';
import 'package:alex/src/check/test_run_result.dart';
import 'package:alex/src/config.dart';
import 'package:alex/src/fs/fs.dart';
import 'package:alex/src/pub_spec.dart';
import 'package:alex/src/version.dart';

import 'src/code_command_base.dart';

const _kBuildTargets = <String>['ios', 'apk', 'appbundle', 'web', 'macos'];

/// Maximum count of the analyzer issues to print in the text output.
const _kMaxPrintedIssues = 50;

/// Maximum count of the failed tests to print in the text output.
const _kMaxPrintedFailures = 20;

/// Maximum count of lines of a single test failure message to print.
const _kMaxPrintedFailureMessageLines = 12;

/// Command to run quality gates: analyze, tests and (optionally) build.
class CheckCommand extends CodeCommandBase {
  static const _argAnalyzeOnly = 'analyze-only';
  static const _argTestOnly = 'test-only';
  static const _argBuild = 'build';
  static const _argBuildTarget = 'build-target';
  static const _argFailFast = 'fail-fast';

  CheckCommand()
      : super(
          'check',
          'Run quality gates: analyze, tests and (optionally) a debug build.\n\n'
              'Output of the commands is filtered from a noise, '
              'a short verdict is printed for each gate.\n\n'
              'Exit code is 0 if all gates passed, '
              '$kExitCodeAnalyzeFailed if analyze failed, '
              '$kExitCodeTestFailed if tests failed, '
              '$kExitCodeBuildFailed if build failed. '
              'Other exit codes are used for errors.\n\n'
              'Arguments after `--` are passed to the test command, '
              'for example: alex code check -- test/some_test.dart',
        ) {
    argParser
      ..addFlag(
        _argAnalyzeOnly,
        help: 'Run the analyze gate only.',
        negatable: false,
      )
      ..addFlag(
        _argTestOnly,
        help: 'Run the test gate only.',
        negatable: false,
      )
      ..addFlag(
        _argBuild,
        help: 'Also run a debug build of the platform target.',
        negatable: false,
      )
      ..addOption(
        _argBuildTarget,
        help: 'Target for the build gate. '
            'By default the value of the `code.check.build_target` '
            'config option is used, or `ios` on macOS and `apk` on '
            'other platforms.',
        allowed: _kBuildTargets,
      )
      ..addFlag(
        _argFailFast,
        help: 'Stop on the first failed gate.',
        negatable: false,
      )
      ..addFormatOption()
      ..addVerboseFlutterCmdFlag();
  }

  late OutputFilter _filter;
  late bool _isFlutterProject;

  @override
  Future<int> doRun() async {
    final config = findConfigAndSetWorkingDir();
    final checkConfig = config.code.check;
    final args = argResults!;
    final isJson = args.isJsonFormat();

    final analyzeOnly = args[_argAnalyzeOnly] as bool;
    final testOnly = args[_argTestOnly] as bool;

    if (analyzeOnly && testOnly) {
      return error(2,
          message: 'You can not use --$_argAnalyzeOnly '
              'and --$_argTestOnly together.');
    }

    final needAnalyze = !testOnly;
    final needTest = !analyzeOnly;
    final needBuild = (args[_argBuild] as bool) && !analyzeOnly && !testOnly;
    final failFast = args[_argFailFast] as bool;

    _filter = OutputFilter(extraPatterns: checkConfig.noise);
    _isFlutterProject = await _checkIsFlutterProject();
    printVerbose('Project type: ${_isFlutterProject ? 'flutter' : 'dart'}');

    final gates = <CheckGateResult>[];

    Future<void> runGate(
      CheckGate gate,
      Future<CheckGateResult> Function() run, {
      required bool need,
      String skipReason = 'skipped',
    }) async {
      if (!need || (failFast && gates.any((g) => g.isFailed))) {
        gates.add(CheckGateResult.skipped(gate, summary: skipReason));
        return;
      }

      printInfo('Running ${gate.key}...');
      final result = await run();
      if (!isJson) _printGate(result);
      gates.add(result);
    }

    await runGate(CheckGate.analyze, _runAnalyze, need: needAnalyze);
    await runGate(CheckGate.test, _runTest, need: needTest);
    await runGate(
      CheckGate.build,
      () => _runBuild(
        args[_argBuildTarget] as String? ?? _defaultBuildTarget(checkConfig),
      ),
      need: needBuild,
    );

    final report = CheckReport(alexVersion: packageVersion, gates: gates);

    if (isJson) {
      print.result(jsonEncode(report.toJson()));
    } else {
      printInfo('');
      printInfo('=== alex code check: ${report.ok ? 'PASS' : 'FAIL'} ===');
      printInfo(report.summary);
    }

    return report.exitCode;
  }

  // region Gates

  Future<CheckGateResult> _runAnalyze() async {
    final stopwatch = Stopwatch()..start();
    final res = await _run(const ['analyze']);
    stopwatch.stop();

    final output = _mergeOutput(res);
    final result = AnalyzeOutputParser.parse(output);
    final isFailed = result.hasIssues || res.exitCode != 0;

    // If the command failed, but no issues were recognized -
    // it's a failure of the command itself, so the output should be shown.
    final hasUnexplainedFailure = isFailed && !result.hasIssues;

    return CheckGateResult(
      gate: CheckGate.analyze,
      status: isFailed ? CheckGateStatus.failed : CheckGateStatus.passed,
      durationMs: stopwatch.elapsedMilliseconds,
      summary: result.hasIssues
          ? '${result.count} issue(s)'
          : (isFailed ? 'failed' : 'no issues'),
      details: result.toJson(),
      output: hasUnexplainedFailure ? _filter.filterTail(output) : null,
    );
  }

  Future<CheckGateResult> _runTest() async {
    if (!Directory('test').existsSync()) {
      return const CheckGateResult.skipped(CheckGate.test,
          summary: 'skipped (no test directory)');
    }

    final rest = argResults!.rest;
    final hasCustomReporter = rest.any((a) => a.startsWith('--reporter'));

    final stopwatch = Stopwatch()..start();
    final res = await _run([
      'test',
      if (!hasCustomReporter) '--reporter=json',
      ...rest,
    ]);
    stopwatch.stop();

    final output = _mergeOutput(res);
    final result = hasCustomReporter
        ? const TestRunResult.unknown()
        : TestOutputParser.parse(res.stdout.toString());
    // If the output was not parsed - only the exit code can be relied on.
    final isFailed =
        res.exitCode != 0 || (!hasCustomReporter && !result.isSuccess);

    final String summary;
    if (!result.completed) {
      summary = isFailed ? 'failed (see output)' : 'done';
    } else {
      summary = [
        '${result.passed} passed',
        if (result.failed > 0) '${result.failed} failed',
        if (result.skipped > 0) '${result.skipped} skipped',
      ].join(', ');
    }

    return CheckGateResult(
      gate: CheckGate.test,
      status: isFailed ? CheckGateStatus.failed : CheckGateStatus.passed,
      durationMs: stopwatch.elapsedMilliseconds,
      summary: summary,
      details: result.toJson(),
      output: isFailed && result.failures.isEmpty
          ? _filter.filterTail(output)
          : null,
    );
  }

  Future<CheckGateResult> _runBuild(String target) async {
    if (!_isFlutterProject) {
      return const CheckGateResult.skipped(CheckGate.build,
          summary: 'skipped (not a flutter project)');
    }

    final stopwatch = Stopwatch()..start();
    final res = await _run(_buildArguments(target));
    stopwatch.stop();

    final isFailed = res.exitCode != 0;
    final output = _mergeOutput(res);

    return CheckGateResult(
      gate: CheckGate.build,
      status: isFailed ? CheckGateStatus.failed : CheckGateStatus.passed,
      durationMs: stopwatch.elapsedMilliseconds,
      summary: isFailed ? 'failed ($target)' : 'ok ($target)',
      details: <String, dynamic>{'target': target},
      output: isFailed ? _filter.filterTail(output) : null,
    );
  }

  List<String> _buildArguments(String target) {
    switch (target) {
      case 'ios':
        return const ['build', 'ios', '--debug', '--no-codesign'];
      case 'apk':
        return const ['build', 'apk', '--debug'];
      case 'appbundle':
        return const ['build', 'appbundle', '--debug'];
      case 'web':
        return const ['build', 'web'];
      case 'macos':
        return const ['build', 'macos', '--debug'];
      default:
        throw ArgumentError.value(target, 'target', 'Unknown build target');
    }
  }

  String _defaultBuildTarget(CodeCheckConfig config) =>
      config.buildTarget ?? (Platform.isMacOS ? 'ios' : 'apk');

  // endregion Gates

  // region Run

  Future<ProcessResult> _run(List<String> arguments) async {
    printVerbose('Run: ${arguments.join(' ')}');

    final ProcessResult res;
    if (_isFlutterProject) {
      res = await flutter.run(
        arguments.first,
        arguments: arguments.sublist(1),
        immediatePrintStd: false,
        immediatePrintErr: false,
      );
    } else {
      res = await cmd.run(
        'dart',
        arguments: arguments,
        immediatePrintStd: false,
        immediatePrintErr: false,
      );
    }

    if (isVerbose) {
      printVerbose('Exit code: ${res.exitCode}');
      final output = _mergeOutput(res);
      if (output.trim().isNotEmpty) printVerbose(output);
    }

    return res;
  }

  String _mergeOutput(ProcessResult res) {
    final out = res.stdout?.toString() ?? '';
    final err = res.stderr?.toString() ?? '';
    if (err.trim().isEmpty) return out;
    if (out.trim().isEmpty) return err;
    return '$out\n$err';
  }

  Future<bool> _checkIsFlutterProject() async {
    try {
      final spec = await Spec.pub(const IOFileSystem());
      return spec.dependsOn('flutter');
    } on Object catch (e) {
      printVerbose("Can't detect a project type: $e");
      return true;
    }
  }

  // endregion Run

  // region Text output

  void _printGate(CheckGateResult gate) {
    final duration = gate.durationMs != null
        ? ' [${(gate.durationMs! / 1000).toStringAsFixed(1)}s]'
        : '';
    printInfo('${gate.gate.key}: ${_statusLabel(gate.status)} - '
        '${gate.summary}$duration');

    switch (gate.gate) {
      case CheckGate.analyze:
        _printAnalyzeIssues(gate);
        break;
      case CheckGate.test:
        _printTestFailures(gate);
        break;
      case CheckGate.build:
        break;
    }

    final output = gate.output;
    if (output != null && output.trim().isNotEmpty) printInfo(output);
  }

  String _statusLabel(CheckGateStatus status) {
    switch (status) {
      case CheckGateStatus.passed:
        return 'OK';
      case CheckGateStatus.failed:
        return 'FAILED';
      case CheckGateStatus.skipped:
        return 'SKIPPED';
    }
  }

  void _printAnalyzeIssues(CheckGateResult gate) {
    final issues = gate.details?['issues'] as List<dynamic>? ?? const [];
    if (issues.isEmpty) return;

    final printed = issues.take(_kMaxPrintedIssues);
    for (final issue in printed) {
      final data = issue as Map<String, dynamic>;
      final rule = data['rule'] as String?;
      printInfo('  ${data['severity']} - '
          '${data['file']}:${data['line']}:${data['column']} - '
          '${data['message']}'
          '${rule != null ? ' - $rule' : ''}');
    }

    final rest = issues.length - printed.length;
    if (rest > 0) printInfo('  ... and $rest more issue(s)');
  }

  void _printTestFailures(CheckGateResult gate) {
    final failures = gate.details?['failures'] as List<dynamic>? ?? const [];
    if (failures.isEmpty) return;

    final printed = failures.take(_kMaxPrintedFailures);
    for (final failure in printed) {
      final data = failure as Map<String, dynamic>;
      final suite = data['suite'] as String?;
      printInfo('  FAILED: ${data['name']}'
          '${suite != null ? ' ($suite)' : ''}');

      final message = data['message'] as String?;
      if (message != null && message.trim().isNotEmpty) {
        final lines = message.trim().split('\n');
        final visible = lines.take(_kMaxPrintedFailureMessageLines);
        for (final line in visible) {
          printInfo('      $line');
        }
        if (lines.length > visible.length) {
          printInfo('      ... ${lines.length - visible.length} line(s) more');
        }
      }
    }

    final rest = failures.length - printed.length;
    if (rest > 0) printInfo('  ... and $rest more failed test(s)');
  }

// endregion Text output
}
