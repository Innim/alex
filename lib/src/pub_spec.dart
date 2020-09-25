import 'dart:io';

import 'package:plain_optional/plain_optional.dart';
import 'package:pubspec_yaml/pubspec_yaml.dart';
import 'package:version/version.dart';

/// Some specifiaction.
class Spec {
  static const _pubspec = "pubspec.yaml";

  /// Returns specification of a project in current directory.
  static Spec pub() {
    var yamlMap = File(_pubspec).readAsStringSync().toPubspecYaml();
    return Spec(yamlMap);
  }

  final PubspecYaml _yamlMap;

  Spec(this._yamlMap) : assert(_yamlMap != null);

  /// Returns version.
  ///
  /// Throws exception if no version found.
  Version get version =>
      _yamlMap.version.iif(some: (v) => Version.parse(v), none: () => null);

  /// Updates version.
  Spec setVersion(Version value) {
    return Spec(_yamlMap.copyWith(version: Optional("$value")));
  }

  /// Saves to `_pubspec` file.
  void save() {
    final file = File(_pubspec);
    file.writeAsString(_yamlMap.toYamlString());
  }
}
