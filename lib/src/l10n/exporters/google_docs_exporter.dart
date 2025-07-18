import 'package:alex/src/l10n/locale/locales.dart';

import '../l10n_entry.dart';
import 'l10n_exporter.dart';
import 'package:alex/internal/print.dart' as print;

class GoogleDocsExporter extends L10nExporter<XmlLocale> {
  final List<String> keys;

  // TODO: use custom locale type
  GoogleDocsExporter(XmlLocale locale, Map<String, L10nEntry> data, this.keys)
      : super(locale, data);

  @override
  Future<bool> execute() async {
    // TODO: implement integration with google docs
    print.info('');
    print.info('String for $locale');
    for (final key in keys) {
      final entry = data[key];
      String res;
      if (entry is L10nTextEntry) {
        res = entry.text;
        if (res.startsWith('+')) res = "'$res";
      } else {
        throw Exception('Unhandled entry: $entry');
      }

      print.info(res);
    }
    print.info('');

    // TODO: check for changes
    return true;
  }
}
