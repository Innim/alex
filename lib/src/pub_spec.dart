import 'dart:io';

import 'package:version/version.dart';
import 'package:yaml/yaml.dart';

/// Some specifiaction.
class Spec {
  static const _pubspec = "pubspec.yaml";

  /// Returns specification of a project in current directory.
  static Spec pub() {
    var yamlMap = loadYaml(File(_pubspec).readAsStringSync()) as YamlMap;
    return Spec(yamlMap);
  }

  final YamlMap _yamlMap;

  Spec(this._yamlMap) : assert(_yamlMap != null);

  /// Returns version.
  ///
  /// Throws exception if no version found.
  Version get version => Version.parse(getString("version"));

  /// Returns string value of specification by its' key.
  String getString(String key) => _yamlMap[key] as String;
}
