import 'dart:io';

import 'package:alex/alex.dart';
import 'package:alex/runner/alex_command.dart';
import 'package:alex/src/exception/run_exception.dart';
import 'package:meta/meta.dart';

/// Base command for localization feature.
abstract class L10nCommandBase extends AlexCommand {
  L10nCommandBase(String name, String description) : super(name, description);

  L10nConfig get l10nConfig => AlexConfig.instance.l10n;

  // TODO: move run "flutter pub run" in common utils
  @protected
  Future<ProcessResult> runIntl(String cmd, List<String> arguments) async {
    final executable = 'flutter';
    final args = ['pub', 'run', 'intl_translation:$cmd', ...arguments];

    printVerbose('Run: $executable ${args.join(" ")}');

    return Process.run(executable, args);
  }

  @protected
  Future<ProcessResult> runIntlOrFail(String cmd, List<String> arguments,
      {bool printStdOut = true}) async {
    final res = await runIntl(cmd, arguments);

    if (res.exitCode != 0) {
      throw RunException(res.exitCode, res.stderr.toString());
    }

    final runOut = res.stdout?.toString();
    if (printStdOut && runOut != null && runOut.isNotEmpty) {
      printInfo(res.stdout.toString());
    }

    return res;
  }
}
