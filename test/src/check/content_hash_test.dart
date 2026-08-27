import 'dart:convert';

import 'package:alex/src/check/content_hash.dart';
import 'package:test/test.dart';

void main() {
  group('contentHash()', () {
    test('should be the same for the same content', () {
      expect(contentHash(utf8.encode('some content')),
          contentHash(utf8.encode('some content')));
    });

    test('should differ for a different content', () {
      expect(contentHash(utf8.encode('some content')),
          isNot(contentHash(utf8.encode('other content'))));
    });

    test('should differ for the same length but a different content', () {
      // A generated file is often rewritten with the same length -
      // a value of the same size, an id, a version.
      expect(contentHash(utf8.encode("const version = '1.15.1';")),
          isNot(contentHash(utf8.encode("const version = '9.99.9';"))));
    });

    test('should differ for a content with the same bytes in another order',
        () {
      expect(contentHash(const [1, 2, 3]), isNot(contentHash(const [3, 2, 1])));
    });

    test('should work with an empty content', () {
      expect(contentHash(const []), isNotEmpty);
      expect(contentHash(const []), isNot(contentHash(const [0])));
    });
  });
}
