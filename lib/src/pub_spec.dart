import 'dart:async';
import 'dart:io';

import 'package:alex/src/fs/fs.dart';
import 'package:glob/glob.dart';
import 'package:glob/list_local_fs.dart';
import 'package:logging/logging.dart';
import 'package:path/path.dart' as p;
import 'package:pubspec_yaml_2/pubspec_yaml_2.dart';
import 'package:version/version.dart';

/// Some specification.
class Spec {
  static const fileName = "pubspec.yaml";
  static final _pubspecSearch = Glob("**$fileName");
  static final _logger = Logger('pubspec');

  /// Returns specification of a project in current directory.
  static Future<Spec> pub(FileSystem fs) async {
    final contents = await fs.readString(fileName);
    final yamlMap = contents.toPubspecYaml();
    return Spec(yamlMap);
  }

  /// Returns `true` if pubspec is exists in current directory.
  static Future<bool> exists(FileSystem fs) => fs.existsFile(fileName);

  static List<File> getPubspecsSync() {
    final projectPath = p.current;
    final pubspecFiles = <File>[];

    for (final file in _pubspecSearch.listSync(
      root: projectPath,
      followLinks: false,
    )) {
      _getPubspecsBody(file, pubspecFiles, projectPath);
    }

    return _getPubspecsEnd(pubspecFiles);
  }

  static Future<List<File>> getPubspecs() async {
    final projectPath = p.current;
    final pubspecFiles = <File>[];

    await for (final file in _pubspecSearch.list(
      root: projectPath,
      followLinks: false,
    )) {
      _getPubspecsBody(file, pubspecFiles, projectPath);
    }

    return _getPubspecsEnd(pubspecFiles);
  }

  static void _getPubspecsBody(
      FileSystemEntity file, List<File> pubspecFiles, String rootPath) {
    // we can add specific folders/subpath to ignore here
    const ignoredDirs = <String>[];

    if (file is! File) return;

    final path = file.path;
    if (p.basename(path) != fileName) return;

    final relatedPath = p.relative(path, from: rootPath);
    final checkPath = '${p.separator}$relatedPath';

    // ignore all inside hidden directories
    final hiddenPrefix = '${p.separator}.';
    if (checkPath.contains(hiddenPrefix)) {
      _logger.finest('- Skip  ${file.path}: ignored by hidden parent dir');
      return;
    }

    // ignore by specific folder
    if (ignoredDirs.any((dir) => checkPath.contains('/$dir/'))) {
      _logger.finest('- Skip  ${file.path}: ignored by dir');
      return;
    }

    _logger.finest('+ Found ${file.path}');
    pubspecFiles.add(file);
  }

  static List<File> _getPubspecsEnd(List<File> pubspecFiles) {
    if (pubspecFiles.isEmpty) {
      _logger.info('Pubspec files are not found');
    } else {
      // file in the root folder should be first than any nested
      pubspecFiles.sort((a, b) {
        final aPath = a.path;
        final bPath = b.path;

        final aPartsLen = p.split(aPath).length;
        final bPartsLen = p.split(bPath).length;
        if (aPartsLen != bPartsLen) {
          final aParent = p.dirname(aPath);
          final bParent = p.dirname(bPath);

          if (aParent.startsWith(bParent) || bParent.startsWith(aParent)) {
            return aPartsLen - bPartsLen;
          }
        }

        return aPath.compareTo(bPath);
      });
    }

    return pubspecFiles;
  }

  final PubspecYaml _yamlMap;

  Spec(this._yamlMap);

  factory Spec.byString(String yaml) => Spec(yaml.toPubspecYaml());
  factory Spec.byFile(File yaml) => Spec.byString(yaml.readAsStringSync());

  /// Returns name.
  String get name => _yamlMap.name;

  /// Returns version.
  ///
  /// Throws exception if no version found.
  Version get version => Version.parse(
      _yamlMap.version.valueOr(() => throw StateError('Version not found')));

  /// Updates version.
  Spec setVersion(Version value) {
    return Spec(_yamlMap.copyWith(version: Optional.value("$value")));
  }

  String getContent() {
    final file = File(fileName);
    return file.readAsStringSync();
  }

  void saveContent(String content) {
    final file = File(fileName);
    file.writeAsStringSync(content);
  }

  bool hasEnvironmentConstraint() => _yamlMap.environment.isNotEmpty;

  bool hasAnyDependencies() =>
      _yamlMap.dependencies.isNotEmpty || _yamlMap.devDependencies.isNotEmpty;

  bool hasDependency(String name) =>
      _hasDependency(_yamlMap.dependencies, name);

  bool hasDevDependency(String name) =>
      _hasDependency(_yamlMap.devDependencies, name);

  bool dependsOn(String name) => hasDependency(name) || hasDevDependency(name);

  bool _hasDependency(
          Iterable<PackageDependencySpec> dependencies, String name) =>
      dependencies.any((d) => d.package() == name);

  bool isResolveFromWorkspace() =>
      _yamlMap.resolution.valueOr(() => '') == 'workspace';

  bool isWorkspaceRoot() => _yamlMap.workspace?.isNotEmpty ?? false;
}
