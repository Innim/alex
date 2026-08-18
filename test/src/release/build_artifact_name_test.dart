import 'package:alex/src/exception/run_exception.dart';
import 'package:alex/src/release/build_artifact_name.dart';
import 'package:test/test.dart';
import 'package:version/version.dart';

void main() {
  group('forVersion', () {
    test('should build a name by the pattern', () {
      expect(
        BuildArtifactName.forVersion('sundry', Version.parse('0.1.2+3'), 'ipa'),
        'sundry_v0.1.2_3.ipa',
      );
      expect(
        BuildArtifactName.forVersion(
            'my_app', Version.parse('10.20.30+456'), 'aab'),
        'my_app_v10.20.30_456.aab',
      );
    });

    test('should ignore a pre release suffix', () {
      expect(
        BuildArtifactName.forVersion(
            'sundry', Version.parse('1.0.0-beta+7'), 'aab'),
        'sundry_v1.0.0_7.aab',
      );
    });

    test('should sanitize a name', () {
      expect(
        BuildArtifactName.forVersion(
            'My Super App!', Version.parse('1.0.0+1'), 'ipa'),
        'My_Super_App_v1.0.0_1.ipa',
      );
    });

    test('should fail if there is no build number', () {
      expect(
        () => BuildArtifactName.forVersion(
            'sundry', Version.parse('1.0.0'), 'ipa'),
        throwsA(isA<RunException>()),
      );
    });
  });

  group('sanitizeName', () {
    test('should keep a valid name as is', () {
      expect(BuildArtifactName.sanitizeName('sundry'), 'sundry');
      expect(BuildArtifactName.sanitizeName('my_app-2.0'), 'my_app-2.0');
    });

    test('should replace invalid characters with an underscore', () {
      expect(BuildArtifactName.sanitizeName('Приложение App'), 'App');
      expect(BuildArtifactName.sanitizeName('app:name'), 'app_name');
      expect(BuildArtifactName.sanitizeName(r'a/b\c'), 'a_b_c');
      expect(BuildArtifactName.sanitizeName('some app'), 'some_app');
    });

    test('should collapse repeated underscores', () {
      expect(BuildArtifactName.sanitizeName('some   app'), 'some_app');
      expect(BuildArtifactName.sanitizeName('a _ b'), 'a_b');
    });

    test('should trim separators at the edges', () {
      expect(BuildArtifactName.sanitizeName('  app  '), 'app');
      expect(BuildArtifactName.sanitizeName('.app.'), 'app');
      expect(BuildArtifactName.sanitizeName('--app__'), 'app');
    });

    test('should fail if nothing is left', () {
      expect(() => BuildArtifactName.sanitizeName(''),
          throwsA(isA<RunException>()));
      expect(() => BuildArtifactName.sanitizeName('...'),
          throwsA(isA<RunException>()));
      expect(() => BuildArtifactName.sanitizeName('Приложение'),
          throwsA(isA<RunException>()));
    });
  });
}
