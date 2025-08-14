import 'dart:io';

import 'package:alex/src/run/cmd.dart';
import 'package:logging/logging.dart';

const _kDefaultIgnorePubGetOutput = true;

class FlutterCmd extends CmdBase {
  final Cmd cmd;
  final bool isVerbose;
  @override
  final Logger logger;

  bool? _hasFvm;

  FlutterCmd(
    this.cmd, {
    this.isVerbose = false,
    Logger? logger,
  }) : logger = logger ?? Logger('flutter');

  /// Runs `flutter` command.
  Future<ProcessResult> run(
    String command, {
    List<String>? arguments,
    bool immediatePrintStd = true,
    bool immediatePrintErr = true,
    String? workingDir,
  }) async {
    const flutter = 'flutter';

    final String executable;
    final args = <String>[];

    final hasFvm = _hasFvm ??= await _checkIfHasFvm();
    if (hasFvm) {
      executable = _fvmCmd();
      args.add(flutter);
    } else {
      executable = _getPlatformSpecificExecutableName(flutter);
    }

    if (isVerbose) args.add('-v');
    args.add(command);
    if (arguments != null) args.addAll(arguments);

    logger.fine('Run: $executable ${args.join(" ")}');

    return cmd.run(
      executable,
      arguments: args,
      workingDir: workingDir,
      immediatePrintStd: immediatePrintStd,
      immediatePrintErr: immediatePrintErr,
    );
  }

  Future<ProcessResult> runCmdOrFail(
    String cmd, {
    List<String>? arguments,
    bool printStdOut = true,
    bool immediatePrint = true,
  }) async {
    assert(printStdOut || !immediatePrint,
        "You can't disable std output if immediatePrint enabled");
    return runOrFail(
      () => run(
        cmd,
        arguments: arguments,
        immediatePrintStd: immediatePrint && printStdOut,
        immediatePrintErr: false,
      ),
      printStdOut: !immediatePrint && printStdOut,
    );
  }

  /// Runs `flutter pub` command.
  Future<ProcessResult> pub(
    String command, {
    List<String>? arguments,
    bool immediatePrintStd = true,
    bool immediatePrintErr = true,
    String? workingDir,
  }) async {
    return run(
      'pub',
      arguments: <String>[
        // if (isVerbose) '-v',
        command,
        if (arguments != null) ...arguments,
      ],
      workingDir: workingDir,
      immediatePrintStd: immediatePrintStd,
      immediatePrintErr: immediatePrintErr,
    );
  }

  Future<ProcessResult> pubOrFail(
    String cmd, {
    List<String>? arguments,
    bool printStdOut = true,
    bool immediatePrint = true,
  }) async {
    assert(printStdOut || !immediatePrint,
        "You can't disable std output if immediatePrint enabled");
    return runOrFail(
      () => pub(
        cmd,
        arguments: arguments,
        immediatePrintStd: immediatePrint && printStdOut,
        immediatePrintErr: false,
      ),
      printStdOut: !immediatePrint && printStdOut,
    );
  }

  Future<ProcessResult> pubGetOrFail({
    String? path,
    bool printStdOut = true,
    bool immediatePrint = true,
  }) async {
    assert(printStdOut || !immediatePrint,
        "You can't disable std output if immediatePrint enabled");
    return pubOrFail(
      'get',
      arguments: path != null ? [path] : null,
      printStdOut: printStdOut,
      immediatePrint: immediatePrint,
    );
  }

  /// Runs `flutter pub run` command.
  Future<ProcessResult> runPub(
    String cmd,
    List<String> arguments, {
    required String? title,
    bool immediatePrintStd = true,
    bool immediatePrintErr = true,
    String? workingDir,
    bool prependWithPubGet = false,
    bool ignorePubGetOutput = _kDefaultIgnorePubGetOutput,
  }) async {
    if (prependWithPubGet) {
      final printStdOut = !ignorePubGetOutput || isVerbose;
      logger.info('Getting dependencies...');

      final pubGetRes = await pub(
        'get',
        workingDir: workingDir,
        immediatePrintStd: immediatePrintStd && printStdOut,
        immediatePrintErr: immediatePrintErr,
      );

      if (printStdOut && !immediatePrintStd) {
        logger.info(pubGetRes.stdout.toString());
      }

      if (pubGetRes.exitCode != 0) return pubGetRes;

      logger.info('Dependencies - OK');
    }

    if (title != null) {
      logger.info(title);
    }

    return pub(
      'run',
      arguments: [cmd, ...arguments],
      workingDir: workingDir,
      immediatePrintStd: immediatePrintStd,
      immediatePrintErr: immediatePrintErr,
    );
  }

  Future<ProcessResult> runPubOrFail(
    String cmd,
    List<String> arguments, {
    required String? title,
    bool printStdOut = true,
    bool immediatePrint = true,
    bool prependWithPubGet = false,
    bool ignorePubGetOutput = _kDefaultIgnorePubGetOutput,
  }) async {
    assert(printStdOut || !immediatePrint,
        "You can't disable std output if immediatePrint enabled");
    return runOrFail(
      () => runPub(
        cmd,
        arguments,
        title: title,
        immediatePrintStd: immediatePrint && printStdOut,
        immediatePrintErr: false,
        prependWithPubGet: prependWithPubGet,
        ignorePubGetOutput: ignorePubGetOutput,
      ),
      printStdOut: !immediatePrint && printStdOut,
    );
  }

  String _getPlatformSpecificExecutableName(String name) {
    if (Platform.isWindows) {
      return '$name.bat';
    }

    return name;
  }

  String _fvmCmd() => _getPlatformSpecificExecutableName('fvm');

  Future<bool> _checkIfHasFvm() async {
    logger.fine('Checking FVM');

    try {
      final res = await cmd.run(
        _fvmCmd(),
        arguments: ['--version'],
        immediatePrintStd: false,
        immediatePrintErr: false,
      );

      if (res.exitCode == 0) {
        final version = res.stdout.trim();
        logger.info('Use FVM v$version');
        return true;
      } else {
        logger.fine('Failed: ${res.stderr} [code: ${res.exitCode}]');
      }
    } on ProcessException catch (e) {
      logger.fine('Failed: ${e.message} [code: ${e.errorCode}]');
    }

    logger.fine('No FVM');
    return false;
  }
}
