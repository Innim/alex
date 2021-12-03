import 'dart:convert';
import 'dart:io';

import 'package:alex/alex.dart';
import 'package:alex/commands/l10n/src/l10n_command_base.dart';
import 'package:alex/src/exception/run_exception.dart';
import 'package:alex/src/l10n/exporters/arb_exporter.dart';
import 'package:alex/src/l10n/exporters/google_docs_exporter.dart';
import 'package:alex/src/l10n/exporters/ios_strings_exporter.dart';
import 'package:alex/src/l10n/exporters/json_exported.dart';
import 'package:alex/src/l10n/l10n_entry.dart';
import 'package:alex/src/l10n/path_providers/l10n_ios_path_provider.dart';
import 'package:alex/src/l10n/utils/l10n_ios_utils.dart';
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
  Future<int> run() async {
    final args = argResults!;
    final config = l10nConfig;

    final target = args[_argTo] as String;
    final locale = args[_argLocale] as String?;
    final name = (args[_argName] as String?)?.trim();

    final locales = locale != null && locale.isNotEmpty
        ? [locale]
        : await getLocales(config);

    if (locales.isEmpty) {
      return success(
          message: 'No locales found. Check ${config.xmlOutputDir} folder');
    }

    printVerbose('Import for locales: ${locales.join(', ')}.');
    if (name != null) printVerbose('Import file <$name>');

    try {
      int res;
      switch (target) {
        case _targetArb:
          res = await _importToArb(locales);
          break;
        case _targetAndroid:
          res = await _importToAndroid(locales);
          break;
        case _targetIos:
          res = await _importToIos(locales);
          break;
        case _targetJson:
          res = await _importToJson(locales, name);
          break;
        case _targetGoogleDocs:
          // TODO: parameter for filename
          res = await _importToGoogleDocs('screenshot1', locales);
          break;
        default:
          res = error(1, message: 'Unknown target: $target');
      }
      return res;
    } on RunException catch (e) {
      return errorBy(e);
    } catch (e) {
      return error(2, message: 'Failed by: $e');
    }
  }

  Future<int> _importToArb(List<String> locales) async {
    final config = l10nConfig;

    final baseArbFile = File(path.join(
        L10nUtils.getDirPath(config), L10nUtils.getArbMessagesFile(config)));
    final baseArb =
        jsonDecode(await baseArbFile.readAsString()) as Map<String, Object>;

    final fileName = config.getMainXmlFileName();

    const localeMap = {
      // Use Norwegian Bokmål for Norwegian
      'no': 'nb',
    };

    for (final locale in locales) {
      final arbLocale = localeMap[locale] ?? locale;
      // ignore: prefer_interpolation_to_compose_strings
      printVerbose('Export locale: $locale' +
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
        message: 'Locales ${locales.join(', ')} exported to arb. '
            'You can "alex l10n generate" to generate dart code.');
  }

  Future<int> _importToAndroid(List<String> locales) async {
    final config = l10nConfig;
    const resPath = 'android/app/src/main/res/';
    const dirName = 'values';
    const filename = 'strings.xml';

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
      printVerbose('Export locale: $locale');
      final androidLocale = (localeMap[locale] ?? locale).replaceAll('_', '-r');
      final targetDirPath = path.join(resPath, '$dirName-$androidLocale');

      final targetDir = Directory(targetDirPath);
      if (!(await targetDir.exists())) await targetDir.create(recursive: true);

      final xmlPath = path.join(config.getXmlFilesPath(locale), filename);
      final targetPath = path.join(targetDirPath, filename);

      printVerbose('Copy $xmlPath to $targetPath');

      final file = File(xmlPath);
      await file.copy(targetPath);

      printVerbose('Success');
    }

    return success(
        message: 'Locales ${locales.join(', ')} copied to android resources.');
  }

  Future<int> _importToIos(List<String> locales) async {
    final config = l10nConfig;
    final provider = L10nIosPathProvider(path.current);

    final baseLocale = l10nConfig.baseLocaleForXml;
    final filesByProject = <String, Set<String>>{};
    final keysMapByXmlBasename = <String, Map<String, String>>{};

    await provider.forEachLocalizationFile(
      baseLocale,
      (projectName, file) async {
        final name = path.basenameWithoutExtension(file.path);
        final xmlBasename =
            provider.getXmlFileName(name, withoutExtension: true);

        final xmlFile = _getXmlFile(l10nConfig, xmlBasename, baseLocale);
        if (await xmlFile.exists()) {
          final files =
              filesByProject[projectName] ?? (filesByProject[projectName] = {});
          files.add(xmlBasename);

          final data = await L10nIosUtils.loadAndDecodeStringsFile(file);
          keysMapByXmlBasename[xmlBasename] = data.map((key, value) =>
              MapEntry(L10nIosUtils.covertStringsKeyToXml(key), key));
        }
      },
    );

    printVerbose(filesByProject.keys
        .where((k) => filesByProject[k]!.isNotEmpty)
        .map((k) => '$k: ${filesByProject[k]!.join(', ')}')
        .join('; '));

    for (final locale in locales) {
      printVerbose('Export locale: $locale');

      var updated = 0;
      for (final projectName in filesByProject.keys) {
        for (final fileName in filesByProject[projectName]!) {
          final xmlData = await _loadMap(config, fileName, locale);
          final keysMap = keysMapByXmlBasename[fileName]!;

          MapEntry<String, L10nEntry> mapKeys(String key, L10nEntry value) {
            final iosKey = keysMap[key];
            if (iosKey == null) {
              throw Exception(
                  "Can't find record for key <$key>. File: $fileName, locale: $locale");
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
        message: 'Locales ${locales.join(', ')} exported to iOS strings.');
  }

  Future<int> _importToJson(List<String> locales, String? name) async {
    final args = argResults!;
    final config = l10nConfig;
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

    if (names.isEmpty || name != null && !names.contains(name)) {
      return error(1,
          // ignore: prefer_interpolation_to_compose_strings
          message: "Can't find any matching files for export. " +
              (names.isNotEmpty
                  ? '\nFound following candidates: ${names.join(', ')}.'
                      '\nLooking for: $name'
                  : 'No candidates in base locale directory.'));
    }

    if (name != null) names.removeWhere((n) => n != name);

    printVerbose('Files to export: ${names.join(', ')}');

    for (final locale in locales) {
      printVerbose('Export locale: $locale');

      var updated = 0;
      for (final name in names) {
        final targetPath = getPath(locale, name);
        final exporter = JsonExporter(
            targetPath, locale, await _loadMap(config, name, locale));

        if (await exporter.execute()) updated++;
      }

      if (updated > 0) {
        printVerbose('Success ($updated updated)');
      } else {
        printVerbose('No changes');
      }
    }

    return success();
  }

  Future<int> _importToGoogleDocs(
      String fileBaseName, List<String> locales) async {
    final config = l10nConfig;
    final baseLocale = config.baseLocaleForXml;
    final keys = await _loadKeys(config, fileBaseName, baseLocale);

    for (final locale in locales) {
      final exporter = GoogleDocsExporter(
          locale, await _loadMap(config, fileBaseName, locale), keys);
      await exporter.execute();
    }

    return success();
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

  Future<void> _loadAndParseXml(L10nConfig config, String fileBaseName,
      String locale, void Function(String name, L10nEntry value) handle) async {
    final xml = await _loadXml(config, fileBaseName, locale);
    final resources = xml.findAllElements('resources').first;
    for (final child in resources.children) {
      if (child is XmlElement) {
        final name = child.getAttribute('name')!;
        final element = child.name.toString();

        switch (element) {
          case 'string':
            handle(name, L10nEntry.text(_textFromXml(child.text)));
            break;
          case 'plurals':
            final map =
                child.children.whereType<XmlElement>().toMap<String, String>(
                      (el) => el.getAttribute('quantity')!,
                      (el) => _textFromXml(el.text),
                    );
            handle(name, L10nEntry.pluralFromMap(map));
            break;
          default:
            throw Exception('Unhandled element <$element> in xml: $child');
        }
      }
    }
  }

  String _textFromXml(String val) {
    // Translates add escape slashes for ' and " in xml
    return val.replaceAll(r"\'", "'").replaceAll(r'\"', '"');
  }

  Future<XmlDocument> _loadXml(
      L10nConfig config, String fileBaseName, String locale) async {
    final file = _getXmlFile(config, fileBaseName, locale);
    return XmlDocument.parse(await file.readAsString());
  }

  File _getXmlFile(L10nConfig config, String fileBaseName, String locale) {
    final dirPath = config.getXmlFilesPath(locale);
    return File(path.join(dirPath, path.setExtension(fileBaseName, '.xml')));
  }
}
