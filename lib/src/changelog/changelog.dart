import 'package:alex/src/fs/fs.dart';
import 'package:intl/intl.dart';
import 'package:version/version.dart';

class Changelog {
  static const _filename = "CHANGELOG.md";

  static const _headerPrefix = '## ';
  static const _nextVersionHeader = '${_headerPrefix}Next release';
  static const _versionHeaderPrefix = '${_headerPrefix}v';
  static const _subheaderPrefix = '### ';
  static const _addedSubheader = '${_subheaderPrefix}Added';
  static const _fixedSubheader = '${_subheaderPrefix}Fixed';
  static const _preReleaseSubheader = '${_subheaderPrefix}Pre-release';

  static const _subheadersOrder = [
    _addedSubheader,
    _fixedSubheader,
    _preReleaseSubheader
  ];

  final FileSystem fs;
  Future<String>? _content;

  Changelog(this.fs);

  Future<String> get content => _content ??= _load();

  Future<bool> get exists => fs.existsFile(_filepath);

  Future<void> reload() async {
    _content = _load();
    await _content;
  }

  Future<void> save() async {
    if (_content != null) {
      await fs.writeString(_filepath, await _content!);
    }
  }

  Future<bool> hasVersion(Version version) async =>
      (await content).contains('$_versionHeaderPrefix$version');

  Future<bool> hasAnyVersion() async =>
      (await getLastVersionChangelog()) != null;

  Future<String> getNextReleaseChangelog({bool includeHeader = false}) async {
    var str = await content;

    final endIndex = str.indexOf(_versionHeaderPrefix);
    if (endIndex != -1) {
      str = str.substring(0, endIndex);
    }

    if (!includeHeader) str = str.replaceFirst(_nextVersionHeader, '');
    str = str.trim();
    if (str.isEmpty || includeHeader && str == _nextVersionHeader) return str;

    final res = StringBuffer()..writeln(str);
    return res.toString();
  }

  Future<void> setNextReleaseChangelog(String value) async {
    final str = await content;

    final endIndex = str.indexOf(_versionHeaderPrefix);

    final res = StringBuffer()..writeln(value);
    if (endIndex != -1) res.write(str.substring(endIndex));

    _update(res.toString());
  }

  Future<String?> getLastVersionChangelog() async {
    final str = await content;

    const marker = "## v";
    final curIndex = str.indexOf(marker);
    if (curIndex == -1) return null;

    final lastIndex = str.indexOf(marker, curIndex + 1);
    if (lastIndex != -1) {
      return str.substring(curIndex, lastIndex);
    }

    return str.substring(curIndex);
  }

  Future<void> releaseVersion(Version version, {DateTime? date}) async {
    date ??= DateTime.now();
    final dateStr = DateFormat("yyyy-MM-dd").format(date);

    _update((await content).replaceFirst(_nextVersionHeader,
        "$_nextVersionHeader\n\n$_versionHeaderPrefix$version - $dateStr"));
  }

  Future<void> addAddedEntry(String line, [int? issueId]) =>
      _addEntry(_addedSubheader, line, issueId);
  Future<void> addFixedEntry(String line, [int? issueId]) =>
      _addEntry(_fixedSubheader, line, issueId);
  Future<void> addPreReleaseEntry(String line, [int? issueId]) =>
      _addEntry(_preReleaseSubheader, line, issueId);

  String get _filepath => _filename;

  Future<void> _addEntry(String subheader, String line, int? issueId) async {
    const sep = '\n';
    const entryStart = '- ';
    const entryEnd = '.';

    final prevContent = await getNextReleaseChangelog(includeHeader: true);
    final lines = prevContent.split(sep);

    int targetIndex;

    final startIndex = lines.indexWhere((e) => e.trim() == subheader) + 1;

    if (startIndex == 0) {
      // No header, need to add it

      // consider order of subheaders
      final orderIndex = _subheadersOrder.indexOf(subheader);
      var startNextHeaderIndex = -1;
      for (var nextHeaderOrderIndex = orderIndex + 1;
          nextHeaderOrderIndex < _subheadersOrder.length;
          nextHeaderOrderIndex++) {
        startNextHeaderIndex = lines.indexWhere(
            (e) => e.trim() == _subheadersOrder[nextHeaderOrderIndex]);

        if (startNextHeaderIndex != -1) break;
      }

      final insertPosition =
          startNextHeaderIndex == -1 ? lines.length : startNextHeaderIndex;

      final insert = [
        if (lines[insertPosition - 1].trim().isNotEmpty) '',
        subheader,
        '',
        '',
      ];

      lines.insertAll(insertPosition, insert);
      targetIndex = insertPosition + insert.length - 1;
    } else {
      var sectionLen = lines.length == startIndex
          ? 0
          : lines.sublist(startIndex).indexWhere((e) {
              final trimmed = e.trim();
              return trimmed.startsWith(_headerPrefix) ||
                  trimmed.startsWith(_subheaderPrefix);
            });

      if (sectionLen < 0) sectionLen = lines.length - startIndex;
      final endIndex = startIndex + sectionLen;

      final lastNotEmptyIndex = startIndex +
          lines
              .sublist(startIndex, endIndex)
              .lastIndexWhere((e) => e.trim().isNotEmpty);

      targetIndex = lastNotEmptyIndex + 1;
    }

    final entry = StringBuffer();

    var str = line;
    String? issueSuffix;
    if (issueId != null) {
      issueSuffix = '(#$issueId)';
      var clearedStr = str.trimRight();
      var clearedEnd = clearedStr.length;
      for (var i = clearedEnd - 1; i >= 0; i--) {
        if (clearedStr[i] != '.') break;
        clearedEnd--;
      }
      clearedStr = clearedStr.substring(0, clearedEnd);
      if (clearedStr.endsWith(issueSuffix)) {
        str = clearedStr
            .substring(0, clearedStr.length - issueSuffix.length)
            .trimRight();
      }
    }

    if (!str.trimLeft().startsWith(entryStart)) entry.write(entryStart);
    entry.write(str);
    if (!str.trimRight().endsWith(entryEnd)) entry.write(entryEnd);
    if (issueSuffix != null) {
      entry
        ..write(' ')
        ..write(issueSuffix);
    }

    lines.insert(targetIndex, entry.toString());

    final updatedContent = lines.join(sep);
    await setNextReleaseChangelog(updatedContent);
  }

  void _update(String content) {
    _content = Future.value(content);
  }

  Future<String> _load() async {
    final res = await fs.readString(_filepath);
    if (!_validate(res)) {
      throw Exception("CHANGELOG.md has unknown structure");
    }

    return res;
  }

  bool _validate(String content) {
    return content.startsWith(_nextVersionHeader);
  }
}
