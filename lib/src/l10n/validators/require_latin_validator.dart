import 'package:alex/src/l10n/validators/l10n_validator.dart';

class RequireLatinValidator implements L10nValidator {
  static late final _pattern = RegExp(
    r'^[a-z0-9\s​​!¡<=>?¿()*+,\-–—’“”„”«»^_`·./:;@"#$%&\[\\\]{|}~'
    r"'àāáåäãăâậąấạảắầặằẫẩæßçčćďđèéěêëęẽềếểẹễệẻğïíîìịıỉĩİłľňñńòóöôőỏõổỗờồợởọơớốộøřŕšśșşťțţúùüůűủừửữứûụựưýỹỳỷżźž]+$",
    unicode: true,
    caseSensitive: false,
  );

  @override
  bool validate(String input) {
    return _pattern.hasMatch(input);
  }

  @override
  String getError(String value) {
    var pos = -1;
    String? failedChar;
    for (var i = 0; i < value.length; i++) {
      final char = value.substring(i, i + 1);
      if (!_pattern.hasMatch(char)) {
        failedChar = char;
        pos = i;
        break;
      }
    }

    final String symbolInfo;
    final String markedString;

    if (failedChar != null) {
      final unicodeCode = failedChar.codeUnitAt(0);
      final unicodeCodeFormatted =
          'U+${unicodeCode.toRadixString(16).toUpperCase()}';
      symbolInfo = '$failedChar ($unicodeCodeFormatted) at $pos is not allowed';
      markedString = value.replaceRange(pos, pos, '▶︎');
    } else {
      symbolInfo = 'failed to find invalid symbol, this may be a mistake';
      markedString = value;
    }

    return 'Only latin characters are allowed [$symbolInfo]: $markedString';
  }
}
