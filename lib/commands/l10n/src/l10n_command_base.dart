import 'dart:convert';
import 'dart:io';

import 'package:alex/alex.dart';
import 'package:alex/runner/alex_command.dart';
import 'package:alex/src/exception/run_exception.dart';
import 'package:alex/src/l10n/locale/locales.dart';
import 'package:args/args.dart';
import 'package:meta/meta.dart';
import 'package:list_ext/list_ext.dart';
import 'package:path/path.dart' as path;
import 'package:xml/xml.dart';

import 'mixins/intl_mixin.dart';

const _jsonDecoder = JsonCodec();

/// Base command for localization feature.
abstract class L10nCommandBase extends AlexCommand with IntlMixin {
  static final _localeRegionRegEx = RegExp('[a-z]{2}_[A-Z]{2}');

  L10nCommandBase(String name, String description,
      [List<String> aliases = const []])
      : super(name, description, aliases);

  @protected
  Future<List<XmlLocale>> getLocales(
    L10nConfig config, {
    bool includeBase = false,
  }) async {
    final baseDirPath = config.xmlOutputDir;
    final baseDir = Directory(baseDirPath);
    final baseLocale = config.baseLocaleForXml;

    final locales = <XmlLocale>[];
    await for (final item in baseDir.list()) {
      if (item is Directory) {
        final name = path.basename(item.path);
        if ((includeBase || name != baseLocale.value) && _isLocaleName(name)) {
          locales.add(name.asXmlLocale());
        }
      }
    }

    locales.sort();

    return locales;
  }

  @protected
  File getArbFile(L10nConfig config, [ArbLocale? locale]) {
    final l10nSubpath = config.outputDir;

    final l10nPath = path.join(path.current, l10nSubpath);
    final l10nDir = Directory(l10nPath);

    locale ??= config.baseLocaleForArb;

    final sourceFileName = L10nUtils.getArbFile(config, locale);
    final file = File(path.join(l10nDir.path, sourceFileName));

    final exists = file.existsSync();
    if (!exists) {
      throw RunException.fileNotFound(
          'ABR file for locale $locale is not found');
    }

    return file;
  }

  @protected
  File getXmlFile(L10nConfig config, {XmlLocale? locale, String? name}) {
    final xmlFileName = name ?? config.getMainXmlFileName();
    locale ??= config.baseLocaleForXml;

    final xmlFileDirPath = config.getXmlFilesPath(locale);
    final xmlFilePath = path.join(xmlFileDirPath, xmlFileName);
    final file = File(xmlFilePath);

    final exists = file.existsSync();
    if (!exists) {
      throw RunException.fileNotFound(
          'XML file for locale $locale is not found at ${file.path}');
    }
    return file;
  }

  @protected
  Future<Set<String>> getKeysFromArb(File file) async {
    final src = await file.readAsString();
    final data = _jsonDecoder.decode(src) as Map<String, dynamic>;
    return data.keys.where((k) => !k.startsWith('@')).toSet();
  }

  @protected
  Future<Set<String>> getKeysFromXml(File file) async {
    final xml = getXML(file);

    return xml.resources.children
        .whereType<XmlElement>()
        .map((e) => e.attributeName)
        .toSet();
  }

  XmlDocument getXML(File file) {
    try {
      return XmlDocument.parse(file.readAsStringSync());
    } catch (e, st) {
      printVerbose('Exception during parsing xml from ${file.path}: $e\n$st');
      throw RunException.err('Failed parsing XML from ${file.path}: $e');
    }
  }

  @protected
  Future<File> writeXML(File target, Set<XmlNode> elements) async {
    final outputXml = XmlDocument([
      XmlElement(XmlName.fromString('resources')),
    ]);
    outputXml.resources.children.addAll(elements);

    final outputBuffer = StringBuffer();
    outputBuffer.writeln('<?xml version="1.0" encoding="utf-8"?>');
    outputBuffer.write(outputXml.toXmlString(
        pretty: true,
        preserveWhitespace: (node) => node.getAttribute('name') != null));

    return target.writeAsString(outputBuffer.toString());
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

extension XmlDocumentExtension on XmlDocument {
  XmlElement get resources => findAllElements('resources').first;

  void forEachResource(void Function(XmlNode child) callback) {
    for (final child in resources.children) {
      callback(child);
    }
  }
}

extension XmlNodeExtension on XmlNode {
  String? get attributeName => getAttribute('name');
}

extension XmlElementExtension on XmlElement {
  String get attributeName => getAttribute('name')!;

  bool isEquals(XmlElement other) {
    if (attributeName == other.attributeName) {
      final name = this.name.toString();
      if (name == other.name.toString()) {
        switch (name) {
          case 'string':
            return text.replaceAll('\r\n', '\n') ==
                other.text.replaceAll('\r\n', '\n');
          case 'plurals':
            final myChildren = children.whereType<XmlElement>();
            final otherChildren = other.children.whereType<XmlElement>();
            return !myChildren.any((e) =>
                otherChildren.firstWhereOrNull((oe) =>
                    oe.getAttribute('quantity') == e.getAttribute('quantity') &&
                    oe.text == e.text) ==
                null);
        }
      }
    }

    return false;
  }
}

extension L10nArgResultsExt on ArgResults {
  XmlLocale? getLocale(String argName) {
    final locale = this[argName] as String?;
    return locale != null && locale.isNotEmpty ? locale.asXmlLocale() : null;
  }
}
