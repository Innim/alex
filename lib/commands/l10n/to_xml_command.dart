import 'package:alex/runner/alex_command.dart';
import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:intl_translation/src/icu_parser.dart';
import 'package:intl_translation/src/intl_message.dart';

const _jsonDecoder = JsonCodec();
final _pluralAndGenderParser = IcuParser().message;
final _plainParser = IcuParser().nonIcuMessage;

/// Команда релизной сборки.
class ToXmlCommand extends AlexCommand {
  ToXmlCommand() : super('to_xml', 'Put localization from arb to xml');

  @override
  Future<int> run() async {
    // TODO: get from args or config
    final projectPath = '/Users/GreyMag/projects/flutter/Notes/';
    final l10nSubpath = 'lib/application/l10n';
    final baseLocale = 'en';

    final l10nPath = path.join(projectPath, l10nSubpath);
    final l10nDir = Directory(l10nPath);

    await for (final file in l10nDir.list()) {
      final filename = path.basename(file.path);
      final ext = path.extension(filename);

      if (ext == '.arb') {
        // TODO: check if this is needed file, without harcoded name
        if (filename == 'intl_${baseLocale}.arb') {
          return _proccessArb(File(file.path));
        }
      }
    }

    // TODO: how to return error?
    print('ABR file for locale ${baseLocale} is not found');
    return 1;
  }

  Future<int> _proccessArb(File file) async {
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

    // TODO: write to the file?
    print(xml.toString());
    return 0;
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
