import 'package:alex/src/l10n/validators/require_latin_validator.dart';
import 'package:test/test.dart';

void main() {
  group('validate()', () {
    test('should return true for string with only latin characters', () {
      final validator = RequireLatinValidator();

      expect(validator.validate('Hello'), true);
    });

    test('should return false for string with cyrillic character', () {
      final validator = RequireLatinValidator();

      expect(validator.validate('Привет'), false);
    });

    test('should return true for string with numbers', () {
      final validator = RequireLatinValidator();

      expect(validator.validate('1 / 5 notes'), true);
    });

    test('should return true for string with parameters', () {
      final validator = RequireLatinValidator();

      expect(validator.validate('Total: {sum}'), true);
    });

    test('should return true for string with old format parameters', () {
      final validator = RequireLatinValidator();

      expect(validator.validate(r'Code: $code'), true);
    });

    test('should return true for string with special symbols', () {
      final validator = RequireLatinValidator();

      expect(
        validator.validate('- {sum}, + {sum}, {currency} / {period}'),
        true,
      );
    });

    test('should return true for string with zero width space (U+200B)', () {
      final validator = RequireLatinValidator();

      expect(validator.validate('Var 6e ​​manad'), true);
    });

    test('should return true for string with new lines', () {
      final validator = RequireLatinValidator();

      expect(validator.validate(r'Day\nWeekday'), true);
    });

    test('should return true for string with quotes', () {
      final validator = RequireLatinValidator();

      expect(validator.validate('Tap "Allow" button'), true);
    });

    test('should return true for string with single quotes', () {
      final validator = RequireLatinValidator();

      expect(validator.validate("annullare l'operazione or l’import"), true);
    });

    test('should return true for string with punctuation marks', () {
      final validator = RequireLatinValidator();

      expect(
        validator.validate(
          "- Hello, John! How are you? Listen: I have... So; ¿Quiere ¡Recordatorio "
          "Start date – End date. cancel·lar",
        ),
        true,
      );
    });

    test('should return true for special latin characters', () {
      final validator = RequireLatinValidator();

      expect(
        validator.validate(
          'Dòlar Àfrica albanès Gràfics Relaxació Introduïu bielorús kenyà '
          'ucraïnès Xíling més Freqüència Adreça Bermudský Tālā Správa '
          'Ázerbájdžánský měně svůj přepočítán Kalkulačka ještě Maďarský '
          'Keňský Ohodnoťte mærke Caymanøerne indgående Einkäufe Löschen '
          'Regelmäßige año icônes Intérêt Noël Złoty îles Mađarska piće '
          'időszak működéséhez più Stai Così Dzień kategorię usunąć bieżące '
          'Wyjść Wyjdź não transações câmbio sterlină ieșire Finanțe '
          'Educaţie podľa Nezahŕňať değiştirildi hesaplandı işlemler İçecek '
          'sơ lại Tiền Đến Chuyển nhận đổi mỗi Xuất khoản Chọn Số Đồng dễ '
          'được dịch của được giờ gửi một sắm lần chỉ dữ mục từ thức bằng '
          'đẹp đặt viện dưới khỏe khẩu quỹ vẫn nghĩa nhở sẽ tự thẻ Kỳ tỷ',
        ),
        true,
      );
    });
  });
}
