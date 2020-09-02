import 'dart:convert';
import 'dart:io';

import 'package:alex/alex.dart';
import 'package:alex/commands/l10n/src/l10n_command_base.dart';
import 'package:alex/src/exception/run_exception.dart';
import 'package:alex/src/l10n/exporters/arb_exporter.dart';
import 'package:alex/src/l10n/exporters/google_docs_exporter.dart';
import 'package:alex/src/l10n/l10n_entry.dart';
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

  static const _argLocale = 'locale';

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
          // TODO: uncomment when implement
          // _targetGoogleDocs,
        ],
        allowedHelp: {
          _targetArb: 'Import to project arb files.',
          _targetAndroid: 'Import to android localization.',
          // TODO: uncomment when implement
          // _targetGoogleDocs:
          // 'Import to google docs. It\'s for assets translations.',
        },
        defaultsTo: _targetArb,
      )
      ..addOption(
        _argLocale,
        abbr: 'l',
        help:
            'Locale for import from xml. If not specified - all locales will be imported.',
        valueHelp: 'LOCALE',
      );
    ;
  }

  @override
  Future<int> run() async {
    final config = l10nConfig;

    final target = argResults[_argTo] as String;
    final locale = argResults[_argLocale] as String;

    final locales =
        locale?.isNotEmpty ?? false ? [locale] : await _getLocales(config);

    printVerbose('Import for locales: ${locales.join(', ')}.');

    try {
      switch (target) {
        case _targetArb:
          return _importToArb(locales);
        case _targetAndroid:
          return _importToAndroid(locales);
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
    final resPath = 'android/app/src/main/res/';
    final dirName = 'values';
    final filename = 'strings.xml';

    // Here file already in required format, just copy it
    for (final locale in locales) {
      printVerbose('Export locale: $locale');
      final targetDirPath = path.join(resPath, dirName + '-$locale');

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

  Future<List<String>> _getLocales(L10nConfig config) async {
    final baseDirPath = config.xmlOutputDir;
    final baseDir = Directory(baseDirPath);
    final baseLocale = config.baseLocaleForXml;

    final locales = <String>[];
    await for (final item in baseDir.list()) {
      if (item is Directory) {
        final name = path.basename(item.path);
        // TODO: check by whitelist?
        if (name.length == 2 && name != baseLocale) locales.add(name);
      }
    }

    locales.sort();

    return locales;
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
            handle(name, L10nEntry.text(child.text));
            break;
          case 'plurals':
            final map = child.children
                .whereType<XmlElement>()
                .toMap<String, String>(
                    (dynamic el) => (el as XmlElement).getAttribute('quantity'),
                    (dynamic el) => (el as XmlElement).text);
            handle(name, L10nEntry.pluralFromMap(map));
            break;
          default:
            throw Exception('Unhandled element <$element> in xml: $child');
        }
      }
    }
  }

  Future<XmlDocument> _loadXml(
      L10nConfig config, String fileBaseName, String locale) async {
    final dirPath = config.getXmlFilesPath(locale);
    final file =
        File(path.join(dirPath, path.setExtension(fileBaseName, '.xml')));
    return XmlDocument.parse(await file.readAsString());
  }
}
