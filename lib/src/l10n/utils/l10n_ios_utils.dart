import 'package:recase/recase.dart';

class L10nIosUtils {
  static final _forbiddenSymbolsRegex =
      RegExp("[^a-z0-9 ]", caseSensitive: false, unicode: true);

  static String getIosLocale(String locale) => locale.replaceAll('_', '-');

  static String covertStringsKeyToXml(String key) => key
      .replaceAll(r'\n', '')
      .replaceAll(_forbiddenSymbolsRegex, '')
      .pascalCase;

  L10nIosUtils._();
}
