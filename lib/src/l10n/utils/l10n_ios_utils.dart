import 'dart:io';

import 'package:alex/src/encoding/utf16.dart';
import 'package:alex/src/l10n/decoders/ios_strings_decoder.dart';
import 'package:recase/recase.dart';

class L10nIosUtils {
  static final _forbiddenSymbolsRegex =
      RegExp("[^a-z0-9 ]", caseSensitive: false, unicode: true);

  static String getIosLocale(String locale) => locale.replaceAll('_', '-');

  static String covertStringsKeyToXml(String key) => key
      .replaceAll(r'\n', '')
      .replaceAll(_forbiddenSymbolsRegex, '')
      .pascalCase;

  static Future<String> loadStringsFile(File file) async {
    return await file.hasUtf16leBom
        ? await file.readAsUft16LEString()
        : await file.readAsString();
  }

  static Future<Map<String, String>> loadAndDecodeStringsFile(File file) async {
    final content = await L10nIosUtils.loadStringsFile(file);
    return const IosStringsDecoder().decode(content);
  }

  L10nIosUtils._();
}
