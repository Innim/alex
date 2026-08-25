import 'package:alex/runner/alex_command.dart';
import 'package:alex/src/agents/command_index.dart';
import 'package:alex/src/agents/guide_renderer.dart';
import 'package:args/command_runner.dart';
import 'package:test/test.dart';

void main() {
  group('build()', () {
    test('should build a tree of commands', () {
      final index = CommandIndex.build(_runner([
        _Group('code', 'Work with code', [
          _Cmd('gen', 'Run code generation.'),
        ]),
      ]));

      expect(index.commands.length, 1);

      final group = index.commands.single;
      expect(group.path, 'code');
      expect(group.isGroup, true);
      expect(group.subcommands.single.path, 'code gen');
      expect(index.runnable.map((c) => c.path), ['code gen']);
    });

    test('should not duplicate a command by its aliases', () {
      final index = CommandIndex.build(_runner([
        _Cmd('check', 'Check something.', aliases: ['c', 'validate']),
      ]));

      expect(index.commands.length, 1);
      expect(index.commands.single.aliases, ['c', 'validate']);
    });

    test('should skip the built-in help command', () {
      final index = CommandIndex.build(_runner([_Cmd('gen', 'Generate.')]));

      expect(index.commands.map((c) => c.path), ['gen']);
    });

    test('should use the first line of the description as a summary', () {
      final index = CommandIndex.build(_runner([
        _Cmd('gen', 'Generate code.\n\nSome long details.\nAnd more.'),
      ]));

      expect(index.commands.single.summary, 'Generate code.');
    });

    test('should skip common and hidden options', () {
      final command = _Cmd('gen', 'Generate.');
      command.argParser
        ..addFlag('secret', hide: true)
        ..addFlag('force', help: 'Force it.');

      final index = CommandIndex.build(_runner([command]));

      expect(index.commands.single.options.map((o) => o.name), ['force']);
    });

    test('should mark a command with the format option as json', () {
      final withJson = _Cmd('gen', 'Generate.')..argParser.addFormatOption();

      final index =
          CommandIndex.build(_runner([withJson, _Cmd('other', 'Other.')]));

      expect(index.commands.first.supportsJson, true);
      expect(index.commands.last.supportsJson, false);
    });

    test('should keep the interactive flag and the exit codes', () {
      final index = CommandIndex.build(_runner([
        _Cmd('finish', 'Finish.',
            interactive: true, codes: const {10: 'no issue id'}),
      ]));

      final command = index.commands.single;
      expect(command.isInteractive, true);
      expect(command.exitCodes, const {10: 'no issue id'});
    });

    test('should not report false as a default value of a flag', () {
      final command = _Cmd('gen', 'Generate.');
      command.argParser
        ..addFlag('force', help: 'Force it.')
        ..addFlag('safe', help: 'Be safe.', defaultsTo: true);

      final index = CommandIndex.build(_runner([command]));
      final options = index.commands.single.options;

      expect(options.first.defaultValue, isNull);
      expect(options.last.defaultValue, 'true');
    });
  });

  group('filter()', () {
    test('should return the subtree by a path', () {
      final index = CommandIndex.build(_runner([
        _Group('l10n', 'Localization', [
          _Cmd('extract', 'Extract.'),
          _Cmd('generate', 'Generate.'),
        ]),
        _Cmd('gen', 'Generate code.'),
      ]));

      final filtered = index.filter(['l10n'])!;

      expect(filtered.runnable.map((c) => c.path),
          ['l10n extract', 'l10n generate']);
    });

    test('should return a single command by a full path', () {
      final index = CommandIndex.build(_runner([
        _Group('l10n', 'Localization', [_Cmd('extract', 'Extract.')]),
      ]));

      final filtered = index.filter(['l10n', 'extract'])!;

      expect(filtered.runnable.single.path, 'l10n extract');
    });

    test('should find a command by an alias', () {
      final index = CommandIndex.build(_runner([
        _Cmd('check', 'Check.', aliases: ['validate']),
      ]));

      expect(index.filter(['validate'])!.runnable.single.path, 'check');
    });

    test('should return null for an unknown path', () {
      final index = CommandIndex.build(_runner([_Cmd('gen', 'Generate.')]));

      expect(index.filter(['unknown']), isNull);
      expect(index.filter(['gen', 'unknown']), isNull);
    });

    test('should return the same index for an empty path', () {
      final index = CommandIndex.build(_runner([_Cmd('gen', 'Generate.')]));

      expect(index.filter(const [])!.runnable.length, 1);
    });
  });

  group('GuideRenderer.render()', () {
    test('should render commands with marks and exit codes', () {
      final withJson =
          _Cmd('check', 'Check something.', codes: const {10: 'checks failed'})
            ..argParser.addFormatOption();

      final index = CommandIndex.build(_runner([
        withJson,
        _Cmd('finish', 'Finish something.', interactive: true),
      ]));

      final res = GuideRenderer.render(index, version: '1.2.3');

      expect(res, startsWith('# alex 1.2.3'));
      expect(res, contains('### alex check [JSON]'));
      expect(res, contains('Exit codes: `10` - checks failed.'));
      expect(res, contains('### alex finish [INTERACTIVE]'));
    });

    test('should not render a group as a command', () {
      final index = CommandIndex.build(_runner([
        _Group('code', 'Work with code', [_Cmd('gen', 'Generate.')]),
      ]));

      final res = GuideRenderer.render(index, version: '1.0.0');

      expect(res, contains('### alex code gen'));
      expect(res, isNot(contains('### alex code\n')));
    });
  });
}

CommandRunner<int> _runner(List<AlexCommand> commands) {
  final runner = CommandRunner<int>('alex', 'Test runner.');
  commands.forEach(runner.addCommand);
  return runner;
}

class _Cmd extends AlexCommand {
  final bool interactive;
  final Map<int, String> codes;

  _Cmd(
    String name,
    String description, {
    List<String> aliases = const [],
    this.interactive = false,
    this.codes = const {},
  }) : super(name, description, aliases);

  @override
  bool get isInteractive => interactive;

  @override
  Map<int, String> get exitCodes => codes;

  @override
  Future<int> doRun() async => 0;
}

class _Group extends AlexCommand {
  _Group(String name, String description, List<AlexCommand> subcommands)
      : super(name, description) {
    subcommands.forEach(addSubcommand);
  }

  @override
  Future<int> doRun() async => 0;
}
