import 'package:alex/runner/alex_command.dart';
import 'package:alex/src/custom_commands/custom_command_config.dart';

/// Remove a custom command.
class RemoveCustomCommand extends AlexCommand {
  RemoveCustomCommand()
      : super('remove', 'Remove a custom command.', ['rm', 'delete']) {
    argParser.addOption(
      'name',
      abbr: 'n',
      help: 'Name of the command to remove',
      mandatory: true,
    );
  }

  @override
  Future<int> doRun() async {
    final name = argResults!['name'] as String;
    final config = CustomCommandsConfig.instance;

    if (!config.hasCommand(name)) {
      printError('Command not found: $name');
      return 1;
    }

    try {
      final removed = config.removeCommand(name);
      if (removed) {
        config.save();
        printInfo('Custom command removed: $name');
        printInfo('Config saved to: ${config.getOrCreateConfigPath()}');
        return 0;
      } else {
        printError('Failed to remove command: $name');
        return 1;
      }
    } catch (e) {
      printError('Failed to remove command: $e');
      return 1;
    }
  }
}
