import 'dart:convert';
import 'dart:io';

import 'package:alex/src/config.dart';
import 'package:alex/src/fs/fs.dart';
import 'package:alex/src/l10n/l10n_utils.dart';
import 'package:alex/src/pub_spec.dart';
import 'package:path/path.dart' as p;

/// Facts about the project that an AI agent or a script needs to know.
///
/// Collected from the alex configuration and the project files,
/// so they can't diverge from the project.
class ProjectFacts {
  /// Path to the root directory of the project.
  final String rootPath;

  /// Path to the file with the alex configuration,
  /// relative to the [rootPath].
  final String configPath;

  /// Whether the project has the localization managed by alex.
  final bool hasL10n;

  final String? packageName;
  final String? packageVersion;

  /// Whether the project depends on Flutter.
  final bool isFlutter;

  /// All packages of the project: subprojects and workspace members.
  ///
  /// Contains more than one item only for a multi-package project.
  final List<ProjectPackage> packages;

  /// Version of Flutter pinned with FVM, if the project uses it.
  final String? fvmVersion;

  /// Locales of the app, by the ARB files.
  final List<String> locales;

  final L10nConfig l10n;
  final AlexGitConfig git;

  const ProjectFacts({
    required this.l10n,
    required this.git,
    this.rootPath = '',
    this.configPath = '',
    this.hasL10n = false,
    this.packageName,
    this.packageVersion,
    this.isFlutter = false,
    this.packages = const [],
    this.fvmVersion,
    this.locales = const [],
  });

  /// Collects the facts of the project with the [config].
  ///
  /// Should be called with the project root as a current directory.
  static Future<ProjectFacts> collect(AlexConfig config) async {
    String? name;
    String? version;
    var isFlutter = false;

    try {
      final spec = await Spec.pub(const IOFileSystem());
      name = spec.name;
      version = spec.versionOrNull?.toString();
      isFlutter = spec.dependsOn('flutter');
    } on Object catch (_) {
      // Pubspec is optional for the facts.
    }

    return ProjectFacts(
      l10n: config.l10n,
      git: config.git,
      rootPath: config.rootPath,
      configPath: p.relative(config.configPath, from: config.rootPath),
      hasL10n: Directory(config.l10n.outputDir).existsSync(),
      packageName: name,
      packageVersion: version,
      isFlutter: isFlutter,
      packages: await _packages(),
      fvmVersion: _fvmVersion(),
      locales: _locales(config.l10n),
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        if (rootPath.isNotEmpty) 'root': rootPath,
        if (configPath.isNotEmpty) 'config': configPath,
        if (packageName != null) 'package': packageName,
        if (packageVersion != null) 'version': packageVersion,
        'flutter': isFlutter,
        if (packages.length > 1)
          'packages': packages.map((p) => p.toJson()).toList(),
        if (fvmVersion != null) 'fvm': fvmVersion,
        if (hasL10n) ...<String, dynamic>{
          'locales': locales,
          'l10n': <String, dynamic>{
            'arbDir': l10n.outputDir,
            'arbPattern': l10n.translationFilesPattern,
            'sourceFile': l10n.sourceFile,
            'xmlDir': l10n.xmlOutputDir,
            'baseLocaleForArb': l10n.baseLocaleForArb.value,
            'baseLocaleForXml': l10n.baseLocaleForXml.value,
          },
        },
        'branches': <String, dynamic>{
          'master': git.branches.master,
          'develop': git.branches.develop,
          'test': git.branches.test,
          'featurePrefix': git.branches.featurePrefix,
          'remote': git.remote,
        },
      };

  /// Facts as a list of lines for a Markdown document.
  List<String> get lines {
    final branches = git.branches;
    final res = <String>[];

    if (rootPath.isNotEmpty) res.add('Project root: `$rootPath`');
    if (configPath.isNotEmpty) res.add('Alex config: `$configPath`');

    final name = packageName;
    if (name != null) {
      final version = packageVersion;
      res.add('Package: `$name`${version != null ? ' $version' : ''}'
          ' (${isFlutter ? 'Flutter' : 'Dart'})');
    }

    final fvm = fvmVersion;
    if (fvm != null) {
      res.add('Flutter: pinned with FVM ($fvm) - '
          'run `flutter` and `dart` through `fvm`');
    }

    if (hasL10n) {
      res.add(locales.isNotEmpty
          ? 'Locales (${locales.length}): '
              '${locales.map((l) => '`$l`').join(', ')}'
          : 'Locales: not detected - no ARB files in `${l10n.outputDir}`');

      res.add('ARB: `${p.join(l10n.outputDir, l10n.translationFilesPattern)}`, '
          'strings source: `${l10n.sourceFile}`');

      res.add('XML for translation: `${l10n.xmlOutputDir}`, '
          'base locale for XML: `${l10n.baseLocaleForXml.value}`, '
          'for ARB: `${l10n.baseLocaleForArb.value}`');
    }

    if (packages.length > 1) {
      res.add('Packages (${packages.length}): '
          '${packages.map((p) => '`${p.name}` (`${p.path}`)').join(', ')}');
    }

    res.add('Branches: master `${branches.master}`, '
        'develop `${branches.develop}`, test `${branches.test}`, '
        'feature prefix `${branches.featurePrefix}`, '
        'remote `${git.remote}`');

    return res;
  }

  static Future<List<ProjectPackage>> _packages() async {
    try {
      final files = await Spec.getPubspecs();

      final res = <ProjectPackage>[];
      for (final file in files) {
        try {
          final spec = Spec.byFile(file);
          final dir = p.dirname(p.relative(file.path, from: p.current));
          res.add(ProjectPackage(
            name: spec.name,
            path: dir.isEmpty ? '.' : dir,
          ));
        } on Object catch (_) {
          // Broken pubspec - just not a package in the list.
        }
      }

      return res;
    } on Object catch (_) {
      return const [];
    }
  }

  static String? _fvmVersion() {
    for (final path in const ['.fvmrc', '.fvm/fvm_config.json']) {
      final file = File(path);
      if (!file.existsSync()) continue;

      try {
        final data = jsonDecode(file.readAsStringSync());
        if (data is! Map) continue;

        final version = data['flutter'] ?? data['flutterSdkVersion'];
        if (version is String && version.isNotEmpty) return version;
      } on FormatException catch (_) {
        // Broken config - just no fact about FVM.
      }
    }

    return null;
  }

  /// Returns locales of the [fileNames] that match the ARB files [pattern]
  /// (`intl_{locale}.arb` and alike), sorted.
  ///
  /// The file with the extracted messages (`intl_messages.arb`) matches the
  /// pattern too, but it's not a locale, so it's skipped.
  static List<String> parseLocales(Iterable<String> fileNames, String pattern) {
    // A locale can have a numeric region (es_419, en_001)
    // and can be written through a dash.
    final escaped = RegExp.escape(pattern)
        .replaceFirst(RegExp.escape('{locale}'), '([a-zA-Z0-9_-]+)');
    final regExp = RegExp('^$escaped\$');

    final res = <String>[];
    for (final name in fileNames) {
      final match = regExp.firstMatch(name);
      if (match == null) continue;

      final locale = match.group(1)!;
      if (locale == L10nUtils.arbMessagesSuffix) continue;

      res.add(locale);
    }

    res.sort();
    return res;
  }

  static List<String> _locales(L10nConfig config) {
    final dir = Directory(config.outputDir);
    if (!dir.existsSync()) return const [];

    final names = dir
        .listSync()
        .whereType<File>()
        .map((f) => p.basename(f.path))
        .toList(growable: false);

    return parseLocales(names, config.translationFilesPattern);
  }
}

/// Package of the project.
class ProjectPackage {
  final String name;

  /// Path to the package directory, relative to the project root.
  final String path;

  const ProjectPackage({required this.name, required this.path});

  Map<String, dynamic> toJson() => <String, dynamic>{
        'name': name,
        'path': path,
      };
}
