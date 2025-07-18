import 'dart:io';

import 'package:alex/alex.dart';
import 'package:alex/src/l10n/locale/locales.dart';
import 'package:path/path.dart' as path;

/// Localization utils.
class L10nUtils {
  static const arbMessagesSuffix = 'messages';
  static const diffsSuffix = '_diffs';
  static const _localeVar = '{locale}';

  /// Returns path of directory with localization files.
  static String getDirPath(L10nConfig config) =>
      path.join(path.current, config.outputDir);

  /// Returns ARB file name by locale.
  static String getArbFile(L10nConfig config, ArbLocale locale) =>
      config.translationFilesPattern.replaceFirst(_localeVar, locale.value);

  static String _getArbFile(L10nConfig config, String suffix) =>
      config.translationFilesPattern.replaceFirst(_localeVar, suffix);

  /// Returns ARB messages file name.
  static String getArbMessagesFile(L10nConfig config) =>
      _getArbFile(config, arbMessagesSuffix);

  /// Returns 2 parts of ARB file name.
  ///
  /// First parts is from start to locale. Second is from locale to the end.
  static List<String> getArbFileParts(L10nConfig config) =>
      config.translationFilesPattern.split(_localeVar);

  /// Returns ARB file name for base locale.
  static String getBaseArbFile(L10nConfig config) =>
      getArbFile(config, config.baseLocaleForArb);

  /// Returns dir path with xml translations files for [locale].
  static String getXmlFilesPath(L10nConfig config, XmlLocale locale) {
    final parentDirPath = config.xmlOutputDir;
    return path.join(parentDirPath, locale.value);
  }

  /// Returns name for xml file of main project localization.
  static String getMainXmlFileName(L10nConfig config) {
    final fileName = config.xmlOutputName?.isNotEmpty ?? false
        ? config.xmlOutputName!
        : _getBaseNameByArb(config);
    return path.setExtension(fileName, '.xml');
  }

  static String getDiffsXmlFileName(String fileName) => path.setExtension(
      addDiffsSuffix(path.withoutExtension(fileName)), '.xml');

  static String addDiffsSuffix(String name) => '$name$diffsSuffix';

  static String removeDiffsSuffix(String name) =>
      name.substring(0, name.length - diffsSuffix.length);

  static Future<File> getMainArb(L10nConfig l10nConfig) async {
    final mainFile = _arb(L10nUtils.getArbMessagesFile(l10nConfig), l10nConfig);
    final localeFile = _arb(L10nUtils.getBaseArbFile(l10nConfig), l10nConfig);

    if (await localeFile.exists()) await localeFile.delete();
    final res = await mainFile.copy(localeFile.path);
    return res;
  }

  static File _arb(String fileName, L10nConfig config) =>
      File(path.join(config.outputDir, fileName));

  static String _getBaseNameByArb(L10nConfig config) {
    final parts = getArbFileParts(config);
    final start = parts.first;
    if (start.endsWith('_') || start.endsWith('-')) {
      parts[0] = start.substring(0, start.length - 1);
    }

    final fileName = parts.join();
    return path.basenameWithoutExtension(fileName);
  }

  L10nUtils._();
}

extension L10nConfigExtension on L10nConfig {
  /// Returns name for xml file of main project localization.
  String getMainXmlFileName() => L10nUtils.getMainXmlFileName(this);

  /// Returns dir path with xml translations files for [locale].
  String getXmlFilesPath(XmlLocale locale) =>
      L10nUtils.getXmlFilesPath(this, locale);

  /// Returns arb file path for the [locale].
  String getArbFilePath(ArbLocale locale) =>
      path.join(L10nUtils.getDirPath(this), L10nUtils.getArbFile(this, locale));

  /// Returns path of directory with localization files.
  String getOutputDirPath() => L10nUtils.getDirPath(this);
}
