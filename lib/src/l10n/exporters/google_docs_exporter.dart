import '../l10n_entry.dart';
import 'l10n_exporter.dart';

class GoogleDocsExporter extends L10nExporter {
  final List<String> keys;

  GoogleDocsExporter(String locale, Map<String, L10nEntry> data, this.keys)
      : super(locale, data);

  @override
  Future<void> execute() async {
    // TODO: implement integration with google docs
    print('');
    print('String for $locale');
    for (var key in keys) {
      final entry = data[key];
      String res;
      if (entry is L10nTextEntry) {
        res = entry.text;
        if (res.startsWith('+')) res = "'" + res;
      } else {
        throw Exception('Unhandled entry: $entry');
      }

      print(res);
    }
    print('');
  }
}
