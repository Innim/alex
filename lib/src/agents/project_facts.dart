import 'dart:convert';
import 'dart:io';

import 'package:alex/src/config.dart';
import 'package:alex/src/fs/fs.dart';
import 'package:alex/src/pub_spec.dart';
import 'package:path/path.dart' as p;

/// Facts about the project that an AI agent or a script needs to know.
///
/// Collected from the alex configuration and the project files,
/// so they can't diverge from the project.
class ProjectFacts {
  final String? packageName;
  final String? packageVersion;

  /// Version of Flutter pinned with FVM, if the project uses it.
  final String? fvmVersion;

  /// Locales of the app, by the ARB files.
  final List<String> locales;

  final L10nConfig l10n;
  final AlexGitConfig git;

  const ProjectFacts({
    required this.l10n,
    required this.git,
    this.packageName,
    this.packageVersion,
    this.fvmVersion,
    this.locales = const [],
  });

  /// Collects the facts of the project with the [config].
  ///
  /// Should be called with the project root as a current directory.
  static Future<ProjectFacts> collect(AlexConfig config) async {
    String? name;
    String? version;

    try {
      final spec = await Spec.pub(const IOFileSystem());
      name = spec.name;
      version = spec.versionOrNull?.toString();
    } on Object catch (_) {
      // Pubspec is optional for the facts.
    }

    return ProjectFacts(
      l10n: config.l10n,
      git: config.git,
      packageName: name,
      packageVersion: version,
      fvmVersion: _fvmVersion(),
      locales: _locales(config.l10n),
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        if (packageName != null) 'package': packageName,
        if (packageVersion != null) 'version': packageVersion,
        if (fvmVersion != null) 'fvm': fvmVersion,
        'locales': locales,
        'l10n': <String, dynamic>{
          'arbDir': l10n.outputDir,
          'arbPattern': l10n.translationFilesPattern,
          'sourceFile': l10n.sourceFile,
          'xmlDir': l10n.xmlOutputDir,
          'baseLocaleForArb': l10n.baseLocaleForArb.value,
          'baseLocaleForXml': l10n.baseLocaleForXml.value,
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

    final name = packageName;
    if (name != null) {
      final version = packageVersion;
      res.add('Package: `$name`${version != null ? ' $version' : ''}');
    }

    final fvm = fvmVersion;
    if (fvm != null) {
      res.add('Flutter: pinned with FVM ($fvm) - '
          'run `flutter` and `dart` through `fvm`');
    }

    res.add(locales.isNotEmpty
        ? 'Locales (${locales.length}): '
            '${locales.map((l) => '`$l`').join(', ')}'
        : 'Locales: not detected - no ARB files in `${l10n.outputDir}`');

    res.add('ARB: `${p.join(l10n.outputDir, l10n.translationFilesPattern)}`, '
        'strings source: `${l10n.sourceFile}`');

    res.add('XML for translation: `${l10n.xmlOutputDir}`, '
        'base locale for XML: `${l10n.baseLocaleForXml.value}`, '
        'for ARB: `${l10n.baseLocaleForArb.value}`');

    res.add('Branches: master `${branches.master}`, '
        'develop `${branches.develop}`, test `${branches.test}`, '
        'feature prefix `${branches.featurePrefix}`, '
        'remote `${git.remote}`');

    return res;
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
  static List<String> parseLocales(Iterable<String> fileNames, String pattern) {
    final escaped = RegExp.escape(pattern)
        .replaceFirst(RegExp.escape('{locale}'), '([a-zA-Z_]+)');
    final regExp = RegExp('^$escaped\$');

    final res = <String>[];
    for (final name in fileNames) {
      final match = regExp.firstMatch(name);
      if (match != null) res.add(match.group(1)!);
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
