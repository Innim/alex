import 'package:alex/src/exception/run_exception.dart';
import 'package:version/version.dart';

/// Builder of a file name for a release build artifact.
///
/// Resulting name has the following format:
/// `<name>_v<major>.<minor>.<patch>_<build>.<extension>`,
/// for example `sundry_v0.1.2_3.ipa`.
abstract class BuildArtifactName {
  static final _invalidCharacters = RegExp('[^A-Za-z0-9._-]+');
  static final _leadingOrTrailingSeparators = RegExp(r'^[._-]+|[._-]+$');
  static final _repeatedUnderscores = RegExp('_{2,}');

  /// Returns a file name for the artifact of the [version] build.
  ///
  /// [name] is an application name, it will be sanitized
  /// with [sanitizeName].
  /// [extension] is an artifact file extension without a dot, e.g. `aab`.
  static String forVersion(String name, Version version, String extension) {
    final buildNumber = version.build;
    if (buildNumber.isEmpty) {
      throw RunException.err('Version "$version" has no build number, '
          "so a build artifact file name can't be defined.");
    }

    return '${sanitizeName(name)}'
        '_v${version.major}.${version.minor}.${version.patch}'
        '_$buildNumber.$extension';
  }

  /// Returns [name] cleaned up to be safely used as a part of a file name.
  ///
  /// All characters except latin letters, digits, `.`, `_` and `-`
  /// are replaced with `_`.
  static String sanitizeName(String name) {
    final res = name
        .trim()
        .replaceAll(_invalidCharacters, '_')
        .replaceAll(_repeatedUnderscores, '_')
        .replaceAll(_leadingOrTrailingSeparators, '');

    if (res.isEmpty) {
      throw RunException.err(
          'Application name "$name" can\'t be used in a file name. '
          'Define a valid name in the build.name section of the alex config.');
    }

    return res;
  }
}
