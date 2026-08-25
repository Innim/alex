import 'dart:async';
import 'dart:io';

import 'package:alex/src/exception/run_exception.dart';
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

  /// A top level `version` key with its value.
  static final _versionDefinition =
      RegExp(r'^(version:[ \t]*)(\S+)', multiLine: true);

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

  /// Returns version or `null` if there is no version in the pubspec.
  Version? get versionOrNull {
    final value = _yamlMap.version.valueOr(() => '');
    return value.isEmpty ? null : Version.parse(value);
  }

  /// Updates version.
  Spec setVersion(Version value) {
    return Spec(_yamlMap.copyWith(version: Optional.value("$value")));
  }

  /// Returns the [content] of a pubspec.yaml with the replaced version.
  ///
  /// Only the version value itself is replaced,
  /// so the rest of the file is kept as is, including a trailing comment
  /// of the version line.
  ///
  /// Throws a [RunException] if there is no version definition
  /// in the [content].
  static String replaceVersion(String content, Version value) {
    final match = _versionDefinition.firstMatch(content);
    if (match == null) {
      throw const RunException.err(
          'There is no version definition in $fileName. '
          'Add a line like "version: 1.0.0+1" in the file.');
    }

    return content.replaceRange(match.start, match.end, '${match[1]}$value');
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
