import 'package:alex/src/exception/run_exception.dart';
import 'package:alex/src/pub_spec.dart';
import 'package:test/test.dart';
import 'package:version/version.dart';

void main() {
  group('replaceVersion', () {
    test('should replace a version and keep the rest of the file', () {
      const content = 'name: demo\n'
          'description: A demo app.\n'
          'version: 1.2.3+4\n'
          '\n'
          'environment:\n'
          '  sdk: ">=3.0.0 <4.0.0"\n';

      expect(
        Spec.replaceVersion(content, Version.parse('1.3.0+4')),
        'name: demo\n'
        'description: A demo app.\n'
        'version: 1.3.0+4\n'
        '\n'
        'environment:\n'
        '  sdk: ">=3.0.0 <4.0.0"\n',
      );
    });

    test('should keep a comment of the version line', () {
      const content = 'name: demo\n'
          'version: 1.2.3+4 # do not forget to increment\n';

      expect(
        Spec.replaceVersion(content, Version.parse('2.0.0+4')),
        'name: demo\n'
        'version: 2.0.0+4 # do not forget to increment\n',
      );
    });

    test('should not touch a version of a dependency', () {
      const content = 'name: demo\n'
          'version: 1.2.3+4\n'
          'dependencies:\n'
          '  some_package:\n'
          '    version: 1.2.3+4\n';

      expect(
        Spec.replaceVersion(content, Version.parse('1.3.0+4')),
        'name: demo\n'
        'version: 1.3.0+4\n'
        'dependencies:\n'
        '  some_package:\n'
        '    version: 1.2.3+4\n',
      );
    });

    test('should fail if there is no version definition', () {
      const content = 'name: demo\n'
          'description: A demo app.\n';

      expect(() => Spec.replaceVersion(content, Version.parse('1.0.0+1')),
          throwsA(isA<RunException>()));
    });
  });

  group('versionOrNull', () {
    test('should return a version if it is defined', () {
      expect(Spec.byString('name: demo\nversion: 1.2.3+4\n').versionOrNull,
          Version.parse('1.2.3+4'));
    });

    test('should return null if there is no version', () {
      expect(Spec.byString('name: demo\n').versionOrNull, isNull);
    });
  });
}
