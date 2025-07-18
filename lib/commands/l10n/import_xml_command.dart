import 'dart:io';

import 'package:alex/alex.dart';
import 'package:alex/commands/l10n/src/l10n_command_base.dart';
import 'package:alex/src/exception/run_exception.dart';
import 'package:alex/src/l10n/locale/locales.dart';
import 'package:archive/archive_io.dart';
import 'package:path/path.dart' as path;
import 'package:xml/xml.dart';
import 'package:list_ext/list_ext.dart';

typedef _CompositeNameBuilder = String Function(String uidWithName);

/// Command to import translations from Google Play
/// to the project's xml files.
class ImportXmlCommand extends L10nCommandBase {
  static const _argPath = 'path';
  static const _argFile = 'file';
  static const _argTarget = 'target';
  static const _argAll = 'all';
  static const _argNew = 'new';
  static const _argDiffs = 'diffs';
  static const _argLocale = 'locale';

  static const _localeJoint = '_';

  ImportXmlCommand()
      : super(
          'import_xml',
          'Import translations from Google Play '
              "to the project's xml files. "
              'By default only files for existing locales will be imported. '
              'If you want to import new locales, use --$_argNew argument.\n'
              'If filename has suffix "${L10nUtils.diffsSuffix}" - it will be imported as a diff file. '
              'You can alter this behavior with --$_argDiffs argument.',
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
        help:
            'Target filename, to which the import will be made (without extension). '
            'For example if translation file has incorrect name "intl_en", '
            'you can provide the expected target name "intl" with this argument. '
            "Can't be used if --$_argAll passed.",
        valueHelp: 'FILENAME',
      )
      ..addOption(
        _argLocale,
        abbr: 'l',
        help: 'Locale for import. '
            'If not specified - all locales will be imported.',
        valueHelp: 'LOCALE',
      )
      ..addFlag(
        _argAll,
        help: 'Import all files from provided path.',
      )
      ..addFlag(
        _argNew,
        help: 'Import files for new locales from provided path.',
      )
      ..addFlag(
        _argDiffs,
        defaultsTo: null,
        help: 'Import strings as diffs or replace a whole file. '
            'If this argument is not defined, alex will decide how to export based on the filename.',
      );
  }

  @override
  Future<int> doRun() async {
    final args = argResults!;
    final sourcePath = args[_argPath] as String?;
    final fileForImport = args[_argFile] as String?;
    final targetFileName = args[_argTarget] as String?;
    final locale = args.getLocale(_argLocale);
    final importAll = args[_argAll] as bool;
    final importNew = args[_argNew] as bool;
    final importDiffs = args[_argDiffs] as bool?;

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

    if (locale != null) {
      printVerbose('Import only locale <$locale>');
    }

    final config = findConfigAndSetWorkingDir();
    final l10nConfig = config.l10n;

    final locales = locale != null
        ? [locale]
        : (importNew ? null : await getLocales(l10nConfig));

    return _importFromGooglePlay(
      l10nConfig,
      sourcePath,
      fileForImport: fileForImport,
      targetFileName: targetFileName,
      importAll: importAll,
      importDiffs: importDiffs,
      locales: locales,
    );
  }

  Future<int> _importFromGooglePlay(
    L10nConfig config,
    String sourcePath, {
    String? fileForImport,
    String? targetFileName,
    bool importAll = false,
    bool? importDiffs,
    List<XmlLocale>? locales,
  }) async {
    final srcFilename = importAll
        ? null
        : (fileForImport == null
            ? config.getMainXmlFileName()
            : _getFilenameByBaseName(fileForImport));
    // TODO: define dest file by name of imported file (change help for _argFile)
    final destFilename = importAll
        ? null
        : (targetFileName == null
            ? srcFilename
            : _getFilenameByBaseName(targetFileName));

    final bool isImportArchive;
    final Directory sourceDir;
    if (FileSystemEntity.isDirectorySync(sourcePath)) {
      sourceDir = await _requireDirectory(sourcePath);
      isImportArchive = false;
    } else if (FileSystemEntity.isFileSync(sourcePath)) {
      final sourceFile = File(sourcePath);
      final sourceExt = path.extension(sourcePath);

      if (sourceExt == '.zip') {
        sourceDir = await _extractZip(sourceFile);
        isImportArchive = true;
      } else if (sourceExt == '.xml') {
        // TODO: import single xml (sl, en)
        // TODO: add xml below in else's error message
        return error(
          2,
          message: 'Import of a single xml file is not supported yet. '
              'Stay tuned.',
        );
      } else {
        return error(
          2,
          message: 'Files with extension <$sourceExt> are not supported. '
              'Expected: zip.',
        );
      }
    } else {
      return error(2, message: 'Path $sourcePath is not directory or file');
    }

    printVerbose('Directory for import: ${sourceDir.path}');

    final importedDirName = path.basename(sourceDir.path);
    final isAllegedlyDiff = importedDirName.endsWith(L10nUtils.diffsSuffix);

    final translationName = isAllegedlyDiff
        ? L10nUtils.removeDiffsSuffix(importedDirName)
        : importedDirName;

    final translationNameWithDiffs = isAllegedlyDiff
        ? importedDirName
        : L10nUtils.addDiffsSuffix(importedDirName);

    final srcBaseName =
        srcFilename != null ? path.withoutExtension(srcFilename) : null;

    printVerbose('Start import.\n'
        '\tTranslation name: $translationName,\n'
        '\tAssumed imported file: $srcBaseName,\n'
        '\tSource: $srcFilename,\n'
        '\tDestination: $destFilename.');

    // TODO: check that all locales (rather than base and gp base) presented
    final imported = <XmlLocale>{};
    final skippedLocales = <String>{};
    final processedItems = <String>{};

    Future<void> import(
            Directory sourceDir, String sourceFilename, String googlePlayLocale,
            [String? targetFilename]) =>
        _importFile(
          config,
          imported,
          skippedLocales,
          sourceDir,
          sourceFilename,
          googlePlayLocale,
          targetFilename ?? destFilename,
          locales,
          importDiffs,
        );

    bool fileExist(Directory dir, String filename) {
      final res = File(path.join(dir.path, filename)).existsSync();
      printVerbose('File <$filename> - ${res ? 'exist' : 'not exist'}');
      return res;
    }

    // In some cases source filename may be just base filename
    // but we don't know for sure
    bool? useBaseName;
    String? baseFileName;
    _CompositeNameBuilder? compositeFilenameBuilder;

    String defaultCompositeBuilder(String uidWithName, [String? mainName]) =>
        '${uidWithName}_${mainName ?? srcBaseName}.xml';
    String diffsCompositeBuilder(String uidWithName) =>
        defaultCompositeBuilder(uidWithName).asDiffsName();

    // if multiple files - than it's in subdirectory,
    // if single file - it's directly in root
    final items = sourceDir.listSync()..sortBy((e) => path.basename(e.path));
    for (final item in items) {
      final name = path.basename(item.path);
      printVerbose('Processing: $name');
      if (name.startsWith(translationName)) {
        if (item is Directory) {
          final translationUid = translationName;
          // file paths like:
          // d_11f922c9b/d_11f922c9b_ko/d_11f922c9b_ko_intl.xml
          final googlePlayLocale = name.replaceFirst('${translationUid}_', '');
          final uidWithName = '${translationUid}_$googlePlayLocale';
          if (srcFilename != null) {
            bool checkBaseName(String? filename) {
              if (filename == null) return false;
              if (!fileExist(item, filename)) return false;
              baseFileName = filename;
              printVerbose('Set base name: $baseFileName');
              return true;
            }

            bool checkCompositeName(_CompositeNameBuilder builder) {
              final filename = builder(uidWithName);
              if (!fileExist(item, filename)) return false;
              compositeFilenameBuilder = builder;
              printVerbose('Set composite name: $filename');
              return true;
            }

            useBaseName ??= !checkCompositeName(defaultCompositeBuilder) &&
                !checkCompositeName(diffsCompositeBuilder) &&
                (checkBaseName(srcFilename) ||
                    checkBaseName(srcFilename.asDiffsName()));

            final sourceFilename = useBaseName
                ? baseFileName
                : compositeFilenameBuilder?.call(uidWithName);

            if (sourceFilename == null) {
              final sb =
                  StringBuffer("Couldn't find acceptable filename for import.");

              final filesInDirectory =
                  item.listSync().map((f) => path.basename(f.path));

              sb.writeln();
              if (filesInDirectory.isEmpty) {
                sb.write('No files in directory ${item.path}');
              } else {
                const lfp = " - ";
                sb
                  ..writeln('Following files was found in directory: ')
                  ..write(lfp)
                  ..write(filesInDirectory.join("\n$lfp"));

                final filenamePrefix = path.basenameWithoutExtension(
                    defaultCompositeBuilder(uidWithName, ''));

                final candidateFile = filesInDirectory
                    .firstWhereOrNull((e) => e.startsWith(filenamePrefix));

                final String? suggestFile;
                if (candidateFile != null) {
                  final invalidName = path
                      .basenameWithoutExtension(candidateFile)
                      .substring(filenamePrefix.length);

                  suggestFile = invalidName;
                } else {
                  suggestFile = null;
                }

                String? suggestTarget;
                if (targetFileName == null && suggestFile != null) {
                  // check for appropriate target file
                  // common error, than filename includes base or "en" locale
                  final baseLocale = config.baseLocaleForXml;
                  final junkSuffixes = {null, baseLocale, 'en'};

                  for (final suffix in junkSuffixes) {
                    final String guessName;
                    if (suffix == null) {
                      guessName = suggestFile;
                    } else {
                      final nameEnd = '_$suffix';
                      if (!suggestFile.endsWith(nameEnd)) continue;
                      guessName = suggestFile.substring(
                          0, suggestFile.length - nameEnd.length);
                    }

                    // check if exist
                    final guessFile = File(
                      path.join(
                        config.getXmlFilesPath(baseLocale),
                        _getFilenameByBaseName(guessName),
                      ),
                    );

                    if (guessFile.existsSync()) {
                      suggestTarget =
                          path.basenameWithoutExtension(guessFile.path);
                      break;
                    }
                  }
                }

                if (suggestTarget == null && destFilename != null) {
                  suggestTarget = path.basenameWithoutExtension(destFilename);
                }

                const point = ' - ';
                final subIndent = ' ' * point.length;
                sb
                  ..writeln('')
                  ..writeln('')
                  ..writeln('💡 Suggestions:');
                if (isImportArchive) {
                  sb
                    ..write(point)
                    ..write(
                        'Probably you are trying to import archive with unsupported content. '
                        'For now alex supports only archives from Google Play. ')
                    ..writeln()
                    ..write(subIndent)
                    ..write(
                        'Try to extract the archive and import the directory.')
                    ..writeln();
                }
                sb
                  ..write(point)
                  ..writeln(
                      'Probably the name of the imported file is incorrect, '
                      'try to specify the parameters explicitly:')
                  ..write(subIndent)
                  ..write('--$_argFile - Filename for import. '
                      'Name without uid, locale and extension. ');
                if (suggestFile != null) {
                  sb.write('E.g.: --$_argFile=$suggestFile');
                }

                sb
                  ..writeln()
                  ..write(subIndent)
                  ..write('--$_argTarget - Name of the file in the project '
                      'to which the import will be performed. '
                      'Name without extension and locale. ');
                if (suggestTarget != null) {
                  sb.write('E.g.: --$_argTarget=$suggestTarget');
                }

                sb
                  ..writeln('')
                  ..write(subIndent)
                  ..write('--$_argDiffs - If you are importing diffs file.');
              }

              throw RunException.err(sb.toString());
            }

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
              await import(
                  item, sourceFilename, googlePlayLocale, curProjectUid);
            }
          }
        } else if (item is File && item.path.endsWith('.xml')) {
          // file paths like:
          // d_11f922f82/d_11f922f82_ar_intl.xml
          // intl/intl_de.xml
          // intl_diffs/intl_diffs_de.xml
          // intl/intl_diffs_de.xml
          final baseName = name.startsWith(translationNameWithDiffs)
              ? translationNameWithDiffs
              : translationName;

          final googlePlayLocale = path
              .withoutExtension(name)
              .replaceFirst('${baseName}_', '')
              .split('_')
              .first;
          await import(sourceDir, name, googlePlayLocale);
        } else {
          printVerbose('Skipped because of invalid extension');
          continue;
        }
        processedItems.add(name);
      } else {
        printVerbose('Skipped because of discrepancy with translation UID');
      }
    }

    if (imported.isEmpty) {
      final folderNameHint = srcBaseName != null ? ' ($srcBaseName)' : '';
      return error(2,
          message: 'There is no files for import in $sourcePath\n'
              'Please, check the name of containing folder - '
              'it should be order UID if translation came from Google Play '
              'or base name of imported file$folderNameHint.');
    } else {
      final importedLocalesStr = imported.join(", ");
      final message =
          StringBuffer('Success. Imported locales (${imported.length}): ')
            ..write(importedLocalesStr)
            ..write('.');

      final projectLocales = await getLocales(config);

      message
        ..writeln()
        ..write('Project supports ')
        ..write(projectLocales.length)
        ..write(' locales (excluding base locale)');

      if (locales != null && locales.length != projectLocales.length) {
        message
          ..writeln()
          ..write(locales.length)
          ..write(' locales were allowed to import');
      } else if (imported.length < projectLocales.length - 1 &&
          processedItems.length > imported.length) {
        message
          ..writeln()
          ..write('Processed ${processedItems.length} items.');

        if (skippedLocales.isNotEmpty) {
          message.write(' Skipped locales: ${skippedLocales.join(', ')}.');
        }

        message
          ..writeln()
          ..write('⚠️ ATTENTION! This may indicate a problem. '
              'Make sure that all desired locales are imported.');
      }

      return success(message: message.toString());
    }
  }

  String _getFilenameByBaseName(String name) => path.setExtension(name, '.xml');

  Future<void> _importFile(
    L10nConfig config,
    Set<XmlLocale> imported,
    Set<String> skipped,
    Directory sourceDir,
    String sourceFilename,
    String googlePlayLocale,
    String? targetFilename,
    List<XmlLocale>? allowedLocales,
    bool? importDiffs,
  ) async {
    printVerbose('Import file $sourceFilename');
    final localeRaw = _convertGooglePlayLocale(googlePlayLocale);
    final XmlLocale locale;

    if (allowedLocales != null &&
        !allowedLocales.any((l) => l.value == localeRaw)) {
      // Maybe we have locale with region in an app
      final XmlLocale? allowedLocale;

      if (localeRaw.contains(_localeJoint)) {
        allowedLocale = null;
      } else {
        allowedLocale = allowedLocales.firstWhereOrNull(
            (l) => l.value.startsWith('$localeRaw$_localeJoint'));
      }

      if (allowedLocale != null) {
        printInfo('Locale $localeRaw not found: '
            'import $googlePlayLocale to $allowedLocale');
        locale = allowedLocale;
      } else {
        printInfo('Skip locale <$localeRaw>');
        skipped.add(localeRaw);
        return;
      }
    } else {
      locale = localeRaw.asXmlLocale();
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
    if (importDiffs ?? _isDiffs(sourceFilename, googlePlayLocale)) {
      await _importDifference(config, sourceFile, targetFile);
    } else {
      printVerbose('Copy ${sourceFile.path} to ${targetFile.path}');
      await sourceFile.copy(targetFile.path);
    }

    imported.add(locale);
  }

  bool _isDiffs(String sourceFilename, String localeInName) {
    final nameWithoutExtension = path.withoutExtension(sourceFilename);
    return nameWithoutExtension.endsWith(L10nUtils.diffsSuffix) ||
        nameWithoutExtension.endsWith('${L10nUtils.diffsSuffix}_$localeInName');
  }

  Future<void> _importDifference(
      L10nConfig config, File source, File target) async {
    printInfo('Import file ${source.path} as diff for ${target.path}');
    final baseLocale = config.baseLocaleForXml;
    final baseFileName = path.basename(target.path);
    final baseFile =
        File(path.join(config.getXmlFilesPath(baseLocale), baseFileName));
    if (baseFile.existsSync()) {
      printVerbose('Base XML: $baseFile');

      final baseXML = getXML(baseFile);
      final sourceXML = getXML(source);
      final targetXML = getXML(target);

      final sourceElements = sourceXML.resources.children.toList();
      final targetElements = targetXML.resources.children.toList();

      final outputElements = <XmlNode>{};

      baseXML.forEachResource((child) {
        if (child is XmlElement) {
          final element = sourceElements.firstWhereOrNull((e) =>
                  e is XmlElement && e.attributeName == child.attributeName) ??
              targetElements.firstWhereOrNull((e) =>
                  e is XmlElement && e.attributeName == child.attributeName);
          if (element != null) {
            outputElements.add(element.copy());
          }
        } else {
          outputElements.add(child.copy());
        }
      });

      final notImported = sourceElements.where((e) =>
          !outputElements.any((oe) => oe.attributeName == e.attributeName));
      if (notImported.isNotEmpty) {
        printVerbose('${notImported.length} keys were not imported '
            'because they are not presented in the base file');
      }
      notImported.forEach((e) => printInfo('Skip key [${e.attributeName}]'));

      await writeXML(target, outputElements);
    } else {
      throw RunException.warn('Base XML not found from ${baseFile.path}');
    }
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

  Future<Directory> _extractZip(File zipFile) async {
    printVerbose('Starting to extract archive: ${zipFile.path}');

    final archiveName = path.basenameWithoutExtension(zipFile.path);
    final tmp = Directory.systemTemp.createTempSync(
      'alex_unpack_${archiveName}_',
    );

    final unpackedDir = await _doExtract(zipFile, tmp.path);

    // unpack also all inside archive
    for (final file in unpackedDir.listSync()) {
      if (file is File && path.extension(file.path) == '.zip') {
        await _doExtract(file, file.parent.path);
        file.deleteSync();
      }
    }

    printVerbose('Extraction done');
    return unpackedDir;
  }

  Future<Directory> _doExtract(File archiveFile, String outPath) async {
    final archiveName = path.basenameWithoutExtension(archiveFile.path);
    final unpackedDir = Directory(path.join(outPath, archiveName));

    printVerbose('Extract ${archiveFile.path} to ${unpackedDir.path}');
    await extractFileToDisk(archiveFile.path, unpackedDir.path);
    return unpackedDir;
  }
}

extension _StrExt on String {
  String asDiffsName() => L10nUtils.getDiffsXmlFileName(this);
}
