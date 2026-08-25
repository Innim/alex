import 'package:alex/runner/alex_command.dart';
import 'package:args/command_runner.dart';
import 'package:test/test.dart';

void main() {
  group('fullName', () {
    test('should be the name for a top level command', () {
      final command = _Cmd('info');
      _runner([command]);

      expect(command.fullName, 'info');
    });

    test('should contain all the parent commands', () {
      final command = _Cmd('check');
      _runner([
        _Group('code', [command]),
      ]);

      expect(command.fullName, 'code check');
    });

    test('should contain all the levels of nesting', () {
      final command = _Cmd('third');
      _runner([
        _Group('first', [
          _Group('second', [command]),
        ]),
      ]);

      expect(command.fullName, 'first second third');
    });
  });
}

CommandRunner<int> _runner(List<AlexCommand> commands) {
  final runner = CommandRunner<int>('alex', 'Test runner.');
  commands.forEach(runner.addCommand);
  return runner;
}

class _Cmd extends AlexCommand {
  _Cmd(String name) : super(name, 'Some command.');

  @override
  Future<int> doRun() async => 0;
}

class _Group extends AlexCommand {
  _Group(String name, List<AlexCommand> subcommands)
      : super(name, 'Some group.') {
    subcommands.forEach(addSubcommand);
  }

  @override
  Future<int> doRun() async => 0;
}
