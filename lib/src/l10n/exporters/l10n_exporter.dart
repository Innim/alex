import 'dart:io';

import 'package:alex/src/l10n/locale/locales.dart';
import 'package:meta/meta.dart';

import '../l10n_entry.dart';

abstract class L10nExporter<T extends LocaleValue> {
  final T locale;
  final Map<String, L10nEntry> data;

  L10nExporter(this.locale, this.data);

  /// Execute export.
  ///
  /// Returns `true` if file was updated,
  /// returns `false` if files wasn't updated,
  /// but without error (no changed)
  /// and throws some `Exception` in case of error.
  Future<bool> execute();

  @protected
  Future<bool> writeContentIfChanged(File target, String content,
      {String Function(String val)? clear}) async {
    clear ??= (v) => v;
    final currentContent = await target.exists() ? await _readArb(target) : '';
    final hasChanged =
        currentContent.isEmpty || clear(currentContent) != clear(content);

    if (hasChanged) {
      await target.writeAsString(content);
    }

    return hasChanged;
  }

  @protected
  String clearWinLines(String str) => str.replaceAll('\r\n', '\n');

  Future<String> _readArb(File file) async {
    final res = await file.readAsString();
    return clearWinLines(res);
  }
}
