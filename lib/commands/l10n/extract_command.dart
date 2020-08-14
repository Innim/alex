import 'dart:io';

import 'package:alex/alex.dart';
import 'package:alex/src/exception/run_exception.dart';
import 'package:path/path.dart' as path;

import 'src/l10n_command_base.dart';

/// Command to extract strings from Dart code to arb file.
class ExtractCommand extends L10nCommandBase {
  ExtractCommand()
      : super('extract', 'Extract strings from Dart code to arb file.');

  @override
  Future<int> run() async {
    final config = l10nConfig;

    try {
      await runIntlOrFail('extract_to_arb', [
        '--output-dir=${config.outputDir}',
        config.sourceFile,
      ]);
    } on RunException catch (e) {
      return errorBy(e);
    }

    final mainFile = _arb(L10nUtils.getArbFile(l10nConfig, 'messages'));
    final localeFile = _arb(L10nUtils.getBaseArbFile(l10nConfig));

    if (await localeFile.exists()) await localeFile.delete();

    await mainFile.copy(localeFile.path);

    return success(
        message: 'Strings extracted to ARB file. '
            'You can send ${mainFile} to the translators');
  }

  File _arb(String fileName) => File(path.join(l10nConfig.outputDir, fileName));
}
