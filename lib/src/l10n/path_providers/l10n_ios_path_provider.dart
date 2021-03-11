import 'dart:io';

import 'package:recase/recase.dart';
import 'package:path/path.dart' as path;

class L10nIosPathProvider {
  static const _xmlPrefix = 'ios_';

  final String projectPath;

  const L10nIosPathProvider(this.projectPath);

  String get iosProjectPath => path.join(path.current, 'ios');

  Directory get iosProjectDir => Directory(iosProjectPath);

  String getTargetFileName(String xmlFileName) {
    var filename = path.withoutExtension(xmlFileName);
    if (filename.startsWith(_xmlPrefix)) {
      filename = filename.replaceFirst(_xmlPrefix, '');
    }

    return path.setExtension(filename.pascalCase, '.strings');
  }

  String getXmlFileName(String iosFileName, {bool withouExtension = false}) {
    final baseName = path.withoutExtension(iosFileName).snakeCase;
    var res = '$_xmlPrefix$baseName';

    if (!withouExtension) {
      res = path.setExtension(res, '.xml');
    }

    return res;
  }

  String getIosLocale(String locale) => locale.replaceAll('_', '-');

  Directory getLocalizationDir(String projectName, String iosLocale) {
    return Directory(getLocalizationDirPath(projectName, iosLocale));
  }

  File getLocalizationFile(
      String projectName, String iosLocale, String targetFileName) {
    return File(
        getLocalizationFilePath(projectName, iosLocale, targetFileName));
  }

  String getLocalizationDirPath(String projectName, String iosLocale) {
    return path.join(iosProjectPath, '$projectName/$iosLocale.lproj');
  }

  String getLocalizationFilePath(
      String projectName, String iosLocale, String targetFileName) {
    return path.join(
        getLocalizationDirPath(projectName, iosLocale), targetFileName);
  }
}
