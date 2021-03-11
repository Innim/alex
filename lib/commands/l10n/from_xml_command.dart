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
      );
  }

  @override
  Future<int> run() async {
    final config = l10nConfig;

    final target = argResults[_argTo] as String;
    final locale = argResults[_argLocale] as String;

    final locales =
        locale?.isNotEmpty ?? false ? [locale] : await getLocales(config);

    if (locales.isEmpty) {
      return success(
          message: 'No locales found. Check ${config.xmlOutputDir} folder');
    }

    printVerbose('Import for locales: ${locales.join(', ')}.');

    try {
      switch (target) {
        case _targetArb:
          return _importToArb(locales);
        case _targetAndroid:
          return _importToAndroid(locales);
        case _targetIos:
          return _importToIos(locales);
        case _targetJson:
          return _importToJson(locales);
        case _targetGoogleDocs:
          // TODO: parameter for filename
          return _importToGoogleDocs('screenshot1', locales);
        default:
          return error(1, message: 'Unknown target: $target');
      }
    } on RunException catch (e) {
      return errorBy(e);
    } catch (e) {
      return error(1, message: 'Failed by: $e');
    }
  }

  Future<int> _importToArb(List<String> locales) async {
    final config = l10nConfig;

    final baseArbFile = File(path.join(
        L10nUtils.getDirPath(config), L10nUtils.getArbMessagesFile(config)));
    final baseArb =
        jsonDecode(await baseArbFile.readAsString()) as Map<String, Object>;

    final fileName = config.getMainXmlFileName();

    for (final locale in locales) {
      printVerbose('Export locale: $locale');
      final arbFilePath = config.getArbFilePath(locale);
      final exporter = ArbExporter(baseArb, arbFilePath, locale,
          await _loadMap(config, fileName, locale));
      await exporter.execute();
      printVerbose('Success');
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

    final iosProjectDir = provider.iosProjectDir;
    final baseLocale = l10nConfig.baseLocaleForXml;
    final baseIosLocale = provider.getIosLocale(baseLocale);

    final filesByProject = <String, Set<String>>{};

    await for (final item in iosProjectDir.list()) {
      if (item is Directory) {
        final tmpName = path.basename(item.path);
        final tmpDir = provider.getLocalizationDir(tmpName, baseIosLocale);
        if (await tmpDir.exists()) {
          final files = <String>{};

          await for (final file in tmpDir.list()) {
            if (file.path.endsWith('.strings')) {
              final name = path.basenameWithoutExtension(file.path);
              final xmlBasename =
                  provider.getXmlFileName(name, withouExtension: true);

              final xmlFile = _getXmlFile(l10nConfig, xmlBasename, baseLocale);
              if (await xmlFile.exists()) {
                files.add(xmlBasename);
              }
            }
          }

          filesByProject[tmpName] = files;
        }
      }
    }

    printVerbose(filesByProject.keys
        .where((k) => filesByProject[k].isNotEmpty)
        .map((k) => '$k: ${filesByProject[k].join(', ')}')
        .join('; '));

    for (final locale in locales) {
      printVerbose('Export locale: $locale');

      for (final projectName in filesByProject.keys) {
        for (final fileName in filesByProject[projectName]) {
          final exporter = IosStringsExporter(provider, projectName, fileName,
              locale, await _loadMap(config, fileName, locale));
          await exporter.execute();
        }
      }
      printVerbose('Success');
    }

    return success(
        message: 'Locales ${locales.join(', ')} exported to iOS strings.');
  }

  Future<int> _importToJson(List<String> locales) async {
    final config = l10nConfig;
    final jsonDirPath = argResults[_argDir] as String;

    if (jsonDirPath?.isEmpty ?? true) {
      return error(1,
          message: 'Required parameter $_argDir: '
              'alex l10n from_xml --to=json --dir=/path/to/json/localization/dir');
    }

    const ext = '.json';

    String jsonLocale(String locale) => locale.replaceAll('_', '-');
    String getPath(String locale, [String fileBasename]) => path.join(
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

    printVerbose('Files to export: ${names.join(', ')}');

    for (final locale in locales) {
      printVerbose('Export locale: $locale');
      for (final name in names) {
        final targetPath = getPath(locale, name);
        final exporter = JsonExporter(
            targetPath, locale, await _loadMap(config, name, locale));
        await exporter.execute();
      }
      printVerbose('Success');
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
        final name = child.getAttribute('name');
        final element = child.name.toString();

        switch (element) {
          case 'string':
            handle(name, L10nEntry.text(_textFromXml(child.text)));
            break;
          case 'plurals':
            final map = child.children
                .whereType<XmlElement>()
                .toMap<String, String>(
                    (dynamic el) => (el as XmlElement).getAttribute('quantity'),
                    (dynamic el) => _textFromXml((el as XmlElement).text));
            handle(name, L10nEntry.pluralFromMap(map));
            break;
          default:
            throw Exception('Unhandled element <$element> in xml: $child');
        }
      }
    }
  }

  String _textFromXml(String val) {
    // Translates add escape slashes for ' in xml
    return val.replaceAll(r"\'", "'");
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
