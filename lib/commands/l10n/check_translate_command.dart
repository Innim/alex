
import 'package:alex/src/l10n/comparers/arb_comparer.dart';

import 'src/l10n_command_base.dart';

/// Command to extract strings from Dart code to arb file.
class CheckTranslateCommand extends L10nCommandBase {
  static const _argLocale = 'locale';
  static const _defaultLocale = 'en';
  CheckTranslateCommand()
      : super('check_translate',
            'Checks for translations for a language, the default is English.') {
    argParser
      ..addOption(
        _argLocale,
        abbr: 'l',
        help: 'Locale for import from xml. '
            'If not specified - all locales will be imported.',
        valueHelp: 'LOCALE',
      );
  }

  @override
  Future<int> doRun() async {
    final config = findConfigAndSetWorkingDir();
    final l10nConfig = config.l10n;
    final args = argResults!;
    final baseLocale = args[_argLocale] as String? ?? _defaultLocale;
    final comparer = ArbComparer(l10nConfig, baseLocale);
    final res = await comparer.compare(
      () async {
        printInfo('Running extract to arb...');
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
      },
      success: success,
      error: error,
      errorBy: errorBy,
    );
    return res;
  }
}
