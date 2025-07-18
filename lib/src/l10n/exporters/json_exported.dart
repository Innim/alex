import 'dart:convert';
import 'dart:io';

import 'package:alex/src/l10n/locale/locales.dart';

import '../l10n_entry.dart';
import 'l10n_exporter.dart';

class JsonExporter extends L10nExporter<JsonLocale> {
  final String targetPath;

  JsonExporter(this.targetPath, super.locale, super.data);

  @override
  Future<bool> execute() async {
    final map = <String, Object>{};

    data.forEach((key, value) {
      if (value is L10nTextEntry) {
        map[key] = _processText(value.text);
      } else {
        throw Exception('Unhandled entry type: ${value.runtimeType}');
      }
    });

    final json = const JsonEncoder.withIndent('  ').convert(map);

    final target = File(targetPath);

    if (!(await target.parent.exists())) {
      await target.parent.create();
    }

    return writeContentIfChanged(target, json);
  }

  String _processText(String text) {
    return text.replaceAll(r'\n', '\n').replaceAll(r'\r', '\r');
  }
}
