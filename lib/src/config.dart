import 'dart:io';

import 'package:yaml/yaml.dart';

/// Run configuration.
class AlexConfig {
  static const _configSection = 'alex';
  static const _defaultConfigFile = 'alex.yaml';
  static const _mainConfigFile = 'pubspec.yaml';

  static AlexConfig _instance;

  /// Load configuration.
  static void load([String configFile]) {
    assert(_instance == null);

    if (configFile != null) {
      _tryLoadConfigFile(configFile);
    } else {
      if (!_tryLoadConfigFile(_defaultConfigFile) &&
          !_tryLoadConfigFile(_mainConfigFile, _configSection)) {
        throw Exception('Config file is not found');
      }
    }
  }

  static bool _tryLoadConfigFile(String path, [String section]) {
    final file = File(path);
    if (file.existsSync()) {
      final config = _loadConfigFile(file, section);
      _instance = config;
      return true;
    } else {
      return false;
    }
  }

  static AlexConfig _loadConfigFile(File file, String section) {
    final yamlString = file.readAsStringSync();
    var yamlMap = loadYaml(yamlString) as YamlMap;
    if (yamlMap == null) {
      throw Exception("Can't parse ${file.path}");
    }

    if (section != null) {
      yamlMap = yamlMap[section] as YamlMap;

      if (yamlMap == null) {
        throw Exception(
            "Can't find section $section in config file ${file.path}");
      }
    }

    return AlexConfig._(yamlMap);
  }

  final YamlMap _data;

  L10nConfig _l10n;

  AlexConfig._(this._data) : assert(_data != null);

  L10nConfig get l10n {
    final key = 'l10n';
    _l10n ??= _data.containsKey(key)
        ? L10nConfig.fromYaml(_data[key] as YamlMap)
        : L10nConfig();
    return _l10n;
  }
}

/// Configutation for manage localization.
class L10nConfig {
  static const String _defaultOutputDir = 'lib/application/l10n';
  static const String _defaultSourceFile = 'lib/application/localization.dart';
  static const String _defaultTranslationFilesMask = 'intl_??.arb';
  static const String _defaultBaseLocaleFile = 'intl_ru.arb';

  /// Path to the outpur directory of arb files.
  final String outputDir;

  /// Path to the source dart file.
  ///
  /// The file contains keys for resources generation.
  final String sourceFile;

  /// Mask for translation abr files.
  final String translationFilesMask;

  /// Name of the abr file for a base locale.
  final String baseLocaleFile;

  L10nConfig({
    this.outputDir = _defaultOutputDir,
    this.sourceFile = _defaultSourceFile,
    this.translationFilesMask = _defaultTranslationFilesMask,
    this.baseLocaleFile = _defaultBaseLocaleFile,
  })  : assert(outputDir != null),
        assert(sourceFile != null),
        assert(translationFilesMask != null),
        assert(baseLocaleFile != null);

  factory L10nConfig.fromYaml(YamlMap data) {
    assert(data != null);
    return L10nConfig(
      outputDir: data['output_dir'] as String ?? _defaultOutputDir,
      sourceFile: data['source_file'] as String ?? _defaultSourceFile,
      translationFilesMask: data['translation_files_mask'] as String ??
          _defaultTranslationFilesMask,
      baseLocaleFile:
          data['base_locale_file'] as String ?? _defaultBaseLocaleFile,
    );
  }

  @override
  String toString() {
    return 'L10nConfig{outputDir: $outputDir, sourceFile: $sourceFile, '
        'translationFilesMask: $translationFilesMask, '
        'baseLocaleFile: $baseLocaleFile}';
  }
}
