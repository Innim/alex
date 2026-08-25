import 'package:alex/src/exception/run_exception.dart';
import 'package:version/version.dart';

/// A part of the version to increment.
enum VersionIncrement {
  /// Increments a patch number: `1.2.3` -> `1.2.4`.
  patch,

  /// Increments a minor number and resets a patch: `1.2.3` -> `1.3.0`.
  minor,

  /// Increments a major number and resets minor and patch:
  /// `1.2.3` -> `2.0.0`.
  major;

  /// Names of all values, e.g. to print in a help or an error message.
  static String get namesList => values.map((e) => e.name).join(', ');

  /// Returns a value by its [name].
  ///
  /// Throws a [RunException] if there is no value with such a name.
  static VersionIncrement byName(String name) {
    final needle = name.trim().toLowerCase();
    for (final value in values) {
      if (value.name == needle) return value;
    }

    throw RunException.err(
        'Unknown version part <$name>. Allowed values: $namesList.');
  }

  /// Returns the [version] with the incremented part.
  ///
  /// A build number is incremented only if [incrementBuild] is `true`,
  /// otherwise it's kept as is.
  /// A pre-release suffix is always kept as is.
  Version apply(Version version, {bool incrementBuild = false}) {
    final String build;
    if (incrementBuild) {
      final buildNumber = int.tryParse(version.build);
      if (buildNumber == null) {
        throw RunException.err('Version "$version" has no valid build number, '
            "so the build number can't be incremented.");
      }
      build = '${buildNumber + 1}';
    } else {
      build = version.build;
    }

    final preRelease = version.preRelease;

    switch (this) {
      case VersionIncrement.patch:
        return Version(version.major, version.minor, version.patch + 1,
            preRelease: preRelease, build: build);
      case VersionIncrement.minor:
        return Version(version.major, version.minor + 1, 0,
            preRelease: preRelease, build: build);
      case VersionIncrement.major:
        return Version(version.major + 1, 0, 0,
            preRelease: preRelease, build: build);
    }
  }
}
