import 'package:alex/src/exception/run_exception.dart';
import 'package:alex/src/l10n/comparers/arb_comparer.dart';

import 'src/l10n_command_base.dart';

/// Command to extract strings from Dart code to arb file.
class CheckTranslateCommand extends L10nCommandBase {
  static const _argLocale = 'locale';
  static const _defaultLocale = 'en';
  CheckTranslateCommand()
      : super('check_translate',
            'Checks for translations into a specific language, the default is English.') {
    argParser
      ..addOption(
        _argLocale,
        abbr: 'l',
        help: 'Locale for check translations. '
            'If not specified - "en" locale will be check.',
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
    try {
      final notTranslatedKeys = await comparer.compare(
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
      );
      if (notTranslatedKeys.isEmpty) {
        return success(
            message: 'All strings have translation for locale: $baseLocale');
      } else {
        return error(2,
            message:
                'No translations for strings: ${notTranslatedKeys.join(',')} in locale: $baseLocale');
      }
    } on RunException catch (e) {
      return errorBy(e);
    }
  }
}
