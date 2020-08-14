import 'package:alex/alex.dart';

/// Localization utils.
class L10nUtils {
  static const arbMessagesSuffix = 'messages';
  static const _localeVar = '{locale}';

  /// Returns ARB file name by locale.
  static String getArbFile(L10nConfig l10nConfig, String locale) =>
      l10nConfig.translationFilesPattern.replaceFirst(_localeVar, locale);

  /// Returns ARB messages file name.
  static String getArbMessagesFile(L10nConfig l10nConfig) =>
      getArbFile(l10nConfig, arbMessagesSuffix);

  /// Returns 2 parts of ARB file name.
  ///
  /// First parts is from start to locale. Second is from locale to the end.
  static List<String> getArbFileParts(L10nConfig l10nConfig) =>
      l10nConfig.translationFilesPattern.split(_localeVar);

  /// Returns ARB file name for base locale.
  static String getBaseArbFile(L10nConfig l10nConfig) =>
      getArbFile(l10nConfig, l10nConfig.baseLocaleForArb);

  L10nUtils._();
}
