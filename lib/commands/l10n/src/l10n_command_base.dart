import 'dart:io';

import 'package:alex/alex.dart';
import 'package:alex/runner/alex_command.dart';
import 'package:meta/meta.dart';

/// Base command for localization feature.
abstract class L10nCommandBase extends AlexCommand {
  L10nCommandBase(String name, String description) : super(name, description);

  L10nConfig get l10nConfig => AlexConfig.instance.l10n;

  // TODO: move run "flutter pub run" in common utils
  @protected
  Future<ProcessResult> runIntl(String cmd, List<String> arguments) async {
    return Process.run(
        'flutter', ['pub', 'run', 'intl_translation:$cmd', ...arguments]);
  }
}
