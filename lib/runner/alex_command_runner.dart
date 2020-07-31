import 'package:alex/commands/hello_world.dart';
import 'package:alex/commands/release/release_command.dart';
import 'package:alex/runner/alex_command.dart';
import 'package:args/command_runner.dart';

class AlexCommandRunner extends CommandRunner<int> {
  AlexCommandRunner() : super('alex', 'A simple command-line application.') {
    <AlexCommand>[HelloWorldCommand(), ReleaseCommand()].forEach(addCommand);
  }
}
