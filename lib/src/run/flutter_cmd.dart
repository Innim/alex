import 'dart:io';

import 'package:alex/src/run/cmd.dart';
import 'package:logging/logging.dart';

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
    bool immediatePrintStd = true,
    bool immediatePrintErr = true,
    String? workingDir,
    bool prependWithPubGet = false,
  }) async {
    if (prependWithPubGet) {
      final pubGetRes = await pub('get', workingDir: workingDir);
      if (pubGetRes.exitCode != 0) return pubGetRes;
    }

    return pub(
      'run',
      arguments: [cmd, ...arguments],
      workingDir: workingDir,
    );
  }

  Future<ProcessResult> runPubOrFail(
    String cmd,
    List<String> arguments, {
    bool printStdOut = true,
    bool immediatePrint = true,
    bool prependWithPubGet = false,
  }) async {
    assert(printStdOut || !immediatePrint,
        "You can't disable std output if immediatePrint enabled");
    return runOrFail(
      () => runPub(
        cmd,
        arguments,
        immediatePrintStd: immediatePrint && printStdOut,
        immediatePrintErr: false,
        prependWithPubGet: prependWithPubGet,
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
      final res = await cmd.run(_fvmCmd(), arguments: ['--version']);

      if (res.exitCode == 0) {
        logger.info('Use FVM v${res.stdout}');
        return true;
      }
    } on ProcessException catch (e) {
      logger.fine('Failed: ${e.message} [code: ${e.errorCode}]');
    }

    logger.fine('No FVM');
    return false;
  }
}
