import 'dart:io';

import 'package:alex/alex.dart';
import 'package:alex/runner/alex_command.dart';
import 'package:alex/src/git/git.dart';
import 'package:alex/src/l10n/comparers/arb_comparer.dart';
import 'package:alex/src/l10n/locale/locales.dart';
import 'package:list_ext/list_ext.dart';
import 'package:xml/xml.dart';
import 'package:path/path.dart' as path;

import 'src/l10n_command_base.dart';

/// Command to check if translations exist for all strings.
///
/// By default it checks for all locales, but you can specify a locale.
class CheckTranslateCommand extends L10nCommandBase {
  static const _argLocale = 'locale';

  CheckTranslateCommand()
      : super(
          'check_translate',
          'Check if translations exist for all strings and prints detailed report about problems.\n'
              'Checks:\n'
              '- if all strings from the localization file (alex.l10n.source_file) have translation in ARB for the language; \n'
              '- if all strings from the localization file (alex.l10n.source_file) was sent for translation (contained in base XML); \n'
              '- if all strings from the base XML file have translation in XML for the language; \n'
              '- if there are not duplicated keys in XML for the language; \n'
              '- if all strings from the XML for the language are imported to ARB for this language; \n'
              '- if the XML for the language has not redundant strings that are not in the localization file (alex.l10n.source_file); \n'
              '- if all code is generated for the language.\n'
              'By default it checks for all locales, but you can specify locale with --$_argLocale option.',
        ) {
    argParser
      ..addOption(
        _argLocale,
        abbr: 'l',
        help: 'Locale to check if translations exist for all strings. '
            'If not specified then it will check all locales.',
        valueHelp: 'LOCALE',
      )
      ..addVerboseFlutterCmdFlag();
  }

  @override
  Future<int> doRun() async {
    final config = findConfigAndSetWorkingDir();
    final l10nConfig = config.l10n;
    final args = argResults!;
    final locale = args.getLocale(_argLocale);
    final printFlutterOut = isVerbose || isVerboseFlutterCmd;

    final git = getGit(config);

    git.ensureCleanStatus();

    final reports = <_CheckReport>[];
    try {
      printInfo('Get dependencies...');
      await flutter.pubGetOrFail(
        printStdOut: printFlutterOut,
        immediatePrint: printFlutterOut,
      );

      try {
        git.ensureCleanStatus();
      } catch (e) {
        printInfo('⚠️ Some files were changed after pub get. '
            'Check if your committed dependencies are correct.');
      }

      printInfo('Running extract to arb...');
      await extractLocalization(
        l10nConfig,
        printStdOut: printFlutterOut,
        prependWithPubGet: false,
      );

      printInfo('Starting checks...');

      if (locale == null) {
        printInfo('No locale specified, checking all locales.');
      } else {
        printInfo('Checking translations for locale: $locale');
      }

      Future<void> check({
        required String successMessage,
        required String failMessage,
        required Future<_CheckReport> check,
        String? noteForNotExpected,
      }) async {
        final report = await check;

        if (report.isOk) {
          _printCheckSuccess(successMessage);
        } else {
          _printCheckFailReport(
            failMessage,
            report.results,
            noteForNotExpected: noteForNotExpected,
          );
        }

        reports.add(report);
      }

      await check(
        successMessage: 'All strings have translation in ARB',
        failMessage: 'Untranslated strings found in ARB',
        check: _checkForUntranslated(l10nConfig, locale).report(),
      );

      await check(
        successMessage: 'All strings were sent for translation',
        failMessage: 'Some strings probably were not sent for translation',
        check: _checkForUnsent(l10nConfig).report(),
      );

      await check(
        successMessage: 'All strings have translation in XML',
        failMessage: 'Untranslated or redundant strings found in XML',
        check: _checkForUntranslatedXml(l10nConfig, locale).report(),
        noteForNotExpected: 'If you see this message, '
            'it means that some strings are presented in XML for the locale, but not in the base XML. '
            'Before do anything about it, check that all required strings are present in the base XML file.',
      );

      await check(
        successMessage: 'No duplicated keys in XML',
        failMessage: 'Duplicated keys found in XML',
        check: _checkXmlForDuplicates(l10nConfig, locale).report(),
      );

      await check(
        successMessage: 'All strings are imported to ARB',
        failMessage: 'Some strings are not imported to ARB from XML',
        check: _checkForNotImportedToArb(l10nConfig, locale).report(),
      );

      await check(
        successMessage: 'Generated localization code is up to date',
        failMessage:
            'Localization code probably is not generated after last changes',
        check: _checkForNotGeneratedCode(
          git,
          l10nConfig,
          locale,
          printFlutterOut: printFlutterOut,
        ).report(),
      );

      printInfo('Checks completed.');
    } finally {
      // Reset all changes after command execution
      printVerbose('Resetting all changes in GIT repository...');
      git.resetHard();
    }

    printInfo('');

    final total = reports.length;
    if (total == 0) {
      return error(
        2,
        message: 'No checks were performed. This is probably a bug.',
      );
    } else if (reports.every((e) => e.isOk)) {
      return success(message: '🏆 All checks passed [$total/$total].');
    } else {
      final failed = reports.countWhere((e) => !e.isOk);
      return error(
        2,
        message: '🚨 $failed of $total checks failed. See details above',
      );
    }
  }

  /// Checks for not translated strings in ARB.
  ///
  /// Not translated strings are those that are present in the base ARB file
  /// but not present in the ARB file for the specified locale.
  ///
  /// If `locale` is null, it checks for all locales.
  Future<List<_CheckResult>> _checkForUntranslated(
    L10nConfig l10nConfig,
    XmlLocale? locale,
  ) async {
    printVerbose('Check for untranslated strings');

    final res = <_CheckResult>[];
    final locales = locale != null
        ? [locale]
        : await getLocales(l10nConfig, includeBase: false);

    for (final loc in locales) {
      res.add(await _checkLocaleForUntranslated(l10nConfig, loc));
    }

    return res;
  }

  Future<_CheckResult> _checkLocaleForUntranslated(
    L10nConfig l10nConfig,
    XmlLocale locale,
  ) async {
    printVerbose('Check for untranslated strings for locale: $locale');
    final comparer = ArbComparer(l10nConfig, locale.toArbLocale());
    final notTranslatedKeys = await comparer.compare();
    if (notTranslatedKeys.isEmpty) {
      printVerbose('All strings have translation for locale: $locale');
      return _CheckResult.ok(locale);
    } else {
      printVerbose(
          'No translations for strings (${notTranslatedKeys.length}): ${notTranslatedKeys.join(',')} in locale: $locale');
      return _CheckResult.missedKeys(locale, notTranslatedKeys);
    }
  }

  /// Checks for unsent to translation strings in the localization files.
  ///
  /// We consider a string as "unsent" if is present in the base ARB file
  /// (after extraction), but not present in base XML file.
  Future<_CheckResult> _checkForUnsent(
    L10nConfig l10nConfig,
  ) async {
    printVerbose('Check for unsent strings');

    final file = getArbFile(l10nConfig);
    final keys = await getKeysFromArb(file);
    final xmlFile = getXmlFile(l10nConfig);

    final res = await _checkXmlKeys(xmlFile, keys);

    _printVerboseCheckKeysResult(
      'XML file ${xmlFile.path}',
      res,
    );

    return _CheckResult.byKeysCheck(
      l10nConfig.baseLocaleForArb.toXmlLocale(),
      res,
    );
  }

  /// Checks for untranslated XML for the specified locale.
  ///
  /// We consider a string as "untranslated" if it is present in the base XML file,
  /// but not present in the XML file for the specified locale.
  ///
  /// Also checks if all keys from the XML file for the specified locale
  /// are present in the base XML file.
  Future<List<_CheckResult>> _checkForUntranslatedXml(
    L10nConfig l10nConfig,
    XmlLocale? locale,
  ) async {
    printVerbose('Check for untranslated XML');

    final res = <_CheckResult>[];
    final locales = locale != null
        ? [locale]
        : await getLocales(l10nConfig, includeBase: false);

    for (final loc in locales) {
      res.add(await _checkLocaleForUntranslatedXml(l10nConfig, loc));
    }

    return res;
  }

  Future<_CheckResult> _checkLocaleForUntranslatedXml(
    L10nConfig l10nConfig,
    XmlLocale locale,
  ) async {
    printVerbose('Check for untranslated XML for locale: $locale');
    final baseXmlFile = getXmlFile(l10nConfig);
    final xmlFile = getXmlFile(l10nConfig, locale: locale);

    final keys = await getKeysFromXml(baseXmlFile);
    final res = await _checkXmlKeys(xmlFile, keys);

    _printVerboseCheckKeysResult(
      'XML file ${xmlFile.path}',
      res,
    );

    return _CheckResult.byKeysCheck(locale, res);
  }

  /// Checks for duplicated strings in XML.
  Future<List<_CheckResult>> _checkXmlForDuplicates(
    L10nConfig l10nConfig,
    XmlLocale? locale,
  ) async {
    printVerbose('Check for duplicated strings in XML');

    final res = <_CheckResult>[];
    final locales = locale != null
        ? [locale]
        : await getLocales(l10nConfig, includeBase: false);

    for (final loc in locales) {
      res.add(await _checkLocaleXmlForDuplicates(l10nConfig, loc));
    }

    return res;
  }

  Future<_CheckResult> _checkLocaleXmlForDuplicates(
    L10nConfig l10nConfig,
    XmlLocale locale,
  ) async {
    printVerbose('Check for XML for duplicated keys for locale: $locale');
    final xmlFile = getXmlFile(l10nConfig, locale: locale);

    final xml = getXML(xmlFile);
    final countByKeys = <String, int>{};

    xml.forEachResource((child) {
      if (child is XmlElement) {
        final name = child.attributeName;
        final count = countByKeys[name] ?? 0;
        if (count > 0) {
          printVerbose('  Duplicated key "$name" found in XML');
        }
        countByKeys[name] = count + 1;
      }
    });

    final duplicates = countByKeys.entries
        .where((e) => e.value > 1)
        .map((e) => '${e.key} (${e.value})');

    return _CheckResult(
      locale: locale,
      notExpectedKeysLabel: 'duplicated keys',
      notExpectedKeys: duplicates.toSet(),
    );
  }

  /// Checks for keys in XML for locale that are not imported to ARB for this locale.
  Future<List<_CheckResult>> _checkForNotImportedToArb(
    L10nConfig l10nConfig,
    XmlLocale? locale,
  ) async {
    printVerbose('Check for not imported to arb strings');

    final res = <_CheckResult>[];
    final locales = locale != null
        ? [locale]
        : await getLocales(l10nConfig, includeBase: true);

    for (final loc in locales) {
      res.add(await _checkLocaleForNotImportedToArb(l10nConfig, loc));
    }

    return res;
  }

  /// Checks for keys in XML for locale that are not imported to ARB for this locale.
  Future<_CheckResult> _checkLocaleForNotImportedToArb(
    L10nConfig l10nConfig,
    XmlLocale locale,
  ) async {
    printVerbose('Check for not imported to arb strings for locale: $locale');

    final baseArb = getArbFile(l10nConfig);
    final baseKeys = await getKeysFromArb(baseArb);

    final targetArb = getArbFile(l10nConfig, locale.toArbLocale());
    final arbKeys = await getKeysFromArb(targetArb);
    final xmlFile = getXmlFile(l10nConfig, locale: locale);

    final res = await _checkXmlKeys(xmlFile, arbKeys);

    // we found keys in XML that are not present in ARB
    // but filter it by base ARB keys
    final notPresentedInArb = res.notExpected.where(baseKeys.contains).toSet();

    if (notPresentedInArb.isNotEmpty) {
      printVerbose(
        'XML file ${xmlFile.path} contains keys that are not imported to ARB: ${res.notExpected.join(', ')}',
      );
      return _CheckResult.missedKeys(locale, notPresentedInArb);
    } else {
      printVerbose(
        'XML file ${xmlFile.path} -- all strings are imported to ARB.',
      );
      return _CheckResult.ok(locale);
    }
  }

  /// Checks for not generated code for the specified locale.
  ///
  /// If `locale` is null, it checks for all locales.
  Future<_CheckResult> _checkForNotGeneratedCode(
    GitCommands git,
    L10nConfig l10nConfig,
    XmlLocale? locale, {
    required bool printFlutterOut,
  }) async {
    printVerbose('Check for not generated code');

    git.resetHard();
    await generateLocalization(
      l10nConfig,
      prependWithPubGet: false,
      printStdOut: printFlutterOut,
    );

    final modifiedFiles = git.getModifiedFiles();
    printVerbose(
      'Modified files after generation: ${modifiedFiles.join(', ')}',
    );
    git.resetHard();

    final codeFileSuffix = locale?.toArbLocale().codeFileSuffix;

    final notGeneratedLocales = <String>{};
    final codeDirPath = l10nConfig.outputDir;
    final modifiedCodeFiles = modifiedFiles.where((f) {
      if (!path.isWithin(codeDirPath, f)) {
        printVerbose('> Skipping file not in code directory: $f');
        return false;
      }

      final name = path.basename(f);
      const end = '.dart';
      if (!name.endsWith(end)) {
        printVerbose('> Skipping not dart file: $name');
        return false;
      }

      const start = 'messages_';
      if (!name.startsWith(start)) {
        printVerbose('> Skipping file not starting with "$start": $name');
        return false;
      }

      final suffix = name.substring(start.length, name.length - end.length);
      if (suffix == 'all_locales') {
        printVerbose('> Skipping file with all locales: $name');
        return false;
      }

      if (codeFileSuffix != null && codeFileSuffix != suffix) {
        printVerbose(
          '> Skipping file for locale "$suffix" (looking for "$codeFileSuffix"): $name',
        );
        return false;
      }

      notGeneratedLocales.add(suffix);
      return true;
    }).toList();

    if (modifiedCodeFiles.isEmpty) {
      printVerbose(
        'All code is generated for ${locale != null ? 'locale: $locale' : 'all locales'}',
      );
      return _CheckResult.ok(locale);
    } else {
      final sb = StringBuffer()
        ..writeln(
          'Code is not generated for locales: ${notGeneratedLocales.join(', ')}.',
        )
        ..write(
          'Modified files after generation: ${modifiedCodeFiles.join(', ')}',
        );
      printVerbose(sb.toString());

      return _CheckResult.error(
        locale,
        'Has modified dart files after generation',
      );
    }
  }

  Future<_KeysCheckResult> _checkXmlKeys(
    File xmlFile,
    Set<String> expectedKeys,
  ) async {
    final notPresentedKeys = expectedKeys.toSet();
    final notExpectedKeys = <String>{};

    // ignoring duplicated keys here
    final keys = await getKeysFromXml(xmlFile);
    keys.forEach((key) {
      if (!notPresentedKeys.remove(key)) {
        notExpectedKeys.add(key);
      }
    });

    return _KeysCheckResult(
      notExpectedKeys,
      notPresentedKeys,
    );
  }

  void _printCheckSuccess(String title) {
    printInfo('✅ $title');
  }

  void _printCheckFailReport(
    String title,
    List<_CheckResult> results, {
    String? noteForNotExpected,
  }) {
    final printLocale = results.length > 1;

    final sb = StringBuffer('❌ $title');
    final fails = results.where((e) => !e.isOk);

    if (printLocale) {
      sb.write(' (${fails.length} locales)');
    }
    sb.write(':');

    const indent = '  ';

    var hasNotExpected = false;
    for (final res in fails) {
      if (printLocale) {
        sb
          ..writeln()
          ..write(indent)
          ..write('Locale: ${res.locale}');
      }

      final errorMessage = res.error;
      if (errorMessage != null) {
        sb
          ..writeln()
          ..write(indent)
          ..write('Description: ')
          ..write(errorMessage);
      }

      if (res.notPresentedKeys.isNotEmpty) {
        sb
          ..writeln()
          ..write(indent)
          ..write('- missed keys ')
          ..write('(${res.notPresentedKeys.length}): ')
          ..write(res.notPresentedKeys.join(', '));
      }

      if (res.notExpectedKeys.isNotEmpty) {
        hasNotExpected = true;

        sb
          ..writeln()
          ..write(indent)
          ..write('- ')
          ..write(res.notExpectedKeysLabel ?? 'not expected keys')
          ..write(' (${res.notExpectedKeys.length}): ')
          ..write(res.notExpectedKeys.join(', '));
      }
    }
    if (hasNotExpected && noteForNotExpected != null) {
      sb
        ..writeln()
        ..write(indent)
        ..write('💡 ')
        ..write(noteForNotExpected);
    }
    printInfo(sb.toString());
  }

  void _printVerboseCheckKeysResult(
    String title,
    _KeysCheckResult res,
  ) {
    if (res.isOk) {
      printVerbose('$title -- check passed.');
    } else {
      final sb = StringBuffer('$title -- check failed.');
      if (res.notPresented.isNotEmpty) {
        sb
          ..writeln()
          ..write('- does not contain all expected keys ')
          ..write('(${res.notPresented.length}): ')
          ..write(res.notPresented.join(', '));
      }

      if (res.notExpected.isNotEmpty) {
        sb
          ..writeln()
          ..write('- contains unexpected keys ')
          ..write('(${res.notExpected.length}): ')
          ..write(res.notExpected.join(', '));
      }

      printVerbose(sb.toString());
    }
  }
}

class _KeysCheckResult {
  final Iterable<String> notExpected;
  final Iterable<String> notPresented;

  _KeysCheckResult(this.notExpected, this.notPresented);

  bool get isOk => notExpected.isEmpty && notPresented.isEmpty;

  @override
  String toString() {
    return 'KeysCheckResult{notExpected: $notExpected, notPresented: $notPresented}';
  }
}

class _CheckReport {
  final List<_CheckResult> results;

  _CheckReport(this.results);
  _CheckReport.single(_CheckResult result) : results = [result];

  bool get isOk => results.every((e) => e.isOk);
}

class _CheckResult {
  final XmlLocale? locale;
  final Iterable<String> notPresentedKeys;
  final Iterable<String> notExpectedKeys;
  final String? error;
  final String? notExpectedKeysLabel;

  _CheckResult({
    required this.locale,
    // ignore: unused_element
    this.notPresentedKeys = const [],
    this.notExpectedKeys = const [],
    // ignore: unused_element
    this.error,
    this.notExpectedKeysLabel,
  });

  _CheckResult.ok(this.locale)
      : notPresentedKeys = [],
        notExpectedKeys = [],
        error = null,
        notExpectedKeysLabel = null;

  _CheckResult.error(this.locale, this.error)
      : notPresentedKeys = [],
        notExpectedKeys = [],
        notExpectedKeysLabel = null;

  _CheckResult.missedKeys(this.locale, this.notPresentedKeys)
      : notExpectedKeys = const [],
        error = null,
        notExpectedKeysLabel = null;

  _CheckResult.byKeysCheck(this.locale, _KeysCheckResult keyCheckResult)
      : notPresentedKeys = keyCheckResult.notPresented,
        notExpectedKeys = keyCheckResult.notExpected,
        error = null,
        notExpectedKeysLabel = null;

  bool get isOk =>
      notPresentedKeys.isEmpty && notExpectedKeys.isEmpty && error == null;
}

extension _CheckResultListFutureExt on Future<List<_CheckResult>> {
  Future<_CheckReport> report() => then(_CheckReport.new);
}

extension _CheckResultFutureExt on Future<_CheckResult> {
  Future<_CheckReport> report() => then(_CheckReport.single);
}
