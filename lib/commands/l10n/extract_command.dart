import 'dart:io';

import 'package:alex/alex.dart';
import 'package:alex/src/exception/run_exception.dart';
import 'package:path/path.dart' as path;

import 'src/l10n_command_base.dart';

/// Command to extract strings from Dart code to arb file.
class ExtractCommand extends L10nCommandBase {
  ExtractCommand()
      : super('extract', 'Extract strings from Dart code to arb file.');

  Future<File> getMainArb(L10nConfig l10nConfig) async {
    final mainFile = _arb(L10nUtils.getArbMessagesFile(l10nConfig));
    final localeFile = _arb(L10nUtils.getBaseArbFile(l10nConfig));

    if (await localeFile.exists()) await localeFile.delete();
    final res = await mainFile.copy(localeFile.path);
    return res;
  }

  @override
  Future<int> doRun() async {
    final config = findConfigAndSetWorkingDir();
    final l10nConfig = config.l10n;
    try {
      final outputDir = l10nConfig.outputDir;
      final sourcePath = l10nConfig.sourceFile;

      await runIntlOrFail(
        'extract_to_arb',
        [
          '--output-dir=$outputDir',
          sourcePath,
        ],
        prependWithPubGet: true,
      );
    } on RunException catch (e) {
      return errorBy(e);
    }
    
    final mainFile = await getMainArb(l10nConfig);
    return success(
        message: 'Strings extracted to ARB file. '
            'You can send $mainFile to the translators');
  }

  File _arb(String fileName) =>
      File(path.join(config.l10n.outputDir, fileName));
}
