import 'package:alex/alex.dart';
import 'package:alex/src/exception/run_exception.dart';
import 'package:alex/src/l10n/decoders/arb_decoder.dart';
import 'package:alex/src/l10n/decoders/ios_strings_decoder.dart';
import 'package:alex/src/l10n/l10n_entry.dart';
import 'package:alex/src/l10n/locale/locales.dart';
import 'package:alex/src/l10n/path_providers/l10n_ios_path_provider.dart';
import 'package:alex/src/l10n/utils/l10n_ios_utils.dart';
import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:xml/xml.dart';

import 'src/l10n_command_base.dart';

const _jsonDecoder = JsonCodec();
const _iosStringsDecoder = IosStringsDecoder();
const _kXmlIndent = '  ';

/// Command to put localization to xml.
class ToXmlCommand extends L10nCommandBase {
  static const _argFrom = 'from';
  static const _argSource = 'source';
  static const _argLocale = 'locale';
  static const _argDiffPath = 'diff-path';

  static const _sourceArb = 'abr';
  static const _sourceJson = 'json';
  static const _sourceIos = 'ios';

  ToXmlCommand() : super('to_xml', 'Put localization from source to xml') {
    argParser
      ..addOption(
        _argFrom,
        abbr: 'f',
        help: 'Source to export string for translation to xml.',
        valueHelp: 'SOURCE',
        allowed: [
          _sourceArb,
          _sourceJson,
          _sourceIos,
        ],
        allowedHelp: {
          _sourceArb: 'Export from project arb files.',
          _sourceJson: 'Export from JSON (server localization). '
              'Require parameter $_argSource',
          _sourceIos: 'Export from .strings iOS localization files. '
              'All not empty files for all projects will be exported.',
        },
        defaultsTo: _sourceArb,
      )
      ..addOption(
        _argSource,
        abbr: 's',
        help: 'Directory of source localization files. '
            'Supported by sources: $_sourceJson',
        valueHelp: 'DIR_PATH',
      )
      ..addOption(
        _argLocale,
        abbr: 'l',
        help: 'Locale to export. By default this is '
            'base_locale_for_xml from alex configuration.',
        valueHelp: 'LOCALE',
      )
      ..addOption(
        _argDiffPath,
        abbr: 'd',
        help: 'Path to file with list of changes',
        valueHelp: 'DIR_PATH',
      );
  }

  @override
  Future<int> doRun() async {
    final args = argResults!;
    final runDirPath = path.current;
    final config = findConfigAndSetWorkingDir();
    final l10nConfig = config.l10n;

    final target = args[_argFrom] as String;
    final baseLocale =
        args.getLocale(_argLocale) ?? l10nConfig.baseLocaleForXml;

    switch (target) {
      case _sourceArb:
        return _exportArb(l10nConfig, baseLocale);
      case _sourceJson:
        return _exportJson(l10nConfig, baseLocale);
      case _sourceIos:
        return _exportIos(l10nConfig, baseLocale, {path.current, runDirPath});
      default:
        return error(1, message: 'Unknown target: $target');
    }
  }

  Future<int> _exportArb(L10nConfig config, XmlLocale locale) async {
    final l10nSubpath = config.outputDir;

    final l10nPath = path.join(path.current, l10nSubpath);
    final l10nDir = Directory(l10nPath);

    final sourceFileName = L10nUtils.getArbFile(config, locale.toArbLocale());
    final file = File(path.join(l10nDir.path, sourceFileName));

    final exists = await file.exists();
    if (!exists) {
      return error(2, message: 'ABR file for locale $locale is not found');
    }

    return _processArb(
        file, config.getXmlFilesPath(locale), config.getMainXmlFileName());
  }

  Future<int> _exportJson(L10nConfig config, XmlLocale locale) async {
    final args = argResults!;
    final jsonBaseDirPath = args[_argSource] as String?;

    if (jsonBaseDirPath == null || jsonBaseDirPath.isEmpty) {
      return error(1,
          message: 'Required parameter $_argSource: '
              'alex l10n to_xml --from=json --source=/path/to/json/localization/dir');
    }

    final jsonLocale = locale.toJsonLocale();
    final checkedPaths = <String>[];

    final curPath = path.join(jsonBaseDirPath, jsonLocale.value);
    checkedPaths.add(curPath);

    final jsonDir = Directory(curPath);

    if (!jsonDir.existsSync()) {
      throw Exception('Directory for locale $locale is not exits. '
          'Searched:\n${checkedPaths.join('\n')}');
    }

    final outputDirPath = config.getXmlFilesPath(locale);

    final resPaths = <String>[];
    await for (final item in jsonDir.list()) {
      if (item is File && path.extension(item.path) == '.json') {
        resPaths.add(await _processJson(item, outputDirPath));
      }
    }

    if (resPaths.isEmpty) {
      return success(message: 'No JSON files found.');
    } else {
      return success(
          message: 'Success! ${resPaths.length} JSON files exported. '
              'Strings written in:\n${resPaths.join("\n")}');
    }
  }

  Future<int> _exportIos(
      L10nConfig config, XmlLocale locale, Set<String> dirs) async {
    final provider = L10nIosPathProvider.from(dirs);

    final outputDirPath = config.getXmlFilesPath(locale);

    final resPaths = <String>[];

    await provider.forEachLocalizationFile(locale, (projectName, file) async {
      final data = await L10nIosUtils.loadStringsFile(file);
      if (data.trim().isNotEmpty) {
        final baseName = path.basename(file.path);
        final outputName =
            provider.getXmlFileName(baseName, withoutExtension: true);

        resPaths.add(await _processStrings(data, outputDirPath, outputName, '''
Project path: ios/$projectName
Filename: $baseName
'''));
      }
    });

    if (resPaths.isEmpty) {
      return success(message: 'No .strings iOS localization files found.');
    } else {
      return success(
          message: 'Success! '
              '${resPaths.length} .strings iOS localization files exported. '
              'Strings written in:\n${resPaths.join("\n")}');
    }
  }

  Future<String> _processJson(File file, String outputDir) async {
    final name = path.basename(file.path);
    printVerbose('Export $name');

    final json = await file.readAsString();
    final map = jsonDecode(json) as Map<String, dynamic>;

    final data = map.map(
        (key, dynamic value) => MapEntry(key, _StrData(key, value as String)));

    // TODO: add some unique prefix

    return _toXml(data, outputDir, path.withoutExtension(name));
  }

  Future<String> _processStrings(String content, String outputDir,
      String outputName, String headerComment) {
    printVerbose('Export $outputName');

    final data = _iosStringsDecoder.decode(content);

    final res = data.map((key, value) {
      final xmlKey = L10nIosUtils.covertStringsKeyToXml(key);
      return MapEntry(xmlKey, _StrData(xmlKey, value));
    });

    return _toXml(res, outputDir, outputName, header: headerComment);
  }

  Future<int> _processArb(
      File file, String outputDir, String outputName) async {
    final src = await file.readAsString();
    final data = _jsonDecoder.decode(src) as Map<String, dynamic>;
    final res = <String, _StrData>{};
    data.forEach((key, dynamic value) {
      if (key.startsWith('@')) {
        final strKey = key.substring(1);
        if (res.containsKey(strKey)) {
          res[strKey]!.meta = value as Map<String, dynamic>;
        }
      } else {
        res[key] = _StrData(key, value as String);
      }
    });

    final relativePath = await _toXml(res, outputDir, outputName);
    return success(message: 'Success! Strings written in $relativePath');
  }

  Future<String> _toXml(
      Map<String, _StrData> data, String outputDir, String outputName,
      {String? header}) async {
    final xml = StringBuffer();

    var level = 0;

    xml.writeln('<?xml version="1.0" encoding="utf-8"?>');
    if (header != null) {
      header.split('\n').forEach((l) {
        if (l.isNotEmpty) {
          xml.write('<!-- ');
          xml.write(l);
          xml.writeln(' -->');
        }
      });
    }
    xml.writeln('<resources>');
    level++;
    data.values.forEach((item) {
      item.add2Xml(xml, level);
    });
    xml.writeln('</resources>');

    final diffPath = argResults?[_argDiffPath] as String?;
    if (diffPath != null) {
      _addChangedPartsXml(xml.toString(), outputDir, outputName, diffPath);
    }

    final outputFileName = path.setExtension(outputName, '.xml');
    final dir = Directory(outputDir);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }

    final output = File(path.join(outputDir, outputFileName));
    await output.writeAsString(xml.toString());

    final relativePath = path.relative(output.path);
    return relativePath;
  }

  void _addChangedPartsXml(
      String xml, String dirName, String fileName, String diffPath) {
    final XmlDocument xmlDoc;
    try {
      xmlDoc = XmlDocument.parse(xml.toString());
    } catch (e, st) {
      printVerbose('Exception during parse xml: $e\n$st');
      throw RunException.err('Failed parse XML: $e');
    }

    final oldFile =
        File(path.join(dirName, path.setExtension(fileName, '.xml')));

    StringBuffer? partsBuffer;

    final bool hasNewStrings;

    if (oldFile.existsSync()) {
      final oldXml = getXML(oldFile);
      final oldRes = oldXml.resources.children;
      final partsElements = <XmlElement>{};
      xmlDoc.forEachResource((child) {
        if (child is XmlElement) {
          if (!oldRes.any((e) => e is XmlElement && e.isEquals(child))) {
            partsElements.add(child.copy());
          }
        }
      });

      hasNewStrings = partsElements.isNotEmpty;
      if (hasNewStrings) {
        printInfo('Found ${partsElements.length} strings for diff');
        final partsXmlDoc = XmlDocument([
          XmlElement(XmlName.fromString('resources')),
        ]);
        partsXmlDoc.resources.children.addAll(partsElements);

        partsBuffer = StringBuffer();
        partsBuffer.writeln('<?xml version="1.0" encoding="utf-8"?>');
        partsBuffer.write(partsXmlDoc.toXmlString(
            pretty: true,
            preserveWhitespace: (node) => node.getAttribute('name') != null));
      } else {
        printInfo('No new or changed strings.');
      }
    } else {
      printInfo('${oldFile.path} not found. All strings was added as new.');
      hasNewStrings = true;
    }

    if (hasNewStrings) {
      final partsFileName = L10nUtils.getDiffsXmlFileName(fileName);
      final dir = Directory(diffPath);
      if (!dir.existsSync()) dir.createSync(recursive: true);
      final output = File(path.join(dir.path, partsFileName));
      output.writeAsStringSync(partsBuffer?.toString() ?? xml);
      printInfo('Diff was written in ${output.path}');
    }
  }
}

class _StrData {
  final String key;
  final String value;
  Map<String, dynamic>? meta;

  _StrData(this.key, this.value);

  void add2Xml(StringBuffer xml, int startLevel) {
    final level = startLevel;

    final desc = meta != null ? meta!['description'] as String? : null;
    if (desc?.isNotEmpty ?? false) xml.writeElement('<!-- $desc -->', level);

    final parsed = arbDecoder.decodeValue(key, value);
    if (parsed is L10nTextEntry) {
      xml.writeElement(
          '<string name="$key">${_prepareStr(parsed.text)}</string>', level);
    } else if (parsed is L10nPluralEntry) {
      xml.writeElement('<plurals name="$key">', level);
      final plural = parsed;
      final sublevel = level + 1;
      plural.codeAttributeNames.forEach((quantity) {
        final val = plural[quantity];
        if (val != null) {
          xml.writeElement(
            '<item quantity="$quantity">${_prepareStr(val)}</item>',
            sublevel,
          );
        }
      });

      xml.writeElement('</plurals>', level);
    } else {
      throw UnimplementedError(
          'Process is not implemented for type ${parsed.runtimeType}. '
          'Key: $key');
    }
  }

  String _prepareStr(String value) => value.replaceAll('\n', r'\n');
}

String _indent(int level) {
  return _kXmlIndent * level;
}

extension _XmlWriterStringBufferExt on StringBuffer {
  /// Writes an XML element with indentation.
  StringBuffer writeElement(String str, int level) {
    final indent = _indent(level);
    return this
      ..write(indent)
      ..write(str)
      ..writeln();
  }
}
