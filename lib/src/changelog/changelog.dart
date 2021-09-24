import 'package:alex/src/fs/fs.dart';
import 'package:intl/intl.dart';
import 'package:version/version.dart';

class Changelog {
  static const _filename = "CHANGELOG.md";
  static const _nextVersionHeader = '## Next release';
  static const _versionHeaderPrefix = '## v';

  final FileSystem fs;
  Future<String> _content;

  Changelog(this.fs);

  Future<String> get content => _content ??= _load();

  Future<void> reload() async {
    _content = _load();
    await _content;
  }

  Future<void> save() async {
    if (_content != null) {
      await fs.writeString(_filename, await _content);
    }
  }

  Future<bool> hasVersion(Version version) async =>
      (await content).contains('$_versionHeaderPrefix$version');

  Future<String> getNextReleaseChangelog() async {
    var str = await content;

    final endIndex = str.indexOf(_versionHeaderPrefix);
    if (endIndex != -1) {
      str = str.substring(0, endIndex);
    }

    str = str.replaceFirst(_nextVersionHeader, '').trim();
    if (str.isEmpty) return '';

    final res = StringBuffer()..writeln(str);
    return res.toString();
  }

  Future<String> getLastVersionChangelog() async {
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

  Future<void> releaseVersion(Version version, {DateTime date}) async {
    date ??= DateTime.now();
    final dateStr = DateFormat("yyyy-MM-dd").format(date);

    _update((await content).replaceFirst(_nextVersionHeader,
        "$_nextVersionHeader\n\n$_versionHeaderPrefix$version - $dateStr"));
  }

  void _update(String content) {
    _content = Future.value(content);
  }

  Future<String> _load() async {
    final res = await fs.readString(_filename);
    if (!_validate(res)) {
      throw Exception("CHANGELOG.md has unknown structure");
    }

    return res;
  }

  bool _validate(String content) {
    return content.startsWith(_nextVersionHeader);
  }
}
