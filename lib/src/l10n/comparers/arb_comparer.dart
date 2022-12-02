import 'dart:convert';
import 'dart:io';
import 'package:alex/src/exception/run_exception.dart';
import 'package:path/path.dart' as path;
import 'package:alex/alex.dart';

const _jsonDecoder = JsonCodec();

class ArbComparer {
  final L10nConfig l10nConfig;
  final String locale;
  const ArbComparer(this.l10nConfig, this.locale);

  Future<List<String>> compare(Future<void> Function() extractArb) async {
    final l10nSubpath = l10nConfig.outputDir;

    final l10nPath = path.join(path.current, l10nSubpath);
    final l10nDir = Directory(l10nPath);

    final sourceFileName = L10nUtils.getArbFile(l10nConfig, locale);
    final toCompareFile = File(path.join(l10nDir.path, sourceFileName));

    final exists = await toCompareFile.exists();
    if (exists) {
      await extractArb.call();
      final mainFile = await L10nUtils.getMainArb(l10nConfig);
      final notTranslatedKeys =
          await _compareArb(mainFile, toCompareFile, locale);
      return notTranslatedKeys;
    } else {
      throw RunException.fileNotFound(
          'ABR file for locale $locale is not found');
    }
  }

  Future<List<String>> _compareArb(
      File mainFile, File toCompareFile, String locale) async {
    final mainData = _jsonDecoder.decode(await mainFile.readAsString())
        as Map<String, dynamic>;
    final compareData = _jsonDecoder.decode(await toCompareFile.readAsString())
        as Map<String, dynamic>;
    final notTranslatedKeys = <String>[];
    mainData.forEach((key, dynamic value) {
      if (!key.startsWith('@') && !compareData.containsKey(key)) {
        notTranslatedKeys.add(key);
      }
    });
    return notTranslatedKeys;
  }
}
