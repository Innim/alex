/// Block of a generated content inside a file that is edited by a human too.
///
/// The block is marked with [beginMarker] and [endMarker], so it can be
/// updated without touching anything else in the file.
class ManagedBlock {
  static const beginMarker = '<!-- alex:begin -->';
  static const endMarker = '<!-- alex:end -->';

  const ManagedBlock._();

  /// Returns the content of the block in the [content]
  /// or `null` if there is no block.
  ///
  /// Throws [FormatException] if the markers are broken.
  static String? extract(String content) {
    final range = _range(content);
    if (range == null) return null;

    return content.substring(range.contentStart, range.contentEnd).trim();
  }

  /// Returns `true` if the block in the [content] is the same as [body].
  static bool isUpToDate(String content, String body) =>
      extract(content) == body.trim();

  /// Returns the [content] with the block replaced by [body].
  ///
  /// If there is no block yet - it will be added at the end of the content.
  ///
  /// Throws [FormatException] if the markers are broken.
  static String apply(String content, String body) {
    final block = '$beginMarker\n${body.trim()}\n$endMarker';
    final range = _range(content);

    if (range == null) {
      if (content.trim().isEmpty) return '$block\n';
      return '${content.trimRight()}\n\n$block\n';
    }

    return content.substring(0, range.start) +
        block +
        content.substring(range.end);
  }

  static _BlockRange? _range(String content) {
    final start = content.indexOf(beginMarker);
    final end = content.indexOf(endMarker);

    if (start == -1 && end == -1) return null;

    if (start == -1) {
      throw const FormatException(
          'There is a closing marker of the alex block, but no opening one');
    }

    if (end == -1) {
      throw const FormatException(
          'There is an opening marker of the alex block, but no closing one');
    }

    if (end < start) {
      throw const FormatException(
          'The closing marker of the alex block is before the opening one');
    }

    if (content.indexOf(beginMarker, start + beginMarker.length) != -1 ||
        content.indexOf(endMarker, end + endMarker.length) != -1) {
      throw const FormatException(
          'There is more than one alex marker of the same type in the file');
    }

    return _BlockRange(
      start: start,
      contentStart: start + beginMarker.length,
      contentEnd: end,
      end: end + endMarker.length,
    );
  }
}

class _BlockRange {
  final int start;
  final int contentStart;
  final int contentEnd;
  final int end;

  const _BlockRange({
    required this.start,
    required this.contentStart,
    required this.contentEnd,
    required this.end,
  });
}
