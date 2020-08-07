import 'package:alex/commands/hello_world.dart';
import 'package:alex/commands/l10n/l10n_command.dart';
import 'package:alex/commands/release/release_command.dart';
import 'package:alex/runner/alex_command.dart';
import 'package:args/command_runner.dart';

class AlexCommandRunner extends CommandRunner<int> {
  AlexCommandRunner() : super('alex', 'A simple command-line application.') {
    <AlexCommand>[HelloWorldCommand(), ReleaseCommand(), L10nCommand()]
        .forEach(addCommand);
  }
}
