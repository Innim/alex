import 'package:alex/alex.dart';
import 'package:alex/src/exception/run_exception.dart';
import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as path;
// ignore: implementation_imports
import 'package:intl_translation/src/icu_parser.dart';
// ignore: implementation_imports
import 'package:intl_translation/src/intl_message.dart';

import 'src/l10n_command_base.dart';

const _jsonDecoder = JsonCodec();
final _pluralAndGenderParser = IcuParser().message;
final _plainParser = IcuParser().nonIcuMessage;

/// Command to put localization from arb to xml.
class ToXmlCommand extends L10nCommandBase {
  static const _argFrom = 'from';
  static const _argSource = 'source';

  static const _sourceArb = 'abr';
  static const _sourceJson = 'json';

  ToXmlCommand() : super('to_xml', 'Put localization from arb to xml') {
    argParser
      ..addOption(
        _argFrom,
        abbr: 'f',
        help: 'Source to export string for translation to xml.',
        valueHelp: 'SOURCE',
        allowed: [
          _sourceArb,
          _sourceJson,
        ],
        allowedHelp: {
          _sourceArb: 'Export from project arb files.',
          _sourceJson: 'Export from JSON (server localization). '
              'Require parameter $_argSource',
        },
        defaultsTo: _sourceArb,
      )
      ..addOption(
        _argSource,
        abbr: 's',
        help: 'Directory of source localization files. '
            'Supported by sources: $_sourceJson',
        valueHelp: 'DIR_PATH',
      );
  }

  @override
  Future<int> run() async {
    final target = argResults[_argFrom] as String;

    try {
      switch (target) {
        case _sourceArb:
          return _exportArb();
        case _sourceJson:
          return _exportJson();
        default:
          return error(1, message: 'Unknown target: $target');
      }
    } on RunException catch (e) {
      return errorBy(e);
    } catch (e) {
      return error(1, message: 'Failed by: $e');
    }
  }

  Future<int> _exportArb() async {
    final config = l10nConfig;
    final l10nSubpath = config.outputDir;
    final baseLocale = config.baseLocaleForXml;

    final l10nPath = path.join(path.current, l10nSubpath);
    final l10nDir = Directory(l10nPath);

    final locale = config.baseLocaleForXml;
    final sourceFileName = L10nUtils.getArbFile(config, locale);
    final file = File(path.join(l10nDir.path, sourceFileName));

    final exists = await file.exists();
    if (!exists) {
      return error(1, message: 'ABR file for locale $baseLocale is not found');
    }

    return _proccessArb(file, config.getXmlFilesPath(locale));
  }

  Future<int> _exportJson() async {
    final config = l10nConfig;
    final jsonBaseDirPath = argResults[_argSource] as String;

    if (jsonBaseDirPath?.isEmpty ?? true) {
      return error(1,
          message: 'Required parameter $_argSource: '
              'alex l10n to_xml --from=json --source=/path/to/json/localization/dir');
    }

    final locale = config.baseLocaleForXml;
    final jsonDir = Directory(path.join(jsonBaseDirPath, locale));
    if (!(await jsonDir.exists())) {
      throw Exception('Directory ${jsonDir.path} is not exits');
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

  Future<String> _processJson(File file, String outputDir) async {
    final name = path.basename(file.path);
    printVerbose('Export $name');

    final json = await file.readAsString();
    final map = jsonDecode(json) as Map<String, Object>;

    final data =
        map.map((key, value) => MapEntry(key, _StrData(key, value as String)));

    // TODO: add some unique prefix

    return _toXml(data, outputDir, path.withoutExtension(name));
  }

  Future<int> _proccessArb(File file, String outputDir) async {
    final src = await file.readAsString();
    final data = _jsonDecoder.decode(src) as Map<String, Object>;
    final res = <String, _StrData>{};
    data.forEach((key, value) {
      if (key.startsWith('@')) {
        final strKey = key.substring(1);
        if (res.containsKey(strKey)) {
          res[strKey].meta = value as Map<String, Object>;
        }
      } else {
        res[key] = _StrData(key, value as String);
      }
    });

    final relativePath =
        await _toXml(res, outputDir, l10nConfig.getMainXmlFileName());
    return success(message: 'Success! Strings written in $relativePath');
  }

  Future<String> _toXml(
      Map<String, _StrData> data, String outputDir, String outputName) async {
    final xml = StringBuffer('<?xml version="1.0" encoding="utf-8"?>');
    xml.writeln('<resources>');
    data.values.forEach((item) {
      item.add2Xml(xml);
    });
    xml.writeln('</resources>');

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
}

class _StrData {
  final String key;
  final String value;
  Map<String, Object> meta;

  _StrData(this.key, this.value);

  void add2Xml(StringBuffer xml) {
    final desc = meta != null ? meta['description'] as String : null;
    if (desc?.isNotEmpty ?? false) xml.writeln('<!-- $desc -->');

    var parsed = _pluralAndGenderParser.parse(value).value as Object;
    if (parsed is LiteralString && parsed.string.isEmpty) {
      parsed = _plainParser.parse(value).value;
    }

    if (parsed is LiteralString) {
      xml.writeln('<string name="$key">${parsed.string}</string>');
    } else if (parsed is Plural) {
      xml.writeln('<plurals name="$key">');
      final plural = parsed;
      plural.codeAttributeNames.forEach((quantity) {
        final val = plural[quantity];
        if (val != null) {
          final str = val.expanded((msg, chunk) {
            if (chunk is LiteralString) return chunk.string;

            if (chunk is VariableSubstitution) {
              return '{${plural.mainArgument}}';
            }

            throw Exception('Unhandled chunk type: ${chunk.runtimeType}');
          });

          xml.writeln('<item quantity="$quantity">$str</item>');
        }
      });

      xml.writeln('</plurals>');
    } else if (parsed is CompositeMessage) {
      // doesn't process message with args, just add it as is
      xml.writeln('<string name="$key">$value</string>');
    } else {
      throw UnimplementedError(
          'Process is not implemented for type ${parsed.runtimeType}. '
          'Key: $key');
    }
  }
}
