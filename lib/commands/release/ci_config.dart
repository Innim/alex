import 'dart:io';

import 'package:ini/ini.dart';

/// Возвращает список языков, которые использует CI при билде приложения.
Future<List<String>> ciConfigGetLocalizationLanguageList() async {
  final config = Config.fromStrings(await File("ci/config.ini").readAsLines());
  final languages =
      config.get("Build", "LOCALIZATION_LANGUAGE_LIST").split(" ");

  return languages;
}
