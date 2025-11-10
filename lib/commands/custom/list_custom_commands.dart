import 'package:alex/runner/alex_command.dart';
import 'package:alex/src/custom_commands/custom_command_config.dart';

/// List all custom commands.
class ListCustomCommandsCommand extends AlexCommand {
  ListCustomCommandsCommand()
      : super('list', 'List all registered custom commands.');

  @override
  Future<int> doRun() async {
    final config = CustomCommandsConfig.instance;

    if (config.commands.isEmpty) {
      printInfo('No custom commands registered.');
      printInfo('');
      printInfo('To add a custom command, use:');
      printInfo('  alex custom add');
      printInfo('');
      printInfo('Or edit the config file directly:');
      printInfo('  ${config.getOrCreateConfigPath()}');
      return 0;
    }

    printInfo('Custom commands (${config.commands.length}):');
    printInfo('');

    for (final cmd in config.commands) {
      printInfo('  ${cmd.name}');
      if (cmd.description.isNotEmpty) {
        printInfo('    ${cmd.description}');
      }
      if (cmd.aliases.isNotEmpty) {
        printInfo('    Aliases: ${cmd.aliases.join(', ')}');
      }
      if (cmd.arguments.isNotEmpty) {
        printInfo('    Arguments: ${cmd.arguments.length}');
      }
      printInfo('    Actions: ${cmd.actions.length}');
      printInfo('');
    }

    printInfo('Config file: ${config.configPath ?? config.getOrCreateConfigPath()}');

    return 0;
  }
}
