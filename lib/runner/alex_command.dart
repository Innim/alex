import 'dart:io';

import 'package:alex/src/exception/run_exception.dart';
import 'package:alex/internal/print.dart' as print;
import 'package:args/args.dart';
import 'package:args/command_runner.dart';
import 'package:meta/meta.dart';

/// Базовый класс команды.
abstract class AlexCommand extends Command<int> {
  final String _name;
  final String _description;
  final ArgParser _argParser = ArgParser(
    allowTrailingOptions: false,
  )..addFlag('verbose', help: 'Show additional diagnostic info');

  AlexCommand(this._name, this._description);

  @override
  String get name => _name;

  @override
  ArgParser get argParser => _argParser;

  @override
  String get description => _description;

  bool get isVerbose => argResults['verbose'] as bool;

  /// Prints message if verbose flag is on.
  @protected
  void printVerbose(String message) {
    if (isVerbose) print.verbose(message);
  }

  /// Prints some info message in output.
  @protected
  void printInfo(String message) => print.info(message);

  /// Prints error message in error output.
  @protected
  void printError(String message) => print.error(message);

  /// Prints 0 code and prints a success message if provided.
  @protected
  int success({String message}) {
    if (message != null) printInfo(message);
    return 0;
  }

  /// Returns error code and prints a error message if provided.
  @protected
  int error(int code, {String message}) {
    if (message != null) printError(message);
    return code;
  }

  /// Returns error code by exception.
  @protected
  int errorBy(RunException exception) {
    assert(exception != null);
    return error(exception.exitCode, message: exception.message);
  }

  /// Run command and add listeners `onOut`/`onErr` on
  /// std and err output.
  @protected
  Future<ProcessResult> runAndListenOutput(
    String executable,
    List<String> arguments, {
    Function(String out) onOut,
    Function(String err) onErr,
    String workingDir,
  }) async {
    final stdout = StringBuffer();
    final stderr = StringBuffer();
    final process = await Process.start(executable, arguments,
        workingDirectory: workingDir);

    systemEncoding.decoder.bind(process.stdout).listen((event) {
      stdout.write(event);
      if (onOut != null) onOut(event);
    });
    systemEncoding.decoder.bind(process.stderr).listen((event) {
      stderr.write(event);
      if (onErr != null) onErr(event);
    });

    final exitCode = await process.exitCode;

    return ProcessResult(
        process.pid, exitCode, stdout.toString(), stderr.toString());
  }

  @protected
  Future<ProcessResult> runWithImmediatePrint(
      String executable, List<String> arguments,
      {bool printStdOut = true, bool printErrOut = true, String workingDir}) {
    assert(printStdOut != null);
    assert(printErrOut != null);
    return runAndListenOutput(
      executable,
      arguments,
      onOut: printStdOut ? (out) => printInfo(out.trimEndLine()) : null,
      onErr: printErrOut ? (err) => printError(err.trimEndLine()) : null,
      workingDir: workingDir,
    );
  }

  /// Runs `flutter pub run` command.
  @protected
  Future<ProcessResult> runPub(String cmd, List<String> arguments,
      {bool immediatePrintStd = true,
      bool immediatePrintErr = true,
      String workingDir}) async {
    assert(immediatePrintStd != null);
    assert(immediatePrintErr != null);
    final executable = _getPlatformSpecificExecutableName('flutter');
    final args = [
      'pub',
      if (isVerbose) '-v',
      'run',
      cmd,
      ...arguments,
    ];

    printVerbose('Run: $executable ${args.join(" ")}');

    return immediatePrintStd || immediatePrintErr
        ? runWithImmediatePrint(
            executable,
            args,
            printStdOut: immediatePrintStd,
            printErrOut: immediatePrintErr,
            workingDir: workingDir,
          )
        : Process.run(executable, args, workingDirectory: workingDir);
  }

  @protected
  Future<ProcessResult> runPubOrFail(String cmd, List<String> arguments,
      {bool printStdOut = true, bool immediatePrint = true}) async {
    assert(printStdOut || !immediatePrint,
        "You can't disable std output if immediatePrint enabled");
    return runOrFail(
        () => runPub(cmd, arguments,
            immediatePrintStd: immediatePrint && printStdOut,
            immediatePrintErr: false),
        printStdOut: !immediatePrint && printStdOut);
  }

  @protected
  Future<ProcessResult> runOrFail(Future<ProcessResult> Function() run,
      {bool printStdOut = true}) async {
    final res = await run();

    final runOut = res.stdout?.toString();
    if (printStdOut && runOut != null && runOut.isNotEmpty) {
      printInfo(res.stdout.toString());
    }

    if (res.exitCode != 0) {
      throw RunException(res.exitCode, res.stderr.toString());
    }

    return res;
  }

  String _getPlatformSpecificExecutableName(String name) {
    if (Platform.isWindows) {
      return '$name.bat';
    }

    return name;
  }
}

extension _StringExtension on String {
  String trimEndLine() => endsWith('\n') ? substring(0, length - 1) : this;
}
