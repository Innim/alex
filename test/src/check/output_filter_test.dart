import 'package:alex/src/check/output_filter.dart';
import 'package:test/test.dart';

void main() {
  group('filter()', () {
    test('should remove the flutter update banner', () {
      const output = '''
╔════════════════════════════════════════════════════════════════════════════╗
║ A new version of Flutter is available!                                     ║
║ To update, run: flutter upgrade                                            ║
╚════════════════════════════════════════════════════════════════════════════╝
Analyzing app...
No issues found!
''';

      final res = OutputFilter().filter(output);

      expect(res, 'Analyzing app...\nNo issues found!');
    });

    test('should keep meaningful lines', () {
      const output = '''
Analyzing app...
  error • The name 'Foo' isn't defined • lib/a.dart:1:1 • undefined_identifier
1 issue found.
''';

      final res = OutputFilter().filter(output);

      expect(res.split('\n').length, 3);
      expect(res, contains("The name 'Foo' isn't defined"));
    });

    test('should collapse blank lines', () {
      const output = '\n\nfirst\n\n\n\nsecond\n\n\n';

      final res = OutputFilter().filter(output);

      expect(res, 'first\n\nsecond');
    });

    test('should remove lines by extra patterns', () {
      const output = 'keep me\nsome_plugin: noisy line\nkeep me too';

      final res =
          OutputFilter(extraPatterns: const ['some_plugin']).filter(output);

      expect(res, 'keep me\nkeep me too');
    });

    test('should remove dependency resolution chatter', () {
      const output = '''
Resolving dependencies...
Got dependencies!
Running "flutter pub get" in app...
Build succeeded
''';

      final res = OutputFilter().filter(output);

      expect(res, 'Build succeeded');
    });
  });

  group('filterTail()', () {
    test('should return not more than maxLines lines', () {
      final output = List.generate(10, (i) => 'line $i').join('\n');

      final res = OutputFilter().filterTail(output, maxLines: 3);
      final lines = res.split('\n');

      expect(lines.length, 4);
      expect(lines.first, contains('7 line(s) skipped'));
      expect(lines.last, 'line 9');
    });

    test('should return all lines if there are less than maxLines', () {
      const output = 'line 1\nline 2';

      final res = OutputFilter().filterTail(output, maxLines: 10);

      expect(res, output);
    });
  });
}
