import 'dart:io';

import 'package:version/version.dart';
import 'package:yaml/yaml.dart';

class PubSpec {
  static const _pubspec = 'pubspec.yaml';

  static PubSpec read() {
    var yamlMap = loadYaml(File(_pubspec).readAsStringSync()) as YamlMap;
    return PubSpec(yamlMap);
  }

  final YamlMap _yamlMap;

  PubSpec(this._yamlMap) : assert(_yamlMap != null);

  Version get version => Version.parse(getString("version"));

  String getString(String key) => _yamlMap[key] as String;
}
