import 'dart:convert';
import 'dart:io';

import '../l10n_entry.dart';
import 'l10n_exporter.dart';

class ArbExporter extends L10nExporter {
  static final _paramRegExp = RegExp(r'\{([a-z][a-z0-9_]*)\}',
      caseSensitive: false, unicode: true, multiLine: true);

  final Map<String, Object> baseArb;
  final String targetPath;

  ArbExporter(
      this.baseArb, this.targetPath, String locale, Map<String, L10nEntry> data)
      : super(locale, data);

  @override
  Future<void> execute() async {
    final map = <String, Object>{
      '@@last_modified': DateTime.now().toIso8601String(),
    };

    data.forEach((key, value) {
      final metaKey = '@$key';
      final baseMeta = baseArb[metaKey] as Map<String, Object>;
      if (baseMeta == null) throw Exception("Can't find meta for $key");
      final parameters =
          (baseMeta['placeholders'] as Map<String, Object>).keys.toSet();

      if (value is L10nTextEntry) {
        map[key] = _validateParameters(key, parameters, value.text);
      } else if (value is L10nPluralEntry) {
        // Получаем заголовочную часть
        const pluralPrefix = ',plural,';
        final baseVal = baseArb[key] as String;
        final prefix = baseVal.split(pluralPrefix).first;

        final val = StringBuffer(prefix)..write(pluralPrefix)..write(' ');
        <String, String>{
          '=0': value.zero,
          '=1': value.one,
          '=2': value.two,
          'few': value.few,
          'many': value.many,
          'other': value.other,
        }.forEach(
            (attr, value) => _addPlural(val, key, parameters, value, attr));
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
    await target.writeAsString(json);
  }

  void _addPlural(StringBuffer res, String key, Set<String> allowedParams,
      String val, String attr) {
    if (val != null) {
      res
        ..write(attr)
        ..write('{')
        ..write(_validateParameters(key, allowedParams, val))
        ..write('}');
    }
  }

  String _validateParameters(String key, Set<String> allowed, String text) {
    final params = _paramRegExp.allMatches(text).map((e) => e.group(1));
    for (final param in params) {
      if (!allowed.contains(param)) {
        throw Exception('[$locale] Unknown parameter {$param} for key "$key"');
      }
    }

    return text;
  }
}
