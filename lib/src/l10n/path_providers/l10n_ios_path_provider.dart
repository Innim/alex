import 'dart:async';
import 'dart:io';

import 'package:alex/src/l10n/locale/locales.dart';
import 'package:logging/logging.dart';
import 'package:recase/recase.dart';
import 'package:path/path.dart' as path;

class L10nIosPathProvider {
  static const _xmlPrefix = 'ios_';
  static const _stringsExt = '.strings';

  static final _logger = Logger('is_path_provider');

  final String projectPath;

  const L10nIosPathProvider(this.projectPath);

  factory L10nIosPathProvider.from(Set<String> dirs) {
    for (final dirPath in dirs) {
      final provider = L10nIosPathProvider(dirPath);
      _logger.finest('Check $dirPath');
      if (provider.iosProjectDir.existsSync()) return provider;
      _logger.fine("Skip $dirPath: doesn't contain ios project folder");
    }

    throw Exception("Can't find valid directory for ios among provided");
  }

  String get iosProjectPath => path.join(projectPath, 'ios');

  Directory get iosProjectDir => Directory(iosProjectPath);

  Future<void> forEachLocalizationFile(XmlLocale locale,
      FutureOr<void> Function(String projectName, File file) f) async {
    final iosLocale = locale.toIosLocale();
    await for (final item in iosProjectDir.list()) {
      if (item is Directory) {
        final tmpName = path.basename(item.path);
        final tmpDir = getLocalizationDir(tmpName, iosLocale);
        if (await tmpDir.exists()) {
          await for (final file in tmpDir.list()) {
            if (file is File && file.path.endsWith(_stringsExt)) {
              final res = f(tmpName, file);
              if (res is Future<void>) {
                await res;
              }
            }
          }
        }
      }
    }
  }

  String getTargetFileName(String xmlFileName) {
    var filename = path.withoutExtension(xmlFileName);
    if (filename.startsWith(_xmlPrefix)) {
      filename = filename.replaceFirst(_xmlPrefix, '');
    }

    return path.setExtension(filename.pascalCase, _stringsExt);
  }

  String getXmlFileName(String iosFileName, {bool withoutExtension = false}) {
    final baseName = path.withoutExtension(iosFileName).snakeCase;
    var res = '$_xmlPrefix$baseName';

    if (!withoutExtension) {
      res = path.setExtension(res, '.xml');
    }

    return res;
  }

  Directory getLocalizationDir(String projectName, IosLocale iosLocale) {
    return Directory(getLocalizationDirPath(projectName, iosLocale));
  }

  File getLocalizationFile(
      String projectName, IosLocale iosLocale, String targetFileName) {
    return File(
        getLocalizationFilePath(projectName, iosLocale, targetFileName));
  }

  String getLocalizationDirPath(String projectName, IosLocale iosLocale) {
    return path.join(iosProjectPath, '$projectName/$iosLocale.lproj');
  }

  String getLocalizationFilePath(
      String projectName, IosLocale iosLocale, String targetFileName) {
    return path.join(
        getLocalizationDirPath(projectName, iosLocale), targetFileName);
  }
}
