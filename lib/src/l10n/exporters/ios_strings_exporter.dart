import 'dart:io';

import 'package:alex/src/exception/run_exception.dart';
import 'package:alex/src/l10n/path_providers/l10n_ios_path_provider.dart';
import 'package:alex/src/l10n/utils/l10n_ios_utils.dart';

import '../l10n_entry.dart';
import 'l10n_exporter.dart';

/// Export to iOS localization .strings file.
class IosStringsExporter extends L10nExporter {
  final L10nIosPathProvider provider;
  final String projectName;
  final String xmlFileName;

  IosStringsExporter(this.provider, this.projectName, this.xmlFileName,
      String locale, Map<String, L10nEntry> data)
      : super(locale, data);

  @override
  Future<bool> execute() async {
    final targetFileName = provider.getTargetFileName(xmlFileName);

    final date = DateTime.now().toIso8601String();
    final result = StringBuffer('''
/* 
  $targetFileName
  $projectName

  Autogenerated by alex on $date.
  Copyright © 2019 The Chromium Authors. All rights reserved.

  ! DO NOT EDIT MANUALLY !
*/
''');

    final headerLength = result.length;

    data.forEach((key, value) {
      result..write('"')..write(key)..write('"="');

      if (value is L10nTextEntry) {
        result.write(_prepareStr(value.text));
      } else {
        throw Exception('Unhandled value type: ${value.runtimeType}');
      }

      result.writeln('";');
    });

    final iosLocale = L10nIosUtils.getIosLocale(locale);

    final target = await _requireTargetFile(iosLocale, targetFileName);
    final newContent = result.toString();

    return writeContentIfChanged(target, newContent,
        clear: (str) =>
            str.length >= headerLength ? str.substring(headerLength) : str);
  }

  Future<File> _requireTargetFile(
      String iosLocale, String targetFileName) async {
    File _getTargetFile(String l) =>
        provider.getLocalizationFile(projectName, l, targetFileName);
    Future<File> _checkAltLocale(String altLocale) async {
      final altRes = _getTargetFile(altLocale);
      final altExist = await altRes.exists();
      return altExist ? altRes : null;
    }

    final res = _getTargetFile(iosLocale);
    final exist = await res.exists();

    if (!exist) {
      // process some locales which is not presented or dirrefent in ios
      if (iosLocale.startsWith('zh-') && iosLocale.split('-').length == 2) {
        // chinese
        for (final altLocale in ['Hans', 'Hant']
            .map((s) => iosLocale.replaceFirst('zh-', 'zh-$s-'))) {
          final altRes = await _checkAltLocale(altLocale);
          if (altRes != null) return altRes;
        }
      } else if (iosLocale == 'no') {
        // norwegian
        final altRes = await _checkAltLocale('nb');
        if (altRes != null) return altRes;
      }

      throw RunException.fileNotFound('Cannot find a file: ${res.path}');
    } else {
      return res;
    }
  }

  String _prepareStr(String text) {
    return text.replaceAll('"', r'\"').replaceAll('\n', r'\n');
  }
}
