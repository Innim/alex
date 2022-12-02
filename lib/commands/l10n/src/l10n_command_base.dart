import 'dart:io';

import 'package:alex/alex.dart';
import 'package:alex/runner/alex_command.dart';
import 'package:alex/src/exception/run_exception.dart';
import 'package:meta/meta.dart';
import 'package:list_ext/list_ext.dart';
import 'package:path/path.dart' as path;
import 'package:xml/xml.dart';

import 'mixins/intl_mixin.dart';

/// Base command for localization feature.
abstract class L10nCommandBase extends AlexCommand with IntlMixin {
  static final _localeRegionRegEx = RegExp('[a-z]{2}_[A-Z]{2}');

  L10nCommandBase(String name, String description,
      [List<String> aliases = const []])
      : super(name, description, aliases);

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

  XmlDocument getXML(File file) {
    try {
      return XmlDocument.parse(file.readAsStringSync());
    } catch (e, st) {
      printVerbose('Exception during parsing xml from ${file.path}: $e\n$st');
      throw RunException.err('Failed parsing XML from ${file.path}: $e');
    }
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
