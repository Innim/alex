/// Localization entry.
abstract class L10nEntry {
  const L10nEntry();

  factory L10nEntry.text(String text) => L10nTextEntry(text);
  factory L10nEntry.plural(
          {String zero,
          String one,
          String two,
          String few,
          String many,
          String other}) =>
      L10nPluralEntry(zero, one, two, few, many, other);

  factory L10nEntry.pluralFromMap(Map<String, String> valueByQuantity) =>
      L10nPluralEntry(
        valueByQuantity['zero'],
        valueByQuantity['one'],
        valueByQuantity['two'],
        valueByQuantity['few'],
        valueByQuantity['many'],
        valueByQuantity['other'],
      );
}

/// Simple localization entry with just text.
class L10nTextEntry extends L10nEntry {
  final String text;

  const L10nTextEntry(this.text);

  @override
  String toString() => 'L10nTextEntry(text: $text)';
}

/// Localization entry for plural string.
class L10nPluralEntry extends L10nEntry {
  final String zero;
  final String one;
  final String two;
  final String few;
  final String many;
  final String other;

  const L10nPluralEntry(
      this.zero, this.one, this.two, this.few, this.many, this.other);

  List<String> get codeAttributeNames =>
      ["zero", "one", "two", "few", "many", "other"];

  @override
  String toString() {
    return 'L10nPluralEntry(zero: $zero, one: $one, two: $two, few: $few, '
        'many: $many, other: $other)';
  }

  String operator [](String attributeName) {
    switch (attributeName) {
      case "zero":
        return zero;
      case "one":
        return one;
      case "two":
        return two;
      case "few":
        return few;
      case "many":
        return many;
      case "other":
        return other;
      default:
        return null;
    }
  }
}
