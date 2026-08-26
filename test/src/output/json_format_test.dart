import 'package:alex/src/output/json_format.dart';
import 'package:test/test.dart';

void main() {
  group('isJsonFormatRequested()', () {
    test('should detect the option written through the equals sign', () {
      expect(isJsonFormatRequested(['code', 'check', '--format=json']), true);
    });

    test('should detect the option written with a space', () {
      expect(isJsonFormatRequested(['info', '--format', 'json']), true);
    });

    test('should return false for another format', () {
      expect(isJsonFormatRequested(['info', '--format=text']), false);
      expect(isJsonFormatRequested(['info', '--format', 'text']), false);
    });

    test('should return false if there is no option', () {
      expect(isJsonFormatRequested(['code', 'check']), false);
      expect(isJsonFormatRequested(const []), false);
    });

    test('should not fail if the option has no value', () {
      expect(isJsonFormatRequested(['info', '--format']), false);
    });
  });

  group('commandNameFromArgs()', () {
    test('should return the command with all its parents', () {
      expect(commandNameFromArgs(['code', 'check', '--format=json']),
          'code check');
    });

    test('should return the command without options', () {
      expect(commandNameFromArgs(['info']), 'info');
    });

    test('should stop on the first option', () {
      expect(commandNameFromArgs(['l10n', 'check', '-l', 'ru']), 'l10n check');
    });

    test('should return empty string if there is no command', () {
      expect(commandNameFromArgs(['--version']), '');
      expect(commandNameFromArgs(const []), '');
    });
  });
}
