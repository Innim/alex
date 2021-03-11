import '../l10n_entry.dart';

abstract class L10nExporter {
  final String locale;
  final Map<String, L10nEntry> data;

  L10nExporter(this.locale, this.data);

  /// Execute export.
  ///
  /// Returns `true` if file was updated,
  /// returns `false` if files wasn't updated,
  /// but without error (no changed)
  /// and throws some `Exception` in case of error.
  Future<bool> execute();
}
