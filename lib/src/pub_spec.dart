import 'dart:io';

import 'package:alex/commands/release/fs.dart';
import 'package:plain_optional/plain_optional.dart';
import 'package:pubspec_yaml/pubspec_yaml.dart';
import 'package:version/version.dart';

/// Some specification.
class Spec {
  static const _pubspec = "pubspec.yaml";

  /// Returns specification of a project in current directory.
  static Future<Spec> pub(FileSystem fs) async {
    final contents = await fs.readString(_pubspec);
    final yamlMap = contents.toPubspecYaml();
    return Spec(yamlMap);
  }

  final PubspecYaml _yamlMap;

  Spec(this._yamlMap) : assert(_yamlMap != null);

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
    final file = File(_pubspec);
    return file.readAsStringSync();
  }

  void saveContent(String content) {
    final file = File(_pubspec);
    file.writeAsStringSync(content);
  }
}
