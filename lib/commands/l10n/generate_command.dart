import 'dart:io';

import 'package:alex/alex.dart';
import 'package:alex/src/exception/run_exception.dart';

import 'src/l10n_command_base.dart';
import 'package:path/path.dart' as path;

/// Command to generate dart files by arb files.
class GenerateCommand extends L10nCommandBase {
  GenerateCommand()
      : super('generate', 'Generate strings dart files by arb files.',
            const ['gen']);

  @override
  Future<int> doRun() async {
    final config = findConfigAndSetWorkingDir();
    final l10nConfig = config.l10n;

    try {
      await generateLocalisation(l10nConfig);
    } on RunException catch (e) {
      return errorBy(e);
    }

    // TODO: check if all translations for all keys are exist

    return success(message: 'All translations imported.');
  }
}
