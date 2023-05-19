import 'dart:io';

import 'package:alex/src/exception/run_exception.dart';
import 'package:logging/logging.dart';
import 'package:meta/meta.dart';

class Cmd extends CmdBase {
  final bool immediatePrintStd;
  final bool immediatePrintErr;

  @override
  final Logger logger;

  Cmd({
    this.immediatePrintStd = true,
    this.immediatePrintErr = true,
    Logger? logger,
  }) : logger = logger ?? Logger('cmd');

  Future<ProcessResult> run(
    String cmd, {
    List<String> arguments = const [],
    String? workingDir,
    bool? immediatePrintStd,
    bool? immediatePrintErr,
  }) {
    immediatePrintStd ??= this.immediatePrintStd;
    immediatePrintErr ??= this.immediatePrintErr;

    return immediatePrintStd || immediatePrintErr
        ? runWithImmediatePrint(
            cmd,
            arguments,
            printStdOut: immediatePrintStd,
            printErrOut: immediatePrintErr,
            workingDir: workingDir,
          )
        : Process.run(cmd, arguments, workingDirectory: workingDir);
  }

  @protected
  Future<ProcessResult> runWithImmediatePrint(
    String executable,
    List<String> arguments, {
    bool? printStdOut,
    bool? printErrOut,
    String? workingDir,
  }) {
    printStdOut ??= immediatePrintStd;
    printErrOut ??= immediatePrintErr;

    return runAndListenOutput(
      executable,
      arguments,
      onOut: printStdOut ? (out) => logger.info(out.trimEndLine()) : null,
      onErr: printErrOut ? (err) => logger.severe(err.trimEndLine()) : null,
      workingDir: workingDir,
    );
  }

  /// Run command and add listeners `onOut`/`onErr` on
  /// std and err output.
  @protected
  Future<ProcessResult> runAndListenOutput(
    String executable,
    List<String> arguments, {
    void Function(String out)? onOut,
    void Function(String err)? onErr,
    String? workingDir,
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
}

abstract class CmdBase {
  Logger get logger;

  Future<ProcessResult> runOrFail(Future<ProcessResult> Function() run,
      {bool printStdOut = true}) async {
    final res = await run();

    final runOut = res.stdout?.toString();
    if (printStdOut && runOut != null && runOut.isNotEmpty) {
      logger.info(res.stdout.toString());
    }

    if (res.exitCode != 0) {
      throw RunException.withCode(res.exitCode, res.stderr.toString());
    }

    return res;
  }
}

extension _StringExtension on String {
  String trimEndLine() => endsWith('\n') ? substring(0, length - 1) : this;
}
