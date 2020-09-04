import '../l10n_entry.dart';

abstract class L10nExporter {
  final String locale;
  final Map<String, L10nEntry> data;

  L10nExporter(this.locale, this.data);

  Future<void> execute();
}
