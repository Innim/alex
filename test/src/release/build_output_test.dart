import 'package:alex/src/release/build_output.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

const _androidOutputDir = 'build/app/outputs/bundle/release';
const _iosOutputDir = 'build/ios/ipa';

void main() {
  group('getArtifactLine', () {
    test('should return a line for android build', () {
      const output = "Running Gradle task 'bundleRelease'...\n"
          "Running Gradle task 'bundleRelease'... 51,4s\n"
          '✓ Built build/app/outputs/bundle/release/app-release.aab (27.1MB).\n';

      expect(BuildOutput.getArtifactLine(output, _androidOutputDir),
          '✓ Built build/app/outputs/bundle/release/app-release.aab (27.1MB).');
    });

    test('should return an ipa line if an archive is also reported', () {
      // Flutter reports the Xcode archive before the IPA itself.
      const output = 'Building com.example.app for device (ios-release)...\n'
          '✓ Built build/ios/archive/Runner.xcarchive (202.3MB)\n'
          'Building App Store IPA...\n'
          '✓ Built IPA to build/ios/ipa (24.4MB).\n';

      expect(BuildOutput.getArtifactLine(output, _iosOutputDir),
          '✓ Built IPA to build/ios/ipa (24.4MB).');
    });

    test(
        'should return a line with a path in the output dir '
        'regardless of its position', () {
      const output = '✓ Built IPA to build/ios/ipa (24.4MB).\n'
          '✓ Built build/ios/archive/Runner.xcarchive (202.3MB)\n';

      expect(BuildOutput.getArtifactLine(output, _iosOutputDir),
          '✓ Built IPA to build/ios/ipa (24.4MB).');
    });

    test('should return the last line if no one is in the output dir', () {
      const output = '✓ Built build/ios/archive/Runner.xcarchive (202.3MB)\n'
          '✓ Built build/ios/something_else (24.4MB).\n';

      expect(BuildOutput.getArtifactLine(output, _iosOutputDir),
          '✓ Built build/ios/something_else (24.4MB).');
    });

    test('should return null if there is no artifact line', () {
      expect(BuildOutput.getArtifactLine('Running Gradle task...\n', 'build'),
          isNull);
      expect(BuildOutput.getArtifactLine('', 'build'), isNull);
      expect(BuildOutput.getArtifactLine(null, 'build'), isNull);
    });
  });

  group('parseArtifactPath', () {
    test('should parse an android line', () {
      expect(
          BuildOutput.parseArtifactPath(
              '✓ Built build/app/outputs/bundle/release/app-release.aab (27.1MB).'),
          p.absolute('build/app/outputs/bundle/release/app-release.aab'));
    });

    test('should parse an ios line', () {
      expect(
          BuildOutput.parseArtifactPath(
              '✓ Built IPA to build/ios/ipa (24.4MB).'),
          p.absolute('build/ios/ipa'));
    });

    test('should return null for an unknown format', () {
      expect(BuildOutput.parseArtifactPath('✓ Built something'), isNull);
    });
  });

  group('isInDir', () {
    test('should return true for the dir itself', () {
      expect(BuildOutput.isInDir('build/ios/ipa', 'build/ios/ipa'), isTrue);
    });

    test('should return true for a file inside the dir', () {
      expect(BuildOutput.isInDir('build/ios/ipa/app.ipa', 'build/ios/ipa'),
          isTrue);
    });

    test('should return false for a path out of the dir', () {
      expect(
          BuildOutput.isInDir(
              'build/ios/archive/Runner.xcarchive', 'build/ios/ipa'),
          isFalse);
    });
  });
}
