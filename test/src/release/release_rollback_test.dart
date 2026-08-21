import 'package:alex/src/config.dart';
import 'package:alex/src/exception/run_exception.dart';
import 'package:alex/src/git/git.dart';
import 'package:alex/src/release/release_rollback.dart';
import 'package:test/test.dart';

const _develop = 'develop';
const _master = 'master';
const _version = '1.2.3';
const _releaseBranch = 'release/$_version';

void main() {
  late _FakeGit client;
  late GitCommands git;
  late _Logs logs;

  ReleaseRollback createRollback() => ReleaseRollback(
        git,
        info: logs.info.add,
        warning: logs.warning.add,
        error: logs.error.add,
        verbose: logs.verbose.add,
      );

  /// Creates a rollback with a saved state of a clean repository.
  ReleaseRollback startRollback() {
    client
      ..setResult('rev-parse $_develop', 'dev_base')
      ..setResult('rev-parse $_master', 'master_base')
      ..setResult('branch --list $_develop', '  $_develop')
      ..setResult('branch --list $_master', '  $_master');

    final rollback = createRollback()..start();
    client.commands.clear();
    return rollback;
  }

  setUp(() {
    client = _FakeGit(currentBranch: _develop);
    git = GitCommands(client, const AlexGitConfig());
    logs = _Logs();
  });

  group('start', () {
    test('saves current commits of develop and master', () {
      client
        ..setResult('rev-parse $_develop', 'dev_base')
        ..setResult('rev-parse $_master', 'master_base');

      final rollback = createRollback()..start();

      expect(client.commands,
          containsAll(<String>['rev-parse $_develop', 'rev-parse $_master']));
      expect(rollback.isArmed, isTrue);
    });

    test("doesn't fail if there is no master branch yet", () {
      client
        ..setResult('rev-parse $_develop', 'dev_base')
        ..setFailure('rev-parse $_master', const RunException.err('no branch'));

      expect(createRollback().start, returnsNormally);
    });
  });

  group('run', () {
    test('does nothing if it was not started', () {
      createRollback().run();

      expect(client.commands, isEmpty);
    });

    test('discards uncommitted changes and untracked files', () {
      startRollback().run();

      expect(client.commands, containsAllInOrder(['reset --hard', 'clean -fd']));
    });

    test("doesn't touch branches if there are no new commits", () {
      startRollback().run();

      expect(client.commands, isNot(contains('reset --hard dev_base')));
      expect(client.commands, isNot(contains('reset --hard master_base')));
      expect(client.commands.where((e) => e.startsWith('checkout ')), isEmpty);
    });

    test('restores develop to the state before the release', () {
      final rollback = startRollback();
      // Some commits were made in develop.
      client.setResult('rev-parse $_develop', 'dev_release');

      rollback.run();

      expect(client.commands, contains('reset --hard dev_base'));
    });

    test('restores master to the state before the release', () {
      final rollback = startRollback();
      // Release was merged in master.
      client.setResult('rev-parse $_master', 'master_release');

      rollback.run();

      expect(client.commands,
          containsAllInOrder(['checkout $_master', 'reset --hard master_base']));
    });

    test("doesn't restore a branch if its state was not saved", () {
      client
        ..setResult('rev-parse $_develop', 'dev_base')
        ..setFailure('rev-parse $_master', const RunException.err('no branch'));

      final rollback = createRollback()..start();
      client.commands.clear();

      client
        ..setResult('rev-parse $_master', 'master_release')
        ..setResult('branch --list $_master', '  $_master');

      rollback.run();

      expect(client.commands, isNot(contains('checkout $_master')));
      expect(client.commands.where((e) => e.startsWith('reset --hard ')),
          isEmpty);
    });

    test('deletes created release branch', () {
      final rollback = startRollback()..setReleaseBranch(_releaseBranch);
      client
        ..currentBranch = _releaseBranch
        ..setResult('branch --list $_releaseBranch', '* $_releaseBranch');

      rollback.run();

      expect(client.commands, contains('branch -D $_releaseBranch'));
      // Branch can't be deleted while it's checked out.
      expect(client.commands.indexOf('checkout $_develop'),
          lessThan(client.commands.indexOf('branch -D $_releaseBranch')));
    });

    test("doesn't delete release branch if it was not created", () {
      startRollback()
        ..setReleaseBranch(_releaseBranch)
        ..run();

      expect(client.commands, isNot(contains('branch -D $_releaseBranch')));
    });

    test("doesn't delete release branch which existed before the release", () {
      // Release start fails in this case, but the branch is not ours.
      client.setResult('branch --list $_releaseBranch', '  $_releaseBranch');

      final rollback = startRollback()..setReleaseBranch(_releaseBranch);
      client.currentBranch = _develop;

      rollback.run();

      expect(client.commands, isNot(contains('branch -D $_releaseBranch')));
    });

    test("doesn't delete release branch if its check failed", () {
      client.setFailure(
          'branch --list $_releaseBranch', const RunException.err('failed'));

      startRollback()
        ..setReleaseBranch(_releaseBranch)
        ..run();

      expect(client.commands, isNot(contains('branch -D $_releaseBranch')));
    });

    test('deletes created tag', () {
      final rollback = startRollback()..setTag(_version);
      client.setResult('tag -l $_version', _version);

      rollback.run();

      expect(client.commands, contains('tag -d $_version'));
    });

    test("doesn't delete tag if it was not set", () {
      startRollback()
        ..setTag(_version)
        ..run();

      expect(client.commands, isNot(contains('tag -d $_version')));
    });

    test("doesn't delete tag which existed before the release", () {
      // Release finish fails in this case, but the tag is not ours.
      client.setResult('tag -l $_version', _version);

      startRollback()
        ..setTag(_version)
        ..run();

      expect(client.commands, isNot(contains('tag -d $_version')));
    });

    test('aborts merge in progress', () {
      final rollback = startRollback();
      client.setFailure(
          'merge HEAD', const RunException.withCode(128, 'MERGE_HEAD exists'));

      rollback.run();

      expect(client.commands, contains('merge --abort'));
      // Merge should be aborted before the working tree is reset.
      expect(client.commands.indexOf('merge --abort'),
          lessThan(client.commands.indexOf('reset --hard')));
    });

    test("doesn't abort merge if there is no merge in progress", () {
      startRollback().run();

      expect(client.commands, isNot(contains('merge --abort')));
    });

    test('returns to develop at the end', () {
      final rollback = startRollback()..setReleaseBranch(_releaseBranch);
      client
        ..currentBranch = _releaseBranch
        ..setResult('branch --list $_releaseBranch', '* $_releaseBranch');

      rollback.run();

      expect(client.currentBranch, _develop);
    });

    test('reverts the whole release in the right order', () {
      final rollback = startRollback()
        ..setReleaseBranch(_releaseBranch)
        ..setTag(_version);
      client
        ..currentBranch = _releaseBranch
        ..setResult('rev-parse $_develop', 'dev_release')
        ..setResult('rev-parse $_master', 'master_release')
        ..setResult('branch --list $_releaseBranch', '* $_releaseBranch')
        ..setResult('tag -l $_version', _version);

      rollback.run();

      expect(
          client.commands,
          containsAllInOrder([
            'reset --hard',
            'clean -fd',
            'tag -d $_version',
            'checkout $_master',
            'reset --hard master_base',
            'checkout $_develop',
            'reset --hard dev_base',
            'branch -D $_releaseBranch',
          ]));
      expect(client.currentBranch, _develop);
      expect(logs.error, isEmpty);
    });

    test('can be run only once', () {
      final rollback = startRollback()..run();
      client.commands.clear();

      rollback
        ..run()
        ..run();

      expect(client.commands, isEmpty);
      expect(rollback.isArmed, isFalse);
    });
  });

  group('run when push is started', () {
    test("doesn't change repository", () {
      final rollback = startRollback()
        ..setReleaseBranch(_releaseBranch)
        ..setTag(_version)
        ..onPushStarted(_develop);
      client
        ..setResult('rev-parse $_develop', 'dev_release')
        ..setResult('rev-parse $_master', 'master_release')
        ..setResult('tag -l $_version', _version)
        ..commands.clear();

      rollback.run();

      expect(client.commands, isEmpty);
    });

    test('reports that release should be handled manually', () {
      startRollback()
        ..onPushStarted(_develop)
        ..run();

      expect(logs.warning.join('\n'), contains(_develop));
      expect(logs.warning.join('\n'), contains('manually'));
    });
  });

  group('run with a failed step', () {
    test('reports a failure if changes were not discarded', () {
      final rollback = startRollback();
      client.setFailure('reset --hard', const RunException.err('index.lock'));

      rollback.run();

      // Untracked files should be removed anyway.
      expect(client.commands, contains('clean -fd'));
      expect(logs.error, isNotEmpty);
      expect(logs.error.join('\n'), contains('git reset --hard dev_base'));
    });

    test('performs the rest of the steps', () {
      final rollback = startRollback()
        ..setReleaseBranch(_releaseBranch)
        ..setTag(_version);
      client
        ..setResult('tag -l $_version', _version)
        ..setFailure('tag -d $_version', const RunException.err('locked'))
        ..setResult('branch --list $_releaseBranch', '  $_releaseBranch');

      rollback.run();

      expect(client.commands, contains('branch -D $_releaseBranch'));
    });

    test('prints instructions for a manual cleanup', () {
      final rollback = startRollback()
        ..setReleaseBranch(_releaseBranch)
        ..setTag(_version);
      client
        ..setResult('tag -l $_version', _version)
        ..setFailure('tag -d $_version', const RunException.err('locked'));

      rollback.run();

      final errors = logs.error.join('\n');
      expect(errors, contains('git branch -D $_releaseBranch'));
      expect(errors, contains('git tag -d $_version'));
      expect(errors, contains('git reset --hard dev_base'));
      expect(errors, contains('git reset --hard master_base'));
    });
  });
}

/// Git client which records all the executed commands.
class _FakeGit extends Git {
  final commands = <String>[];
  final _results = <String, String>{};
  final _failures = <String, RunException>{};

  String currentBranch;

  _FakeGit({required this.currentBranch});

  void setResult(String command, String result) => _results[command] = result;

  void setFailure(String command, RunException exception) =>
      _failures[command] = exception;

  @override
  String execute(List<String> args, String desc, {bool printIfError = true}) {
    final command = args.join(' ');
    commands.add(command);

    final failure = _failures[command];
    if (failure != null) throw failure;

    if (args.first == 'checkout') {
      currentBranch = args[1];
      return '';
    }

    if (command == 'branch --show-current') return currentBranch;

    return _results[command] ?? '';
  }
}

class _Logs {
  final info = <String>[];
  final warning = <String>[];
  final error = <String>[];
  final verbose = <String>[];
}
