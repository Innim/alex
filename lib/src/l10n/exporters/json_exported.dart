import 'dart:convert';
import 'dart:io';

import '../l10n_entry.dart';
import 'l10n_exporter.dart';

class JsonExporter extends L10nExporter {
  final String targetPath;

  JsonExporter(this.targetPath, String locale, Map<String, L10nEntry> data)
      : super(locale, data);

  @override
  Future<bool> execute() async {
    final map = <String, Object>{};

    data.forEach((key, value) {
      if (value is L10nTextEntry) {
        map[key] = value.text;
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
}
