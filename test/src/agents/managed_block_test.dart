import 'package:alex/src/agents/managed_block.dart';
import 'package:alex/src/agents/project_facts.dart';
import 'package:test/test.dart';

const _begin = ManagedBlock.beginMarker;
const _end = ManagedBlock.endMarker;

void main() {
  group('apply()', () {
    test('should add a block to an empty content', () {
      final res = ManagedBlock.apply('', 'Body.');

      expect(res, '$_begin\nBody.\n$_end\n');
    });

    test('should append a block and keep the existing content', () {
      const content = '# Title\n\nSome human text.\n';

      final res = ManagedBlock.apply(content, 'Body.');

      expect(res, '# Title\n\nSome human text.\n\n$_begin\nBody.\n$_end\n');
    });

    test('should replace the block and keep everything around it', () {
      const content = 'Before.\n\n'
          '$_begin\nOld body.\n$_end\n\n'
          'After.\n';

      final res = ManagedBlock.apply(content, 'New body.');

      expect(res, 'Before.\n\n$_begin\nNew body.\n$_end\n\nAfter.\n');
    });

    test('should not change the content if the block is the same', () {
      final content = ManagedBlock.apply('Before.\n', 'Body.');

      expect(ManagedBlock.apply(content, 'Body.'), content);
    });

    test('should throw if there is no opening marker', () {
      expect(() => ManagedBlock.apply('Text.\n$_end\n', 'Body.'),
          throwsFormatException);
    });

    test('should throw if there is no closing marker', () {
      expect(() => ManagedBlock.apply('$_begin\nText.\n', 'Body.'),
          throwsFormatException);
    });

    test('should throw if the markers are in the wrong order', () {
      expect(() => ManagedBlock.apply('$_end\nText.\n$_begin\n', 'Body.'),
          throwsFormatException);
    });

    test('should throw if there is more than one block', () {
      const content = '$_begin\nOne.\n$_end\n$_begin\nTwo.\n$_end\n';

      expect(() => ManagedBlock.apply(content, 'Body.'), throwsFormatException);
    });
  });

  group('extract()', () {
    test('should return the body of the block', () {
      final content = ManagedBlock.apply('Before.', 'Body.\nSecond line.');

      expect(ManagedBlock.extract(content), 'Body.\nSecond line.');
    });

    test('should return null if there is no block', () {
      expect(ManagedBlock.extract('Just text.'), isNull);
    });
  });

  group('isUpToDate()', () {
    test('should return true for the same body', () {
      final content = ManagedBlock.apply('Before.', 'Body.');

      expect(ManagedBlock.isUpToDate(content, 'Body.'), true);
      expect(ManagedBlock.isUpToDate(content, 'Other body.'), false);
    });

    test('should return false if there is no block', () {
      expect(ManagedBlock.isUpToDate('Just text.', 'Body.'), false);
    });
  });

  group('ProjectFacts.parseLocales()', () {
    test('should return sorted locales of the matched files', () {
      final res = ProjectFacts.parseLocales(
        const ['intl_ru.arb', 'intl_en.arb', 'intl_pt_BR.arb'],
        'intl_{locale}.arb',
      );

      expect(res, ['en', 'pt_BR', 'ru']);
    });

    test('should skip files that do not match the pattern', () {
      final res = ProjectFacts.parseLocales(
        const [
          'intl_en.arb',
          'messages_en.dart',
          'intl_en.arb.bak',
          'l10n.dart'
        ],
        'intl_{locale}.arb',
      );

      expect(res, ['en']);
    });

    test('should support a custom pattern', () {
      final res = ProjectFacts.parseLocales(
        const ['app_en.arb', 'app_ru.arb'],
        'app_{locale}.arb',
      );

      expect(res, ['en', 'ru']);
    });
  });
}
