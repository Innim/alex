import 'dart:io';

import 'package:ini/ini.dart';

/// CI config.
class CiConfig {
  static Future<CiConfig> getConfig(String configPath) async {
    final strings = await File(configPath).readAsLines();
    final config = Config.fromStrings(strings);

    return CiConfig._(config);
  }

  final Config _config;

  CiConfig._(this._config);

  List<String> get localizationLanguageList {
    return _config.get("Build", "LOCALIZATION_LANGUAGE_LIST")?.split(" ") ??
        const [];
  }
}
