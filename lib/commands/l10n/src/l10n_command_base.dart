import 'dart:io';

import 'package:alex/alex.dart';
import 'package:alex/runner/alex_command.dart';
import 'package:alex/src/exception/run_exception.dart';
import 'package:alex/src/fs/fs.dart';
import 'package:alex/src/pub_spec.dart';
import 'package:meta/meta.dart';
import 'package:list_ext/list_ext.dart';
import 'package:path/path.dart' as path;

/// Base command for localization feature.
abstract class L10nCommandBase extends AlexCommand {
  static final _localeRegionRegEx = RegExp('[a-z]{2}_[A-Z]{2}');

  String _intlGeneratorPackage;

  L10nCommandBase(String name, String description) : super(name, description);

  L10nConfig get l10nConfig => AlexConfig.instance.l10n;

  @protected
  Future<ProcessResult> runIntl(String cmd, List<String> arguments,
      {String workingDir, bool prependWithPubGet = false}) async {
    final packageName = await _getIntlGeneratorPackageName();
    return runPub('$packageName:$cmd', arguments,
        workingDir: workingDir, prependWithPubGet: prependWithPubGet);
  }

  @protected
  Future<ProcessResult> runIntlOrFail(String cmd, List<String> arguments,
      {bool printStdOut = true,
      String workingDir,
      bool prependWithPubGet = false}) async {
    return runOrFail(
        () => runIntl(cmd, arguments,
            workingDir: workingDir, prependWithPubGet: prependWithPubGet),
        printStdOut: printStdOut);
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

  Future<String> _getIntlGeneratorPackageName() async {
    if (_intlGeneratorPackage != null) return _intlGeneratorPackage;

    final needle = ['intl_translation', 'intl_generator'];

    // TODO: may be better to check pubspec.lock?
    final spec = await Spec.pub(const IOFileSystem());

    final res = needle.firstWhereOrNull(spec.hasDevDependency);
    if (res == null) {
      throw RunException.err(
          "Can't found any of generation packages: ${needle.join(', ')}. "
          "Did you forget to add a dependency?");
    }

    return res;
  }
}
