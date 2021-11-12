import 'dart:io';

import 'package:alex/src/fs/fs.dart';
import 'package:plain_optional/plain_optional.dart';
import 'package:pubspec_yaml/pubspec_yaml.dart';
import 'package:version/version.dart';

/// Some specification.
class Spec {
  static const fileName = "pubspec.yaml";

  /// Returns specification of a project in current directory.
  static Future<Spec> pub(FileSystem fs) async {
    final contents = await fs.readString(fileName);
    final yamlMap = contents.toPubspecYaml();
    return Spec(yamlMap);
  }

  /// Returns `true` if pubspec is exists in current directory.
  static Future<bool> exists(FileSystem fs) => fs.existsFile(fileName);

  final PubspecYaml _yamlMap;

  Spec(this._yamlMap) : assert(_yamlMap != null);

  factory Spec.byString(String yaml) {
    assert(yaml != null);
    return Spec(yaml.toPubspecYaml());
  }

  /// Returns name.
  String get name => _yamlMap.name;

  /// Returns version.
  ///
  /// Throws exception if no version found.
  Version get version =>
      _yamlMap.version.iif(some: Version.parse, none: () => null);

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
