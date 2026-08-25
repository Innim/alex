import 'package:list_ext/list_ext.dart';
import 'package:path/path.dart' as p;

/// Parser of an output of a `flutter build` command.
abstract class BuildOutput {
  static const _artifactLineMarker = '✓ Built ';

  /// `✓ Built <path> (<size>)` for Android
  /// and `✓ Built IPA to <path> (<size>)` for iOS.
  static final _artifactPath = RegExp(r'✓ Built (?:.*? to )?(.+?) \(');

  /// Returns a line of the [output] which reports a path of a build artifact.
  ///
  /// A build can print more than one such line — for example
  /// `flutter build ipa` reports both the Xcode archive and the IPA itself:
  ///
  /// ```
  /// ✓ Built build/ios/archive/Runner.xcarchive (202.3MB)
  /// ✓ Built IPA to build/ios/ipa (24.4MB)
  /// ```
  ///
  /// So a line with a path inside the [outputDirPath] is preferred,
  /// and the last of the printed lines is used as a fallback.
  ///
  /// Returns `null` if the [output] contains no such line.
  static String? getArtifactLine(String? output, String outputDirPath) {
    final lines = output
            ?.split('\n')
            .where((line) => line.contains(_artifactLineMarker))
            .map((line) => line.trim())
            .toList() ??
        const <String>[];

    if (lines.isEmpty) return null;

    return lines.reversed.firstWhereOrNull((line) {
          final path = parseArtifactPath(line);
          return path != null && isInDir(path, outputDirPath);
        }) ??
        lines.last;
  }

  /// Returns an absolute artifact path reported by the [artifactLine].
  ///
  /// Returns `null` if the line has an unknown format.
  static String? parseArtifactPath(String artifactLine) {
    final match = _artifactPath.firstMatch(artifactLine);
    return match != null ? p.absolute(match.group(1)!.trim()) : null;
  }

  /// Returns `true` if the [path] is the [dirPath] itself
  /// or is located inside it.
  static bool isInDir(String path, String dirPath) {
    final dir = p.absolute(dirPath);
    final target = p.absolute(path);
    return p.equals(target, dir) || p.isWithin(dir, target);
  }
}
