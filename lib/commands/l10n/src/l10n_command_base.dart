import 'dart:io';

import 'package:alex/alex.dart';
import 'package:alex/runner/alex_command.dart';
import 'package:meta/meta.dart';

/// Base command for localization feature.
abstract class L10nCommandBase extends AlexCommand {
  L10nCommandBase(String name, String description) : super(name, description);

  L10nConfig get l10nConfig => AlexConfig.instance.l10n;

  @protected
  Future<ProcessResult> runIntl(String cmd, List<String> arguments) async {
    return runPub('intl_translation:$cmd', arguments);
  }

  @protected
  Future<ProcessResult> runIntlOrFail(String cmd, List<String> arguments,
      {bool printStdOut = true}) async {
    return runOrFail(() => runIntl(cmd, arguments), printStdOut: printStdOut);
  }
}
