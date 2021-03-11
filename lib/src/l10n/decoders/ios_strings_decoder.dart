/// Decoder for .strings iOS localization files.
class IosStringsDecoder {
  static final _keyValueStrRegEx = RegExp('"?(.*?)"?[ ]*=[ ]*"(.*)"',
      unicode: true, caseSensitive: false, multiLine: false);

  const IosStringsDecoder();

  Map<String, String> decode(String source) {
    final data = <String, String>{};
    for (final line in source.split('\n').map((e) => e.trim())) {
      if (line.isNotEmpty) {
        final matches = _keyValueStrRegEx.allMatches(line);
        if (matches.isNotEmpty) {
          final match = matches.first;
          final key = match.group(1);
          final value = match.group(2);

          data[key] = value;
        }
      }
    }

    return data;
  }
}
