import 'dart:convert';
import 'dart:io';

import 'package:alex/alex.dart';
import 'package:alex/commands/l10n/src/l10n_command_base.dart';
import 'package:alex/src/exception/run_exception.dart';
import 'package:alex/src/exception/validation_exception.dart';
import 'package:alex/src/l10n/exporters/arb_exporter.dart';
import 'package:alex/src/l10n/exporters/google_docs_exporter.dart';
import 'package:alex/src/l10n/exporters/ios_strings_exporter.dart';
import 'package:alex/src/l10n/exporters/json_exported.dart';
import 'package:alex/src/l10n/l10n_entry.dart';
import 'package:alex/src/l10n/path_providers/l10n_ios_path_provider.dart';
import 'package:alex/src/l10n/utils/l10n_ios_utils.dart';
import 'package:alex/src/l10n/validators/l10n_validator.dart';
import 'package:alex/src/l10n/validators/require_latin_validator.dart';
import 'package:xml/xml.dart';
import 'package:path/path.dart' as path;
import 'package:list_ext/list_ext.dart';

/// Command to import translations from xml.
///
/// By default it's import from xml to project arb.
/// For additional variants - see options.
class FromXmlCommand extends L10nCommandBase {
  static const _argTo = 'to';
  static const _targetArb = 'arb';
  static const _targetGoogleDocs = 'google_docs';
  static const _targetAndroid = 'android';
  static const _targetIos = 'ios';
  static const _targetJson = 'json';

  static const _argLocale = 'locale';
  static const _argName = 'name';
  static const _argDir = 'dir';

  FromXmlCommand() : super('from_xml', 'Import translations from xml.') {
    argParser
      ..addOption(
        _argTo,
        abbr: 't',
        help: 'Target to import translations from xml.',
        valueHelp: 'TARGET',
        allowed: [
          _targetArb,
          _targetAndroid,
          _targetIos,
          _targetJson,
          // TODO: uncomment when implement
          // _targetGoogleDocs,
        ],
        allowedHelp: {
          _targetArb: 'Import to project arb files.',
          _targetAndroid: 'Import to Android localization.',
          _targetIos: 'Import to iOS localization.',
          _targetJson: 'Import to JSON localization (for backend).',
          // TODO: uncomment when implement
          // _targetGoogleDocs:
          // 'Import to google docs. It\'s for assets translations.',
        },
        defaultsTo: _targetArb,
      )
      ..addOption(
        _argDir,
        abbr: 'd',
        help: 'Directory to save localization files. '
            'Supported by targets: $_targetJson.',
        valueHelp: 'DIR_PATH',
      )
      ..addOption(
        _argLocale,
        abbr: 'l',
        help: 'Locale for import from xml. '
            'If not specified - all locales will be imported.',
        valueHelp: 'LOCALE',
      )
      ..addOption(
        _argName,
        abbr: 'n',
        help: 'File name without extension for import from xml. '
            'If not specified - all matching files will be imported. '
            'Supported by targets: $_targetJson.',
        valueHelp: 'FILENAME',
      );
  }

  @override
  Future<int> doRun() async {
    final args = argResults!;
    final runDirPath = path.current;
    final config = findConfigAndSetWorkingDir();
    final l10nConfig = config.l10n;

    final target = args[_argTo] as String;
    final locale = args[_argLocale] as String?;
    final name = (args[_argName] as String?)?.trim();

    final locales = locale != null && locale.isNotEmpty
        ? [locale]
        : await getLocales(l10nConfig);

    if (locales.isEmpty) {
      return success(
          message: 'No locales found. Check ${l10nConfig.xmlOutputDir} folder');
    }

    printVerbose('Import for locales: ${locales.join(', ')}.');
    if (name != null) printVerbose('Import file <$name>');

    final dirs = {path.current, runDirPath};

    try {
      final int res;
      switch (target) {
        case _targetArb:
          res = await _importToArb(l10nConfig, locales);
          break;
        case _targetAndroid:
          res = await _importToAndroid(l10nConfig, locales, dirs);
          break;
        case _targetIos:
          res = await _importToIos(l10nConfig, locales, dirs);
          break;
        case _targetJson:
          res = await _importToJson(l10nConfig, locales, name);
          break;
        case _targetGoogleDocs:
          // TODO: parameter for filename
          res = await _importToGoogleDocs(l10nConfig, 'screenshot1', locales);
          break;
        default:
          res = error(1, message: 'Unknown target: $target');
      }
      return res;
    } on RunException catch (e) {
      return errorBy(e, title: 'Import failed.');
    }
  }

  Future<int> _importToArb(L10nConfig config, List<String> locales) async {
    final baseArbFile = File(path.join(
        L10nUtils.getDirPath(config), L10nUtils.getArbMessagesFile(config)));
    final baseArb =
        jsonDecode(await baseArbFile.readAsString()) as Map<String, dynamic>;

    final fileName = config.getMainXmlFileName();

    const localeMap = {
      // Use Norwegian Bokmål for Norwegian
      'no': 'nb',
    };

    for (final locale in locales) {
      final arbLocale = localeMap[locale] ?? locale;
      // ignore: prefer_interpolation_to_compose_strings
      printVerbose('Import locale: $locale' +
          (arbLocale != locale ? ' -> $arbLocale' : ''));

      final arbFilePath = config.getArbFilePath(arbLocale);
      final exporter = ArbExporter(baseArb, arbFilePath, locale,
          await _loadMap(config, fileName, locale));
      try {
        if (await exporter.execute()) {
          printVerbose('Success');
        } else {
          printVerbose('No changes');
        }
      } on MissedMetaException catch (e) {
        return error(2,
            message: '${e.message} (searched in ${baseArbFile.path})');
      }
    }

    return success(
        message: 'Locales ${locales.join(', ')} imported to arb. '
            'You can "alex l10n generate" to generate dart code.');
  }

  Future<int> _importToAndroid(
      L10nConfig config, List<String> locales, Set<String> dirs) async {
    const dirName = 'values';
    const filename = 'strings.xml';
    final resPath = _findAndroidResPath(dirs);

    // http://developer.android.com/reference/java/util/Locale.html
    // Note that Java uses several deprecated two-letter codes.
    // The Hebrew ("he") language code is rewritten as "iw",
    // Indonesian ("id") as "in", and Yiddish ("yi") as "ji".
    // This rewriting happens even if you construct your own Locale object,
    // not just for instances returned by the various lookup methods.
    const localeMap = <String, String>{
      'he': 'iw',
      'id': 'in',
      'yi': 'ji',
      // Custom map: use nb for Norwegian
      'no': 'nb',
    };

    // Here file already in required format, just copy it
    for (final locale in locales) {
      printVerbose('Import locale: $locale');
      final androidLocale = (localeMap[locale] ?? locale).replaceAll('_', '-r');
      final targetDirPath = path.join(resPath, '$dirName-$androidLocale');

      final targetDir = Directory(targetDirPath);
      if (!(await targetDir.exists())) await targetDir.create(recursive: true);

      final xmlPath = path.join(config.getXmlFilesPath(locale), filename);

      // TODO: check source xml with validators, as _loadAndParseXml do

      final targetPath = path.join(targetDirPath, filename);

      printVerbose('Copy $xmlPath to $targetPath');

      final file = File(xmlPath);
      await file.copy(targetPath);

      printVerbose('Success');
    }

    return success(
        message: 'Locales ${locales.join(', ')} copied to android resources.');
  }

  Future<int> _importToIos(
      L10nConfig config, List<String> locales, Set<String> dirs) async {
    final provider = L10nIosPathProvider.from(dirs);

    final baseLocale = config.baseLocaleForXml;
    final filesByProject = <String, Set<String>>{};
    final keysMapByXmlBasename = <String, _IosL10nFileInfo>{};

    await provider.forEachLocalizationFile(
      baseLocale,
      (projectName, file) async {
        final name = path.basenameWithoutExtension(file.path);
        final xmlBasename =
            provider.getXmlFileName(name, withoutExtension: true);

        final xmlFile = _getXmlFile(config, xmlBasename, baseLocale);
        if (await xmlFile.exists()) {
          final files =
              filesByProject[projectName] ?? (filesByProject[projectName] = {});
          files.add(xmlBasename);

          final data = await L10nIosUtils.loadAndDecodeStringsFile(file);
          keysMapByXmlBasename[xmlBasename] = _IosL10nFileInfo(
            file,
            data.map(
              (key, value) => MapEntry(
                L10nIosUtils.covertStringsKeyToXml(key),
                key,
              ),
            ),
          );
        }
      },
    );

    printVerbose(
      // ignore: prefer_interpolation_to_compose_strings
      'Found ${filesByProject.length} projects. Files by projects: ' +
          filesByProject.keys
              .where((k) => filesByProject[k]!.isNotEmpty)
              .map((k) => '$k: ${filesByProject[k]!.join(', ')}')
              .join('; '),
    );

    for (final locale in locales) {
      printVerbose('Import locale: $locale');

      var updated = 0;
      for (final projectName in filesByProject.keys) {
        for (final fileName in filesByProject[projectName]!) {
          final xmlData = await _loadMap(config, fileName, locale);
          final info = keysMapByXmlBasename[fileName]!;
          final keysMap = info.xml2IosKeys;

          MapEntry<String, L10nEntry> mapKeys(String key, L10nEntry value) {
            final iosKey = keysMap[key];
            if (iosKey == null) {
              final baseFilePath = info.baseIosFile.path;
              final msg = '''
Found unexpected key <$key>. File: $fileName, locale: $locale.
The search for a matching key was performed in the file for base locale ($baseLocale): $baseFilePath.

💡 Suggestions: 
   - Make sure the .strings file for the *base* locale ($baseLocale) has all the necessary keys. Add any missing ones.
   - Remove not relevant keys from the processed .xml file (locale: $locale) if key was removed from localization.
   - Check name of the keys in the base .strings and processed .xml files 
     (note that keys do not always have to be exactly the same in .strings and .xml files, but a key in a .xml file should be able to be generated from a key in .strings by replacing forbidden symbols).
''';

              throw RunException.err(msg);
            }

            return MapEntry(iosKey, value);
          }

          final exporter = IosStringsExporter(
            provider,
            projectName,
            fileName,
            locale,
            xmlData.map(mapKeys),
          );
          if (await exporter.execute()) updated++;
        }
      }

      if (updated > 0) {
        printVerbose('Success ($updated updated)');
      } else {
        printVerbose('No changes');
      }
    }

    return success(
      message: 'Locales ${locales.join(', ')} imported to iOS strings.',
    );
  }

  Future<int> _importToJson(
      L10nConfig config, List<String> locales, String? name) async {
    final args = argResults!;
    final jsonDirPath = args[_argDir] as String?;

    if (jsonDirPath == null || jsonDirPath.isEmpty) {
      return error(1,
          message: 'Required parameter $_argDir: '
              'alex l10n from_xml --to=json --dir=/path/to/json/localization/dir');
    }

    const ext = '.json';

    const localeMap = {
      // Use Norwegian Bokmål for Norwegian
      'no': 'nb',
    };

    String jsonLocale(String locale) =>
        localeMap[locale] ?? locale.replaceAll('_', '-');
    String getPath(String locale, [String? fileBasename]) => path.join(
        jsonDirPath,
        jsonLocale(locale),
        fileBasename != null ? path.setExtension(fileBasename, ext) : null);

    // Get list of files to import from base locale dir
    final baseLocale = config.baseLocaleForXml;
    final baseLocaleDir = getPath(baseLocale);
    final names = <String>{};
    await for (final file in Directory(baseLocaleDir).list()) {
      final basename = path.basename(file.path);
      if (basename.endsWith(ext)) {
        names.add(path.withoutExtension(basename));
      }
    }

    // TODO: если явно указано имя, то спрашивать подтверждение надо ли экспортировать, даже если нет

    if (names.isEmpty || name != null && !names.contains(name)) {
      return error(1,
          // ignore: prefer_interpolation_to_compose_strings
          message: "Can't find any matching files for import. " +
              (names.isNotEmpty
                  ? '\nFound following candidates: ${names.join(', ')}.'
                      '\nLooking for: $name'
                  : 'No candidates in base locale directory.'));
    }

    if (name != null) names.removeWhere((n) => n != name);

    printVerbose('Files to import: ${names.join(', ')}');

    final exportedLocales = <String>[];
    for (final locale in locales) {
      printVerbose('Import locale: $locale');

      var updated = 0;
      for (final name in names) {
        final targetPath = getPath(locale, name);
        final exporter = JsonExporter(
            targetPath, locale, await _loadMap(config, name, locale));

        if (await exporter.execute()) updated++;
      }

      if (updated > 0) {
        printVerbose('Success ($updated updated)');
        exportedLocales.add(locale);
      } else {
        printVerbose('No changes');
      }
    }

    return success(
      message: exportedLocales.isEmpty
          ? 'No JSON files updated'
          : 'Updated JSON for ${exportedLocales.length} locales: ${exportedLocales.join(', ')}.',
    );
  }

  Future<int> _importToGoogleDocs(
      L10nConfig config, String fileBaseName, List<String> locales) async {
    final baseLocale = config.baseLocaleForXml;
    final keys = await _loadKeys(config, fileBaseName, baseLocale);

    for (final locale in locales) {
      final exporter = GoogleDocsExporter(
          locale, await _loadMap(config, fileBaseName, locale), keys);
      await exporter.execute();
    }

    return success();
  }

  String _findAndroidResPath(Set<String> dirs) {
    const resRelativePath = 'android/app/src/main/res/';

    for (final dirPath in dirs) {
      final resPath = path.join(dirPath, resRelativePath);
      if (Directory(resPath).existsSync()) return resPath;
      printVerbose("Skip $dirPath: doesn't contain android project folder");
    }

    throw Exception("Can't find valid directory for android among provided");
  }

  Future<List<String>> _loadKeys(
      L10nConfig config, String fileBaseName, String locale) async {
    final list = <String>[];
    await _loadAndParseXml(config, fileBaseName, locale, (name, value) {
      list.add(name);
    });

    return list;
  }

  Future<Map<String, L10nEntry>> _loadMap(
      L10nConfig config, String fileBaseName, String locale) async {
    final map = <String, L10nEntry>{};
    await _loadAndParseXml(config, fileBaseName, locale, (name, value) {
      map[name] = value;
    });
    return map;
  }

  Future<void> _loadAndParseXml(
    L10nConfig config,
    String fileBaseName,
    String locale,
    void Function(String name, L10nEntry value) handle,
  ) async {
    final xml = await _loadXml(config, fileBaseName, locale);
    final resources = xml.findAllElements('resources').first;

    final validators = <L10nValidator>[
      if (config.requireLatin.contains(locale)) RequireLatinValidator(),
    ];

    String processText(String value) => _textFromXml(value, validators);

    final errors = <String>[];
    final keys = <String>{};
    final duplicateKeys = <String>{};
    for (final child in resources.children) {
      if (child is XmlElement) {
        final name = child.getAttribute('name')!;
        final element = child.name.toString();

        if (!keys.add(name)) {
          duplicateKeys.add(name);
          continue;
        }

        try {
          switch (element) {
            case 'string':
              handle(name, L10nEntry.text(processText(child.text)));
              break;
            case 'plurals':
              final map =
                  child.children.whereType<XmlElement>().toMap<String, String>(
                        (el) => el.getAttribute('quantity')!,
                        (el) => processText(el.text),
                      );
              handle(name, L10nEntry.pluralFromMap(map));
              break;
            default:
              throw Exception('Unhandled element <$element> in xml: $child');
          }
        } on ValidationException catch (e) {
          errors.add('[$name] ${e.message}');
        }
      }
    }

    if (duplicateKeys.isNotEmpty) {
      throw RunException.err(
          'Found duplicate keys in xml for locale <$locale>: ${duplicateKeys.join(', ')}.');
    } else if (errors.isNotEmpty) {
      final sb = StringBuffer('XML file for locale <$locale> contains errors:')
        ..writeln()
        ..writeln();
      errors.forEach(sb.writeln);
      sb
        ..writeln()
        ..writeln('Found ${errors.length} invalid strings.')
        ..writeln()
        ..writeln('💡 Suggestion:')
        ..writeln(
            'Probably translations file contains some Cyrillic characters '
            'or unusual kind of punctuation marks. '
            'Another options: instead of a single character, combining characters '
            '(combining diacritical marks) are used.')
        ..writeln('You should fix the strings in xml and try again '
            '(in case of combining characters you should replace them '
            'with a single character).')
        ..write('If you think this is a false positive, '
            'please contact developer.');

      throw RunException.warn(sb.toString());
    }
  }

  String _textFromXml(String val, List<L10nValidator> validators) {
    final errors =
        validators.where((e) => !e.validate(val)).map((e) => e.getError(val));
    if (errors.isNotEmpty) {
      throw ValidationException(
        'Validation failed:\n\t- ${errors.join('\n\t - ')}',
      );
    }

    // Translates add escape slashes for ' and " in xml
    return val.replaceAll(r"\'", "'").replaceAll(r'\"', '"');
  }

  Future<XmlDocument> _loadXml(
      L10nConfig config, String fileBaseName, String locale) async {
    final file = _getXmlFile(config, fileBaseName, locale);
    try {
      return XmlDocument.parse(await file.readAsString());
    } catch (e, st) {
      printVerbose('Exception during load xml from ${file.path}: $e\n$st');
      throw RunException.err(
          'Failed load XML for <$locale> [${file.path}]: $e');
    }
  }

  File _getXmlFile(L10nConfig config, String fileBaseName, String locale) {
    final dirPath = config.getXmlFilesPath(locale);
    return File(path.join(dirPath, path.setExtension(fileBaseName, '.xml')));
  }
}

class _IosL10nFileInfo {
  final File baseIosFile;
  final Map<String, String> xml2IosKeys;

  _IosL10nFileInfo(this.baseIosFile, this.xml2IosKeys);
}
