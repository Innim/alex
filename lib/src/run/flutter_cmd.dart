import 'dart:io';

import 'package:alex/src/run/cmd.dart';
import 'package:logging/logging.dart';

class FlutterCmd extends CmdBase {
  final Cmd cmd;
  final bool isVerbose;
  @override
  final Logger logger;

  FlutterCmd(
    this.cmd, {
    this.isVerbose = false,
    Logger? logger,
  }) : logger = logger ?? Logger('flutter');

  /// Runs `flutter pub` command.
  Future<ProcessResult> pub(
    String command, {
    List<String>? arguments,
    bool immediatePrintStd = true,
    bool immediatePrintErr = true,
    String? workingDir,
  }) async {
    final executable = _getPlatformSpecificExecutableName('flutter');
    final args = <String>[
      'pub',
      if (isVerbose) '-v',
      command,
      if (arguments != null) ...arguments,
    ];

    logger.fine('Run: $executable ${args.join(" ")}');

    return cmd.run(
      executable,
      arguments: args,
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
}
