import 'package:alex/alex.dart';
import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:intl_translation/src/icu_parser.dart';
import 'package:intl_translation/src/intl_message.dart';

import 'src/l10n_command_base.dart';

const _jsonDecoder = JsonCodec();
final _pluralAndGenderParser = IcuParser().message;
final _plainParser = IcuParser().nonIcuMessage;

/// Command to put localization from arb to xml.
class ToXmlCommand extends L10nCommandBase {
  ToXmlCommand() : super('to_xml', 'Put localization from arb to xml');

  @override
  Future<int> run() async {
    final config = l10nConfig;
    final l10nSubpath = config.outputDir;
    final baseLocale = config.baseLocaleForXml;

    final l10nPath = path.join(path.current, l10nSubpath);
    final l10nDir = Directory(l10nPath);

    final sourceFileName =
        L10nUtils.getArbFile(config, config.baseLocaleForXml);
    final file = File(path.join(l10nDir.path, sourceFileName));

    final exists = await file.exists();
    if (!exists) {
      return error(1,
          message: 'ABR file for locale ${baseLocale} is not found');
    }

    return _proccessArb(file, config.xmlOutputDir);
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

    final xml = StringBuffer('<?xml version="1.0" encoding="utf-8"?>');
    xml.writeln('<resources>');
    res.values.forEach((item) {
      item.add2Xml(xml);
    });
    xml.writeln('</resources>');

    final outputFileName =
        path.setExtension(path.basenameWithoutExtension(file.path), '.xml');

    final dir = Directory(outputDir);
    if (!await dir.exists()) {
      await dir.create();
    }

    final output = File(path.join(outputDir, outputFileName));
    await output.writeAsString(xml.toString());

    final relativePath = path.relative(output.path);
    return success(message: 'Success! Strings written in $relativePath');
  }
}

class _StrData {
  final String key;
  final String value;
  Map<String, Object> meta;

  _StrData(this.key, this.value);

  void add2Xml(StringBuffer xml) {
    final desc = meta['description'] as String;
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
      plural.codeAttributeNames.forEach((String quantity) {
        final val = plural[quantity];
        if (val != null) {
          final str = val.expanded((Message msg, Message chunk) {
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
