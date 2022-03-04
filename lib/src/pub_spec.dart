import 'dart:async';
import 'dart:io';

import 'package:alex/src/fs/fs.dart';
import 'package:glob/glob.dart';
import 'package:glob/list_local_fs.dart';
import 'package:logging/logging.dart';
import 'package:path/path.dart' as p;
import 'package:plain_optional/plain_optional.dart';
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

    for (final file
        in _pubspecSearch.listSync(root: projectPath, followLinks: false)) {
      _getPubspecsBody(file, pubspecFiles);
    }

    return _getPubspecsEnd(pubspecFiles);
  }

  static Future<List<File>> getPubspecs() async {
    final projectPath = p.current;
    final pubspecFiles = <File>[];

    await for (final file
        in _pubspecSearch.list(root: projectPath, followLinks: false)) {
      _getPubspecsBody(file, pubspecFiles);
    }

    return _getPubspecsEnd(pubspecFiles);
  }

  static void _getPubspecsBody(FileSystemEntity file, List<File> pubspecFiles) {
    if (file is File && p.basename(file.path) == fileName) {
      _logger.finest('Found ${file.path}');
      pubspecFiles.add(file);
    }
  }

  static List<File> _getPubspecsEnd(List<File> pubspecFiles) {
    if (pubspecFiles.isEmpty) {
      _logger.info('Pubspec files are not found');
    }

    return pubspecFiles;
  }

  final PubspecYaml _yamlMap;

  Spec(this._yamlMap);

  factory Spec.byString(String yaml) {
    return Spec(yaml.toPubspecYaml());
  }

  /// Returns name.
  String get name => _yamlMap.name;

  /// Returns version.
  ///
  /// Throws exception if no version found.
  Version get version => _yamlMap.version.iif(
      some: Version.parse, none: () => throw StateError('Version not found'));

  /// Updates version.
  Spec setVersion(Version value) {
    return Spec(_yamlMap.copyWith(version: Optional("$value")));
  }

  String getContent() {
    final file = File(fileName);
    return file.readAsStringSync();
  }

  void saveContent(String content) {
    final file = File(fileName);
    file.writeAsStringSync(content);
  }

  bool hasDependency(String name) =>
      _hasDependency(_yamlMap.dependencies, name);

  bool hasDevDependency(String name) =>
      _hasDependency(_yamlMap.devDependencies, name);

  bool dependsOn(String name) => hasDependency(name) || hasDevDependency(name);

  bool _hasDependency(
          Iterable<PackageDependencySpec> dependencies, String name) =>
      dependencies.any((d) => d.package() == name);
}
