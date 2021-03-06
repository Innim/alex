import 'dart:io';

import 'package:yaml/yaml.dart';

/// Run configuration.
class AlexConfig {
  static const _configSection = 'alex';
  static const _defaultConfigFile = 'alex.yaml';
  static const _mainConfigFile = 'pubspec.yaml';

  static AlexConfig _instance;

  /// Returns instance of loaded configuration.
  static AlexConfig get instance {
    if (_instance == null) {
      load();
    }

    return _instance;
  }

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
      if (!yamlMap.containsKey(section)) {
        throw Exception(
            "Can't find section $section in config file ${file.path}");
      }

      yamlMap = yamlMap[section] as YamlMap;

      if (yamlMap == null) {
        throw Exception(
            'Section $section is empty in config file ${file.path}');
      }
    }

    return AlexConfig._(yamlMap);
  }

  final YamlMap _data;

  L10nConfig _l10n;

  AlexConfig._(this._data) : assert(_data != null);

  L10nConfig get l10n {
    const key = 'l10n';
    return _l10n ??= _data.containsKey(key)
        ? L10nConfig.fromYaml(_data[key] as YamlMap)
        : L10nConfig();
  }
}

/// Configutation for manage localization.
class L10nConfig {
  static const String _defaultOutputDir = 'lib/application/l10n';
  static const String _defaultSourceFile = 'lib/application/localization.dart';
  static const String _defaultTranslationFilesPattern = 'intl_{locale}.arb';
  static const String _defaultBaseLocaleForArb = 'ru';
  static const String _defaultBaseLocaleForXml = 'en';
  static const String _defaultXmlOutputDir = 'lib/application/l10n/xml';

  /// Path to the outpur directory for arb files.
  final String outputDir;

  /// Path to the source dart file.
  ///
  /// The file contains keys for resources generation.
  final String sourceFile;

  /// Pattern for translation abr files names.
  ///
  /// Should contains `{locale}`, which will be replaced with
  /// a locale code (ru, en, etc).
  final String translationFilesPattern;

  /// Base locale for abr files.
  ///
  /// Should be a locale code: ru, en, etc.
  final String baseLocaleForArb;

  /// Base locale for generate xml files by arb.
  ///
  /// Should be a locale code: ru, en, etc.
  ///
  /// See [xmlOutputDir].
  final String baseLocaleForXml;

  /// Path to the outpur directory for xml files.
  ///
  /// See [baseLocaleForXml].
  final String xmlOutputDir;

  /// Filename for the output xml.
  ///
  /// If empty - than name of original arb file without locale suffix will used.
  ///
  /// See [baseLocaleForXml].
  final String xmlOutputName;

  L10nConfig({
    this.outputDir = _defaultOutputDir,
    this.sourceFile = _defaultSourceFile,
    this.translationFilesPattern = _defaultTranslationFilesPattern,
    this.baseLocaleForArb = _defaultBaseLocaleForArb,
    this.baseLocaleForXml = _defaultBaseLocaleForXml,
    this.xmlOutputDir = _defaultXmlOutputDir,
    this.xmlOutputName,
  })  : assert(outputDir != null),
        assert(sourceFile != null),
        assert(translationFilesPattern != null),
        assert(baseLocaleForArb != null),
        assert(baseLocaleForXml != null),
        assert(xmlOutputDir != null);

  factory L10nConfig.fromYaml(YamlMap data) {
    assert(data != null);
    return L10nConfig(
      outputDir: data['output_dir'] as String ?? _defaultOutputDir,
      sourceFile: data['source_file'] as String ?? _defaultSourceFile,
      translationFilesPattern: data['translation_files_pattern'] as String ??
          _defaultTranslationFilesPattern,
      baseLocaleForArb:
          data['base_locale_for_abr'] as String ?? _defaultBaseLocaleForArb,
      baseLocaleForXml:
          data['base_locale_for_xml'] as String ?? _defaultBaseLocaleForXml,
      xmlOutputDir: data['xml_output_dir'] as String ?? _defaultXmlOutputDir,
      xmlOutputName: data['xml_output_name'] as String,
    );
  }

  @override
  String toString() {
    return 'L10nConfig{outputDir: $outputDir, sourceFile: $sourceFile, '
        'translationFilesPattern: $translationFilesPattern, '
        'baseLocaleForArb: $baseLocaleForArb, '
        'baseLocaleForXml: $baseLocaleForXml, '
        'xmlOutputDir: $xmlOutputDir, '
        'xmlOutputName: $xmlOutputName}';
  }
}
