import 'dart:convert';
import 'dart:io';

import 'package:alex/alex.dart';
import 'package:alex/commands/l10n/l10n_command.dart';
import 'package:alex/commands/l10n/to_xml_command.dart';
import 'package:alex/src/exception/run_exception.dart';
import 'package:args/command_runner.dart';
import 'package:path/path.dart' as path;

import 'extract_command.dart';
import 'src/l10n_command_base.dart';

const _jsonDecoder = JsonCodec();

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
  
    final l10nSubpath = l10nConfig.outputDir;

    final l10nPath = path.join(path.current, l10nSubpath);
    final l10nDir = Directory(l10nPath);

    final sourceFileName = L10nUtils.getArbFile(l10nConfig, baseLocale);
    final toCompareFile = File(path.join(l10nDir.path, sourceFileName));

    final exists = await toCompareFile.exists();
    if (exists) {
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
      final mainFile = await ExtractCommand().getMainArb(l10nConfig);
      return _compareFiles(mainFile, toCompareFile, baseLocale);
    }
    return error(2, message: 'ABR file for locale $baseLocale is not found');
  }

  Future<int> _compareFiles(
      File mainFile, File toCompareFile, String locale) async {
    final mainData = _jsonDecoder.decode(await mainFile.readAsString())
        as Map<String, dynamic>;
    final compareData = _jsonDecoder.decode(await toCompareFile.readAsString())
        as Map<String, dynamic>;
    final notTranslatedKeys = <String>[];
    mainData.forEach((key, value) {
      if (!compareData.containsKey(key)) {
        notTranslatedKeys.add(key);
      }
    });
    if (notTranslatedKeys.isEmpty) {
      return success(message: 'All strings has translete for locale: $locale');
    } else {
      return error(2,
          message:
              'No translations for strings: ${notTranslatedKeys.join(',')} in locale: $locale');
    }
  }
}
