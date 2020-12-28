import 'dart:io';

import 'package:alex/alex.dart';
import 'package:alex/runner/alex_command.dart';
import 'package:meta/meta.dart';
import 'package:path/path.dart' as path;

/// Base command for localization feature.
abstract class L10nCommandBase extends AlexCommand {
  static final _localeRegionRegEx = RegExp(r'[a-z]{2}_[A-Z]{2}');

  L10nCommandBase(String name, String description) : super(name, description);

  L10nConfig get l10nConfig => AlexConfig.instance.l10n;

  @protected
  Future<ProcessResult> runIntl(String cmd, List<String> arguments) async {
    return runPub('intl_translation:$cmd', arguments);
  }

  @protected
  Future<ProcessResult> runIntlOrFail(String cmd, List<String> arguments,
      {bool printStdOut = true}) async {
    return runOrFail(() => runIntl(cmd, arguments), printStdOut: printStdOut);
  }

  @protected
  Future<List<String>> getLocales(L10nConfig config) async {
    final baseDirPath = config.xmlOutputDir;
    final baseDir = Directory(baseDirPath);
    final baseLocale = config.baseLocaleForXml;

    final locales = <String>[];
    await for (final item in baseDir.list()) {
      if (item is Directory) {
        final name = path.basename(item.path);
        if (name != baseLocale && _isLocaleName(name)) locales.add(name);
      }
    }

    locales.sort();

    return locales;
  }

  bool _isLocaleName(String value) {
    // TODO: check by whitelist?
    if (value.length == 2) return true;

    if (value.length == 5) {
      return _localeRegionRegEx.hasMatch(value);
    }

    return false;
  }
}
