import 'dart:io';

import 'package:alex/src/l10n/locale/locales.dart';
import 'package:logging/logging.dart';
import 'package:yaml/yaml.dart';
import 'package:path/path.dart' as p;

import 'pub_spec.dart';

/// Run configuration.
class AlexConfig {
  static const _configSection = 'alex';
  static const _defaultConfigFile = 'alex.yaml';
  static const _mainConfigFile = 'pubspec.yaml';

  static AlexConfig? _instance;
  static final _logger = Logger('alex_config');

  /// Returns instance of loaded configuration.
  static AlexConfig get instance {
    if (_instance == null) {
      load();
    }

    return _instance!;
  }

  static bool get hasInstance => _instance != null;

  /// Load configuration.
  static void load({String? path, bool recursive = false}) {
    assert(_instance == null);

    if (path != null) {
      _tryLoadConfigFile(path);
    } else {
      final dirs = recursive
          ? Spec.getPubspecsSync().map((e) => p.dirname(e.path))
          : const ['./'];

      for (final dir in dirs) {
        if (_tryLoadConfigFile(p.join(dir, _defaultConfigFile)) ||
            _tryLoadConfigFile(p.join(dir, _mainConfigFile), _configSection)) {
          return;
        }
      }

      throw Exception(
          'Config file or section alex in pubspec.yaml are not found');
    }
  }

  static bool _tryLoadConfigFile(String path, [String? section]) {
    final file = File(path);
    if (file.existsSync()) {
      try {
        final config = _loadConfigFile(file, section);
        _instance = config;
      } catch (e) {
        _logger.fine('Config was not loaded due $e');
        return false;
      }
      return true;
    } else {
      return false;
    }
  }

  static AlexConfig _loadConfigFile(File file, String? section) {
    final yamlString = file.readAsStringSync();
    var yamlMap = loadYaml(yamlString) as YamlMap?;
    if (yamlMap == null) {
      throw Exception("Can't parse ${file.path}");
    }

    if (section != null) {
      if (!yamlMap.containsKey(section)) {
        throw Exception(
            "Can't find section $section in config file ${file.path}");
      }

      yamlMap = yamlMap[section] as YamlMap?;

      if (yamlMap == null) {
        throw Exception(
            'Section $section is empty in config file ${file.path}');
      }
    }

    return AlexConfig._(file.path, yamlMap);
  }

  final String _path;
  final YamlMap _data;

  L10nConfig? _l10n;
  AlexCIConfig? _ci;
  AlexGitConfig? _git;
  AlexScriptsConfig? _scripts;

  AlexConfig._(this._path, this._data);

  L10nConfig get l10n {
    const key = 'l10n';
    return _l10n ??= _data.containsKey(key)
        ? L10nConfig.fromYaml(_data[key] as YamlMap)
        : L10nConfig();
  }

  AlexCIConfig get ci {
    const key = 'ci';
    return _ci ??= _data.containsKey(key)
        ? AlexCIConfig.fromYaml(_data[key] as YamlMap)
        : const AlexCIConfig();
  }

  AlexGitConfig get git {
    const key = 'git';
    return _git ??= _data.containsKey(key)
        ? AlexGitConfig.fromYaml(_data[key] as YamlMap)
        : const AlexGitConfig();
  }

  AlexScriptsConfig? get scripts {
    const key = 'scripts';
    return _scripts ??= _data.containsKey(key)
        ? AlexScriptsConfig.fromYaml(_data[key] as YamlMap)
        : const AlexScriptsConfig();
  }

  String get rootPath => p.dirname(_path);
}

/// Configuration for manage localization.
class L10nConfig {
  static const String _defaultOutputDir = 'lib/application/l10n';
  static const String _defaultSourceFile = 'lib/application/localization.dart';
  static const String _defaultTranslationFilesPattern = 'intl_{locale}.arb';
  static const String _defaultBaseLocaleForArb = 'ru';
  static const String _defaultBaseLocaleForXml = 'en';
  static const String _defaultXmlOutputDir = 'lib/application/l10n/xml';
  static const List<String> _defaultRequireLatin = [
    'ca',
    'cs',
    'da',
    'de',
    'en',
    'es',
    'fi',
    'fr',
    'hr',
    'hu',
    'id',
    'it',
    'ms',
    'nl',
    'no',
    'pl',
    'pt',
    'pt_BR',
    'ro',
    'sk',
    'sl',
    'sr',
    'sv',
    'tr',
  ];

  /// Path to the output directory for arb files.
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
  final ArbLocale baseLocaleForArb;

  /// Base locale for generate xml files by arb.
  ///
  /// Should be a locale code: ru, en, etc.
  ///
  /// See [xmlOutputDir].
  final XmlLocale baseLocaleForXml;

  /// Path to the output directory for xml files.
  ///
  /// See [baseLocaleForXml].
  final String xmlOutputDir;

  /// Filename for the output xml.
  ///
  /// If empty - than name of original arb file without locale suffix will used.
  ///
  /// See [baseLocaleForXml].
  final String? xmlOutputName;

  /// Require only Latin symbols for specified locales.
  ///
  /// This includes (i.e. they are allowed) all special symbols from
  /// German, Spanish, Turkish, Slovenian, Vietnamese, etc alphabets.
  /// But exclude (i.e. they are forbidden) Cyrillic, Persian, etc symbols.
  final List<XmlLocale> requireLatin;

  L10nConfig({
    this.outputDir = _defaultOutputDir,
    this.sourceFile = _defaultSourceFile,
    this.translationFilesPattern = _defaultTranslationFilesPattern,
    String baseLocaleForArb = _defaultBaseLocaleForArb,
    String baseLocaleForXml = _defaultBaseLocaleForXml,
    this.xmlOutputDir = _defaultXmlOutputDir,
    this.xmlOutputName,
    List<String> requireLatin = _defaultRequireLatin,
  })  : baseLocaleForArb = baseLocaleForArb.asArbLocale(),
        baseLocaleForXml = baseLocaleForXml.asXmlLocale(),
        requireLatin =
            requireLatin.map((e) => e.asXmlLocale()).toList(growable: false);

  factory L10nConfig.fromYaml(YamlMap data) {
    return L10nConfig(
      outputDir: data['output_dir'] as String? ?? _defaultOutputDir,
      sourceFile: data['source_file'] as String? ?? _defaultSourceFile,
      translationFilesPattern: data['translation_files_pattern'] as String? ??
          _defaultTranslationFilesPattern,
      baseLocaleForArb:
          data['base_locale_for_abr'] as String? ?? _defaultBaseLocaleForArb,
      baseLocaleForXml:
          data['base_locale_for_xml'] as String? ?? _defaultBaseLocaleForXml,
      xmlOutputDir: data['xml_output_dir'] as String? ?? _defaultXmlOutputDir,
      xmlOutputName: data['xml_output_name'] as String?,
      requireLatin: (data['require_latin'] as YamlList?).toListString() ??
          _defaultRequireLatin,
    );
  }

  @override
  String toString() {
    return 'L10nConfig{outputDir: $outputDir, sourceFile: $sourceFile, '
        'translationFilesPattern: $translationFilesPattern, '
        'baseLocaleForArb: $baseLocaleForArb, '
        'baseLocaleForXml: $baseLocaleForXml, '
        'xmlOutputDir: $xmlOutputDir, '
        'requireLatin: [${requireLatin.join(', ')}], '
        'xmlOutputName: $xmlOutputName}';
  }
}

/// Configuration of CI for Alex.
class AlexCIConfig {
  static const _defaultEnabled = true;

  /// Defines if CI for project is enabled.
  final bool enabled;

  const AlexCIConfig({
    this.enabled = _defaultEnabled,
  });

  factory AlexCIConfig.fromYaml(YamlMap data) {
    return AlexCIConfig(
      enabled: data['enabled'] as bool? ?? _defaultEnabled,
    );
  }

  @override
  String toString() {
    return 'AlexCIConfig{enabled: $enabled}';
  }
}

/// Configuration of GIT repository for Alex.
class AlexGitConfig {
  static const _defaultRemote = "origin";

  /// Name for default remote.
  final String remote;

  /// Configurations of branches.
  final AlexGitConfigBranches branches;

  const AlexGitConfig({
    this.remote = _defaultRemote,
    this.branches = const AlexGitConfigBranches(),
  });

  factory AlexGitConfig.fromYaml(YamlMap data) {
    const branchesKey = 'branches';
    return AlexGitConfig(
      remote: data['remote'] as String? ?? _defaultRemote,
      branches: data.containsKey(branchesKey)
          ? AlexGitConfigBranches.fromYaml(data[branchesKey] as YamlMap)
          : const AlexGitConfigBranches(),
    );
  }

  @override
  String toString() {
    return 'AlexGitConfig{'
        'remote: $remote, '
        'branches: $branches'
        '}';
  }
}

class AlexGitConfigBranches {
  static const _defaultMaster = "master";
  static const _defaultDevelop = "develop";
  static const _defaultTest = "pipe/test";
  static const _defaultFeaturePrefix = "feature/";

  final String master;
  final String develop;
  final String test;
  final String featurePrefix;

  const AlexGitConfigBranches({
    this.master = _defaultMaster,
    this.develop = _defaultDevelop,
    this.test = _defaultTest,
    this.featurePrefix = _defaultFeaturePrefix,
  });

  factory AlexGitConfigBranches.fromYaml(YamlMap data) {
    return AlexGitConfigBranches(
      master: data['master'] as String? ?? _defaultMaster,
      develop: data['develop'] as String? ?? _defaultDevelop,
      test: data['test'] as String? ?? _defaultTest,
      featurePrefix: data['featurePrefix'] as String? ?? _defaultFeaturePrefix,
    );
  }

  @override
  String toString() {
    return 'AlexGitConfigBranches{'
        'master: $master, '
        'develop: $develop, '
        'test: $test, '
        'featurePrefix: $featurePrefix'
        '}';
  }
}

/// Configuration for scripts for alex
class AlexScriptsConfig {
  /// Scripts paths for run before release start.
  final List<String>? preReleaseScriptsPaths;

  const AlexScriptsConfig({this.preReleaseScriptsPaths = const []});

  factory AlexScriptsConfig.fromYaml(YamlMap data) {
    return AlexScriptsConfig(
      preReleaseScriptsPaths:
          (data['pre_release_scripts_paths'] as YamlList?).toListString(),
    );
  }

  @override
  String toString() {
    return 'AlexScriptsConfig{preReleaseScriptsPaths: $preReleaseScriptsPaths}';
  }
}

extension YamlListExtension on YamlList? {
  List<String>? toListString() {
    final list = this;
    if (list != null) {
      return list.map((e) => e as String).toList();
    }
    return null;
  }
}
