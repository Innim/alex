import 'package:alex/commands/hello_world.dart';
import 'package:alex/commands/release/start_release_command.dart';
import 'package:alex/runner/alex_command.dart';

/// Команда релизной сборки.
class ReleaseCommand extends AlexCommand {
  ReleaseCommand() : super('release', 'App release commands') {
    addSubcommand(StartReleaseCommand());
  }
}
