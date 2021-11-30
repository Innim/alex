import 'dart:io';

extension Utf16FileExtension on File {
  Future<String> readAsUft16LEString() async {
    final bytes = <int>[];
    await for (final chunk in openRead()) {
      bytes.addAll(chunk);
    }

    final d = Utf16LEDecoder(bytes);
    return String.fromCharCodes(d.decode());
  }

  Future<bool> get hasUtf16leBom async {
    final bytes = <int>[];

    await for (final chunk in openRead(0, 2)) {
      bytes.addAll(chunk);
    }

    return _hasUtf16LEBom(bytes);
  }
}

const _unicodeUtfBomLo = 0xff;
const _unicodeUtfBomHi = 0xfe;

/// Identifies whether a List of bytes starts (based on offset) with a
/// little-endian byte-order marker (BOM).
bool _hasUtf16LEBom(List<int> bytes, {int offset = 0, int? length}) {
  final end = length != null ? offset + length : bytes.length;
  return (offset + 2) <= end &&
      bytes[offset] == _unicodeUtfBomLo &&
      bytes[offset + 1] == _unicodeUtfBomHi;
}

class Utf16LEDecoder {
  final List<int> bytes;

  Utf16LEDecoder(this.bytes);

  Iterable<int> decode() sync* {
    final length = bytes.length;
    var start = 0;
    if (_hasUtf16LEBom(bytes, length: length)) {
      start += 2;
    }

    for (var index = start; index < length; index += 2) {
      final lo = bytes[index];
      final hi = bytes[index + 1];

      yield (hi << 8) + lo;
    }
  }
}
