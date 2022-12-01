import 'package:alex/alex.dart';
import 'package:alex/commands/l10n/src/mixins/intl_mixin.dart';
import 'package:alex/src/exception/run_exception.dart';

import 'src/l10n_command_base.dart';

/// Command to extract strings from Dart code to arb file.
class ExtractCommand extends L10nCommandBase with IntlMixim {
  ExtractCommand()
      : super('extract', 'Extract strings from Dart code to arb file.');

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

    final mainFile = await L10nUtils.getMainArb(l10nConfig);
    return success(
        message: 'Strings extracted to ARB file. '
            'You can send $mainFile to the translators');
  }
}
