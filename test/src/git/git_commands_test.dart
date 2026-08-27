import 'package:alex/src/config.dart';
import 'package:alex/src/git/git.dart';
import 'package:test/test.dart';

void main() {
  group('getModifiedFiles()', () {
    test('should return paths without the status', () {
      final git = _commands(' M lib/a.dart\n?? lib/new.dart\nA  lib/b.dart');

      expect(git.getModifiedFiles(), [
        'lib/a.dart',
        'lib/new.dart',
        'lib/b.dart',
      ]);
    });

    test('should return an empty list if there are no changes', () {
      expect(_commands('').getModifiedFiles(), isEmpty);
    });

    test('should ask git for every untracked file if it is required', () {
      // Git collapses an untracked directory into a single entry by default,
      // so the files in it would not be listed.
      final git = _FakeGit('');

      GitCommands(git, const AlexGitConfig())
          .getModifiedFiles(allUntracked: true);

      expect(git.lastArgs, contains('--untracked-files=all'));
    });

    test('should not ask for every untracked file by default', () {
      final git = _FakeGit('');

      GitCommands(git, const AlexGitConfig()).getModifiedFiles();

      expect(git.lastArgs, isNot(contains('--untracked-files=all')));
    });
  });
}

GitCommands _commands(String output) =>
    GitCommands(_FakeGit(output), const AlexGitConfig());

class _FakeGit extends Git {
  final String output;

  /// Arguments of the last call.
  List<String> lastArgs = const [];

  _FakeGit(this.output);

  @override
  String execute(List<String> args, String desc, {bool printIfError = true}) {
    lastArgs = args;
    return output;
  }
}
