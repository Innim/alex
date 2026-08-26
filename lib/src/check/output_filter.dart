/// Filter for a noisy output of `flutter`/`dart` commands.
///
/// Removes lines that are not related to the result of a check:
/// update banners, box-drawing borders, dependency resolution chatter,
/// deprecation notices of third-party plugins, progress indicators.
class OutputFilter {
  /// Patterns of the lines that are considered noise by default.
  static const defaultNoisePatterns = <String>[
    // Box drawing borders of flutter banners.
    r'^\s*[╔╚║╭╰│┌└├┤┬┴┼─═╞╡]',
    // Update banners.
    'A new version of Flutter is available',
    r'^\s*To update,? run:',
    r'^\s*flutter upgrade\s*$',
    'Changelog: https://',
    // Dependency resolution chatter.
    r'^\s*Running "flutter pub get"',
    r'^\s*Resolving dependencies',
    r'^\s*Got dependencies',
    r'^\s*Downloading ',
    // Third-party deprecations - not an issue of the project itself.
    'uses a deprecated version of the Android embedding',
    r'^\s*Note: .* uses (or overrides )?a deprecated API',
    r'^\s*Note: Recompile with -Xlint',
    r'^\s*warning: .* is deprecated',
    // Swift Package Manager chatter.
    'Swift Package Manager',
    r'^\s*swift-',
    // Locks and progress.
    'Waiting for another flutter command to release the startup lock',
    r'^\s*\d+% ',
  ];

  final List<RegExp> _patterns;

  OutputFilter({Iterable<String> extraPatterns = const []})
      : _patterns = [
          ...defaultNoisePatterns,
          ...extraPatterns,
        ].map(RegExp.new).toList(growable: false);

  /// Returns `true` if the [line] should be hidden.
  bool isNoise(String line) => _patterns.any((p) => p.hasMatch(line));

  /// Returns lines of the [output] without noise.
  ///
  /// Blank lines are collapsed: leading and trailing ones are removed,
  /// a sequence of blank lines is replaced with a single one.
  List<String> filterLines(String output) {
    final res = <String>[];
    var pendingBlank = false;

    for (final line in output.split('\n')) {
      final value = line.trimRight();

      if (isNoise(value)) continue;

      if (value.trim().isEmpty) {
        if (res.isNotEmpty) pendingBlank = true;
        continue;
      }

      if (pendingBlank) {
        res.add('');
        pendingBlank = false;
      }

      res.add(value);
    }

    return res;
  }

  /// Returns the [output] without noise.
  String filter(String output) => filterLines(output).join('\n');

  /// Returns not more than [maxLines] last lines of the [output] without noise.
  String filterTail(String output, {int maxLines = 30}) {
    final lines = filterLines(output);
    if (lines.length <= maxLines) return lines.join('\n');
    return [
      '... ${lines.length - maxLines} line(s) skipped ...',
      ...lines.sublist(lines.length - maxLines),
    ].join('\n');
  }
}
