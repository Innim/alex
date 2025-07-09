import 'package:alex/alex.dart';
import 'package:alex/src/exception/run_exception.dart';
import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:xml/xml.dart';

import 'src/l10n_command_base.dart';

const _jsonDecoder = JsonCodec();

/// Command to remove unused strings from XML files.
///
/// This command checks XML files for all locales and
/// removes strings that are not existing in the main ARB file.
class CleanupXmlCommand extends L10nCommandBase {
  static const _argLocale = 'locale';

  CleanupXmlCommand()
      : super(
          'cleanup_xml',
          'Remove all redundant strings from XML files',
        ) {
    argParser
      ..addOption(
        _argLocale,
        abbr: 'l',
        help: 'Locale for main ARB file. By default this is '
            'base_locale_for_xml from alex configuration.',
        valueHelp: 'LOCALE',
      );
  }

  @override
  Future<int> doRun() async {
    final args = argResults!;
    final config = findConfigAndSetWorkingDir();
    final l10nConfig = config.l10n;

    final baseLocale =
        args[_argLocale] as String? ?? l10nConfig.baseLocaleForArb;

    return _cleanUp(l10nConfig, baseLocale);
  }

  Future<int> _cleanUp(L10nConfig config, String baseLocale) async {
    final l10nSubpath = config.outputDir;

    final l10nPath = path.join(path.current, l10nSubpath);
    final l10nDir = Directory(l10nPath);

    final sourceFileName = L10nUtils.getArbFile(config, baseLocale);
    final file = File(path.join(l10nDir.path, sourceFileName));

    final exists = await file.exists();
    if (!exists) {
      return error(2, message: 'ABR file for locale $baseLocale is not found');
    }

    final keys = await _getKeysFromArb(file);

    final locales = await getLocales(config, includeBase: true);
    printVerbose('Locales (${locales.length}): ${locales.join(', ')}');

    final xmlFileName = config.getMainXmlFileName();
    var filesProcessed = 0;
    var stringsRemoved = 0;
    for (final locale in locales) {
      printVerbose('Processing locale: $locale');
      final xmlFileDirPath = config.getXmlFilesPath(locale);
      final xmlFilePath = path.join(xmlFileDirPath, xmlFileName);
      final xmlFile = File(xmlFilePath);

      final removed = await _removeOmitted(xmlFile, keys.toSet());

      filesProcessed++;
      stringsRemoved += removed;

      if (removed > 0) {
        printInfo('Removed $removed strings from XML for locale $locale');
      } else {
        printInfo('No strings removed from XML for locale $locale');
      }
    }

    final sb = StringBuffer('🧹 Cleanup completed.\n');
    if (filesProcessed == 0) {
      return error(
        1,
        message: 'No XML files processed. '
            'Check your configuration and ensure that XML files exist.',
      );
    } else {
      sb.writeln('Processed $filesProcessed XML files.');
      if (stringsRemoved > 0) {
        sb
          ..write('Removed $stringsRemoved strings from XML files (')
          ..write((stringsRemoved / filesProcessed).toStringAsFixed(2))
          ..write(' per file)')
          ..writeln('.');
      } else {
        sb.writeln('No strings removed from XML files.');
      }

      return success(message: sb.toString());
    }
  }

  Future<Set<String>> _getKeysFromArb(File file) async {
    final src = await file.readAsString();
    final data = _jsonDecoder.decode(src) as Map<String, dynamic>;
    return data.keys.where((k) => !k.startsWith('@')).toSet();
  }

  Future<int> _removeOmitted(File xmlFile, Set<String> keys) async {
    printVerbose('Remove omitted keys from ${xmlFile.path}');
    if (!xmlFile.existsSync()) {
      throw RunException.err('XML file ${xmlFile.path} does not exist.');
    }

    final xml = getXML(xmlFile);
    final outputElements = <XmlNode>{};
    final removedKeys = <String>{};
    xml.forEachResource((child) {
      if (child is XmlElement) {
        final name = child.attributeName;
        if (!keys.contains(name)) {
          printVerbose('  Remove key "$name"');
          removedKeys.add(name);
        } else {
          outputElements.add(child.copy());
        }
      } else {
        outputElements.add(child.copy());
      }
    });

    if (removedKeys.isEmpty) {
      printVerbose('No keys removed.');
      return 0;
    } else {
      printVerbose('Removed keys: ${removedKeys.join(', ')}');
      printVerbose('Saving cleaned XML to ${xmlFile.path}');
      await writeXML(xmlFile, outputElements);
      return removedKeys.length;
    }
  }
}
