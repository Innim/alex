import 'package:alex/alex.dart';

/// Localization utils.
class L10nUtils {
  /// Returns ARB file name by locale.
  static String getArbFile(L10nConfig l10nConfig, String locale) =>
      l10nConfig.translationFilesPattern.replaceFirst('{locale}', locale);

  /// Returns ARB file name for base locale.
  static String getBaseArbFile(L10nConfig l10nConfig, String locale) =>
      getArbFile(l10nConfig, l10nConfig.baseLocaleForArb);

  L10nUtils._();
}
