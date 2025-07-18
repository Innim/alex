import 'dart:convert';
import 'dart:io';

import 'package:alex/src/l10n/decoders/arb_decoder.dart';
import 'package:alex/src/l10n/locale/locales.dart';

import '../l10n_entry.dart';
import 'l10n_exporter.dart';

class ArbExporter extends L10nExporter<ArbLocale> {
  static final _paramRegExp = RegExp(r'\{([\p{L}\P{Me}][\p{L}\P{Me}0-9_]*?)\}',
      caseSensitive: false, unicode: true, multiLine: true);

  static final _lastModifiedLineRegex = RegExp('[ ]*"@@last_modified":.*');

  final Map<String, dynamic> baseArb;
  final String targetPath;

  ArbExporter(this.baseArb, this.targetPath, super.locale, super.data);

  @override
  Future<bool> execute() async {
    final map = <String, Object>{
      '@@last_modified': DateTime.now().toIso8601String(),
    };

    data.forEach((key, value) {
      final metaKey = '@$key';
      final baseMeta = baseArb[metaKey] as Map<String, dynamic>?;
      if (baseMeta == null) throw MissedMetaException(key);

      final parameters =
          (baseMeta['placeholders'] as Map<String, dynamic>).keys.toSet();

      if (value is L10nTextEntry) {
        map[key] = _processText(key, parameters, value.text);
      } else if (value is L10nPluralEntry) {
        // Получаем заголовочную часть
        const pluralPrefix = ',plural,';
        final baseStr = baseArb[key] as String;
        final prefix = baseStr.split(pluralPrefix).first;

        final baseValue =
            arbDecoder.decodeValue(key, baseStr) as L10nPluralEntry;

        final val = StringBuffer(prefix)
          ..write(pluralPrefix)
          ..write(' ');
        <String, String?>{
          '=0': value.zero,
          '=1': value.one,
          '=2': value.two,
          'few': value.few,
          'many': value.many,
          'other': value.other,
        }.forEach((attr, value) {
          final baseVal = baseValue.find(attr);
          final allowed = baseVal == null
              ? <String>{}
              : parameters
                  .where((param) => baseVal.contains('{$param}'))
                  .toSet();
          return _addPlural(val, key, allowed, value, attr);
        });
        val.write('}');

        map[key] = val.toString();
      } else {
        final entryType = baseMeta['type'] as String;
        throw Exception('Unhandled arb key type: $entryType');
      }

      map['@$key'] = baseMeta;
    });

    final json = const JsonEncoder.withIndent('  ').convert(map);

    final target = File(targetPath);
    return writeContentIfChanged(target, json, clear: _removeLastModified);
  }

  String _removeLastModified(String json) {
    return json.replaceFirst(_lastModifiedLineRegex, '');
  }

  void _addPlural(StringBuffer res, String key, Set<String> allowedParams,
      String? val, String attr) {
    if (val != null) {
      res
        ..write(attr)
        ..write('{')
        ..write(_processText(key, allowedParams, val))
        ..write('}');
    }
  }

  String _processText(String key, Set<String> allowed, String text) {
    return clearWinLines(_validateParameters(key, allowed, text)
        .replaceAll(r'\n', '\n')
        .replaceAll(r'\r', '\r')
        // escape single quotes
        // https://docs.flutter.dev/ui/accessibility-and-internationalization/internationalization#escaping-syntax
        .replaceAll("'", "''"));
  }

  String _validateParameters(String key, Set<String> allowed, String text) {
    final params = _paramRegExp.allMatches(text).map((e) => e.group(1));

    if (params.isNotEmpty) {
      for (final param in params) {
        if (!allowed.contains(param)) {
          throw Exception(
              '[$locale] Unknown parameter {$param} for key "$key"');
        }
      }
    } else {
      if (allowed.isNotEmpty) {
        throw Exception('[$locale] No parameters found for key "$key". '
            'Expected: ${allowed.join(', ')}.');
      }
    }

    return text;
  }
}

class MissedMetaException implements Exception {
  final String key;

  const MissedMetaException(this.key);

  String get message => "Can't find meta for <$key>";

  @override
  String toString() {
    return "Exception: $message";
  }
}
