import 'dart:io';

import 'package:alex/alex.dart';
import 'package:alex/commands/l10n/src/l10n_command_base.dart';
import 'package:alex/src/exception/run_exception.dart';
import 'package:path/path.dart' as path;

/// Command to import transalations from Google Play
/// to the project's xml files.
class ImportXmlCommand extends L10nCommandBase {
  static const _argPath = 'path';

  ImportXmlCommand()
      : super(
          'import_xml',
          'Import transalations from Google Play '
              "to the project's xml files",
        ) {
    argParser
      ..addOption(
        _argPath,
        abbr: 'p',
        help: 'Path to the durectory with translations from Google Play.',
        valueHelp: 'PATH',
      );
  }

  @override
  Future<int> run() async {
    final sourcePath = argResults[_argPath] as String;

    if (sourcePath == null) {
      printUsage();
      return success();
    }

    printVerbose('Import transalations from: $sourcePath.');

    final config = l10nConfig;

    try {
      return _importFromGooglePlay(config, sourcePath);
    } on RunException catch (e) {
      return errorBy(e);
    } catch (e) {
      return error(1, message: 'Failed by: $e');
    }
  }

  Future<int> _importFromGooglePlay(
      L10nConfig config, String sourcePath) async {
    final filename = config.getMainXmlFileName();

    final sourceDir = await _requireDirectory(sourcePath);

    final translationUid = path.basename(sourcePath);
    final projectUid = path.withoutExtension(filename);

    // TODO: check that all locales (rather than base and gp base) presented
    final imported = <String>[];

    // if multiple files - than it's in subdirectory,
    // if single file - it's directly in root
    await for (final item in sourceDir.list()) {
      final name = path.basename(item.path);
      if (name.startsWith(translationUid)) {
        if (item is Directory) {
          final googlePlayLocale = name.replaceFirst('${translationUid}_', '');
          await _importFile(config, imported, item, projectUid, translationUid,
              googlePlayLocale, filename);
        } else if (item is File && item.path.endsWith('.xml')) {
          final googlePlayLocale =
              name.replaceFirst('${translationUid}_', '').split('_').first;
          await _importFile(config, imported, sourceDir, projectUid,
              translationUid, googlePlayLocale, filename);
        }
      }
    }

    if (imported.isEmpty) {
      return error(2, message: 'There is no files for import in $sourcePath');
    } else {
      return success(
          message: 'Success. Imported locales (${imported.length}): '
              '${imported.join(", ")}.');
    }
  }

  Future<void> _importFile(
      L10nConfig config,
      List<String> imported,
      Directory sourceDir,
      String projectUid,
      String translationUid,
      String googlePlayLocale,
      String filename) async {
    print('googlePlayLocale: $googlePlayLocale');
    final locale = _convertGooglePlayLocale(googlePlayLocale);

    final uidWithName = '${translationUid}_${googlePlayLocale}';
    final sourceFileName = '${uidWithName}_${projectUid}.xml';
    final sourceFile =
        await _requireFile(path.join(sourceDir.path, sourceFileName));

    final targetDir = await _requireDirectory(config.getXmlFilesPath(locale),
        createIfNotExist: true);
    final targetFile = File(path.join(targetDir.path, filename));
    printVerbose('Copy $sourceFile to $targetFile');
    await sourceFile.copy(targetFile.path);

    imported.add(locale);
  }

  Future<Directory> _requireDirectory(String path,
      {bool createIfNotExist = false}) async {
    var dir = Directory(path);
    final exist = await dir.exists();
    if (!exist) {
      if (createIfNotExist) {
        dir = await dir.create(recursive: true);
      } else {
        throw RunException(1, 'Directory $path is not exist');
      }
    }
    return dir;
  }

  Future<File> _requireFile(String path) async {
    final file = File(path);
    final exist = await file.exists();
    if (!exist) throw RunException(1, 'File $path is not exist');
    return file;
  }

  String _convertGooglePlayLocale(String value) {
    return value.replaceAll('-', '_');
  }
}
