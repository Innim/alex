import 'package:alex/src/exception/run_exception.dart';
import 'package:alex/src/version_increment.dart';
import 'package:test/test.dart';
import 'package:version/version.dart';

void main() {
  group('byName', () {
    test('should return a value by its name', () {
      expect(VersionIncrement.byName('patch'), VersionIncrement.patch);
      expect(VersionIncrement.byName('minor'), VersionIncrement.minor);
      expect(VersionIncrement.byName('major'), VersionIncrement.major);
    });

    test('should ignore a case and spaces', () {
      expect(VersionIncrement.byName(' Major '), VersionIncrement.major);
    });

    test('should fail for an unknown value', () {
      expect(
          () => VersionIncrement.byName('build'), throwsA(isA<RunException>()));
    });
  });

  group('apply', () {
    test('should keep a build number by default', () {
      expect(VersionIncrement.patch.apply(Version.parse('1.2.3+4')).toString(),
          '1.2.4+4');
      expect(VersionIncrement.minor.apply(Version.parse('1.2.3+4')).toString(),
          '1.3.0+4');
      expect(VersionIncrement.major.apply(Version.parse('1.2.3+4')).toString(),
          '2.0.0+4');
    });

    test('should increment a build number if it is requested', () {
      expect(
          VersionIncrement.patch
              .apply(Version.parse('1.2.3+4'), incrementBuild: true)
              .toString(),
          '1.2.4+5');
      expect(
          VersionIncrement.minor
              .apply(Version.parse('1.2.3+4'), incrementBuild: true)
              .toString(),
          '1.3.0+5');
      expect(
          VersionIncrement.major
              .apply(Version.parse('1.2.3+4'), incrementBuild: true)
              .toString(),
          '2.0.0+5');
    });

    test('should keep a pre release', () {
      expect(
          VersionIncrement.minor
              .apply(Version.parse('1.2.3-beta+4'))
              .toString(),
          '1.3.0-beta+4');
    });

    test('should work for a version without a build number', () {
      expect(VersionIncrement.minor.apply(Version.parse('1.2.3')).toString(),
          '1.3.0');
    });

    test('should fail to increment an invalid build number', () {
      expect(
          () => VersionIncrement.patch
              .apply(Version.parse('1.2.3'), incrementBuild: true),
          throwsA(isA<RunException>()));
      expect(
          () => VersionIncrement.patch
              .apply(Version.parse('1.2.3+beta'), incrementBuild: true),
          throwsA(isA<RunException>()));
    });
  });
}
