import 'dart:io';

import 'package:alex/alex.dart';
import 'package:alex/commands/l10n/src/l10n_command_base.dart';
import 'package:alex/src/exception/run_exception.dart';
import 'package:path/path.dart' as path;

/// Command to import translations from Google Play
/// to the project's xml files.
class ImportXmlCommand extends L10nCommandBase {
  static const _argPath = 'path';
  static const _argFile = 'file';
  static const _argTarget = 'target';
  static const _argAll = 'all';
  static const _argNew = 'new';

  static const _localeJoint = '_';

  ImportXmlCommand()
      : super(
          'import_xml',
          'Import translations from Google Play '
              "to the project's xml files. "
              'By default only files for existing locales will be imported. '
              'If you want to import new locales, use --$_argNew argument.',
        ) {
    argParser
      ..addOption(
        _argPath,
        abbr: 'p',
        help: 'Path to the directory with translations from Google Play.',
        valueHelp: 'PATH',
      )
      ..addOption(
        _argFile,
        abbr: 'f',
        help: 'Filename for import (without extension). '
            'For example: intl, strings, info_plist, etc. '
            'By default main localization file will be imported. '
            'You can use --$_argAll to import all files.',
        valueHelp: 'FILENAME',
      )
      ..addOption(
        _argTarget,
        abbr: 't',
        help: 'Target filename, which will be imported (without extension). '
            'For example if translation file has incorrect name "intl_en", '
            'you can provider expected target name "intl" with this argument. '
            "Can't be used if --$_argAll passed.",
        valueHelp: 'FILENAME',
      )
      ..addFlag(
        _argAll,
        help: 'Import all files from provided path.',
      )
      ..addFlag(
        _argNew,
        help: 'Import files for new locales from provided path.',
      );
  }

  @override
  Future<int> doRun() async {
    final args = argResults!;
    final sourcePath = args[_argPath] as String?;
    final fileForImport = args[_argFile] as String?;
    final targetFileName = args[_argTarget] as String?;
    final importAll = args[_argAll] as bool;
    final importNew = args[_argNew] as bool;

    if (sourcePath == null) {
      printUsage();
      return success();
    }

    if (importAll) {
      printVerbose('Import all translations from: $sourcePath.');
      if (fileForImport != null) {
        return error(1,
            message:
                "You can't use argument --$_argFile along with --$_argAll");
      }

      if (targetFileName != null) {
        return error(1,
            message:
                "You can't use argument --$_argTarget along with --$_argAll");
      }
    } else {
      printVerbose(
          // ignore: prefer_interpolation_to_compose_strings
          'Import ${fileForImport ?? 'main'} translations from: $sourcePath' +
              (targetFileName != null ? ' to $targetFileName.' : '.'));
    }

    final config = findConfigAndSetWorkingDir();
    final l10nConfig = config.l10n;

    final locales = importNew ? null : await getLocales(l10nConfig);

    try {
      return _importFromGooglePlay(
        l10nConfig,
        sourcePath,
        fileForImport: fileForImport,
        targetFileName: targetFileName,
        importAll: importAll,
        locales: locales,
      );
    } on RunException catch (e) {
      return errorBy(e);
    } catch (e) {
      return error(2, message: 'Failed by: $e');
    }
  }

  Future<int> _importFromGooglePlay(
    L10nConfig config,
    String sourcePath, {
    String? fileForImport,
    String? targetFileName,
    bool importAll = false,
    List<String>? locales,
  }) async {
    final srcFilename = importAll
        ? null
        : (fileForImport == null
            ? config.getMainXmlFileName()
            : _getFilenameByBaseName(fileForImport));
    final destFilename = importAll
        ? null
        : (targetFileName == null
            ? srcFilename
            : _getFilenameByBaseName(targetFileName));

    final sourceDir = await _requireDirectory(sourcePath);

    final translationUid = path.basename(sourcePath);
    final projectUid =
        srcFilename != null ? path.withoutExtension(srcFilename) : null;

    // TODO: check that all locales (rather than base and gp base) presented
    final imported = <String>{};

    Future<void> import(
            Directory sourceDir, String sourceFilename, String googlePlayLocale,
            [String? gpProjectUid, String? targetFilename]) =>
        _importFile(
            config,
            imported,
            sourceDir,
            sourceFilename,
            gpProjectUid ?? projectUid,
            translationUid,
            googlePlayLocale,
            targetFilename ?? destFilename,
            locales);

    // In some cases source filename may be just base filename
    // but we don't know for sure
    bool? useBaseName;

    // if multiple files - than it's in subdirectory,
    // if single file - it's directly in root
    await for (final item in sourceDir.list()) {
      final name = path.basename(item.path);
      if (name.startsWith(translationUid)) {
        if (item is Directory) {
          // file paths like:
          // d_11f922c9b/d_11f922c9b_ko/d_11f922c9b_ko_intl.xml
          final googlePlayLocale = name.replaceFirst('${translationUid}_', '');
          final uidWithName = '${translationUid}_$googlePlayLocale';
          if (projectUid != null) {
            final compositeFilename = '${uidWithName}_$projectUid.xml';

            useBaseName ??=
                !File(path.join(item.path, compositeFilename)).existsSync() &&
                    File(path.join(item.path, srcFilename)).existsSync();

            final sourceFilename =
                useBaseName ? srcFilename! : compositeFilename;

            await import(item, sourceFilename, googlePlayLocale);
          } else {
            await for (final file in item.list()) {
              final sourceFilename = path.basename(file.path);
              // TODO: add "or equal to target file name"?
              if (!sourceFilename.startsWith(uidWithName)) {
                printInfo('Skip $sourceFilename');
                continue;
              }

              final curProjectUid = path
                  .withoutExtension(sourceFilename)
                  .substring(uidWithName.length + 1);
              final curFileName = _getFilenameByBaseName(curProjectUid);
              await import(item, sourceFilename, googlePlayLocale,
                  curProjectUid, curFileName);
            }
          }
        } else if (item is File && item.path.endsWith('.xml')) {
          // file paths like:
          // d_11f922f82/d_11f922f82_ar_intl.xml
          // intl/intl_de.xml
          final googlePlayLocale = path
              .withoutExtension(name)
              .replaceFirst('${translationUid}_', '')
              .split('_')
              .first;
          await import(sourceDir, name, googlePlayLocale);
        }
      }
    }

    if (imported.isEmpty) {
      return error(2, message: 'There is no files for import in $sourcePath');
    } else {
      final importedLocales = imported.join(", ");
      // TODO: писать сколько всего должно быть? или может даже ошибку выдать?
      return success(
          message: 'Success. Imported locales (${imported.length}): '
              '$importedLocales.');
    }
  }

  String _getFilenameByBaseName(String name) => path.setExtension(name, '.xml');

  Future<void> _importFile(
      L10nConfig config,
      Set<String> imported,
      Directory sourceDir,
      String sourceFilename,
      String? projectUid,
      String translationUid,
      String googlePlayLocale,
      String? targetFilename,
      List<String>? allowedLocales) async {
    var locale = _convertGooglePlayLocale(googlePlayLocale);

    if (allowedLocales != null && !allowedLocales.contains(locale)) {
      // Maybe we have locale with region in an app
      if (!locale.contains(_localeJoint) &&
          allowedLocales.any((l) => l.startsWith(locale))) {
        final allowedLocale =
            allowedLocales.firstWhere((l) => l.startsWith(locale));
        printInfo('Locale $locale not found: '
            'import $googlePlayLocale to $allowedLocale');
        locale = allowedLocale;
      } else {
        printInfo('Skip locale $locale');
        return;
      }
    }

    if (imported.contains(locale)) {
      throw RunException.warn(
          'Duplicate import for locale $locale (original: $googlePlayLocale)');
    }

    final sourceFile =
        await _requireFile(path.join(sourceDir.path, sourceFilename));

    final targetDir = await _requireDirectory(config.getXmlFilesPath(locale),
        createIfNotExist: true);
    final targetFile = File(path.join(targetDir.path, targetFilename));
    printVerbose('Copy ${sourceFile.path} to ${targetFile.path}');
    await sourceFile.copy(targetFile.path);

    imported.add(locale);
  }

  // TODO: may be move to some utils or base class
  Future<Directory> _requireDirectory(String path,
      {bool createIfNotExist = false}) async {
    var dir = Directory(path);
    final exist = await dir.exists();
    if (!exist) {
      if (createIfNotExist) {
        dir = await dir.create(recursive: true);
      } else {
        throw RunException.warn('Directory $path is not exist');
      }
    }
    return dir;
  }

  // TODO: may be move to some utils or base class
  Future<File> _requireFile(String path) async {
    final file = File(path);
    final exist = await file.exists();
    if (!exist) throw RunException.warn('File $path is not exist');
    return file;
  }

  String _convertGooglePlayLocale(String value) {
    final parts = value.split('-');
    if (parts.length > 1) {
      assert(parts.length == 2);
      final lang = _convertLang(parts[0]);
      final region = parts[1].toUpperCase();
      return '$lang$_localeJoint$region';
    } else {
      return _convertLang(parts.first);
    }
  }

  String _convertLang(String lang) {
    // Some locales on Google Play Translations
    // use different lang code
    // than we have in an app.
    const langMap = <String, String>{
      'iw': 'he',
    };

    return langMap[lang] ?? lang;
  }
}
