import 'package:alex/runner/alex_command.dart';
import 'package:alex/src/custom_commands/custom_command_action.dart';
import 'package:alex/src/custom_commands/custom_command_argument.dart';
import 'package:alex/src/custom_commands/custom_command_config.dart';

/// Show details of a custom command.
class ShowCustomCommand extends AlexCommand {
  ShowCustomCommand() : super('show', 'Show details of a custom command.') {
    argParser.addOption(
      'name',
      abbr: 'n',
      help: 'Name of the command to show',
      mandatory: true,
    );
  }

  @override
  Future<int> doRun() async {
    final name = argResults!['name'] as String;
    final config = CustomCommandsConfig.instance;

    final cmd = config.findCommand(name);
    if (cmd == null) {
      printError('Command not found: $name');
      return 1;
    }

    printInfo('Command: ${cmd.name}');
    if (cmd.description.isNotEmpty) {
      printInfo('Description: ${cmd.description}');
    }
    if (cmd.aliases.isNotEmpty) {
      printInfo('Aliases: ${cmd.aliases.join(', ')}');
    }
    printInfo('');

    if (cmd.arguments.isNotEmpty) {
      printInfo('Arguments:');
      for (final arg in cmd.arguments) {
        _printArgument(arg);
      }
      printInfo('');
    }

    printInfo('Actions:');
    for (var i = 0; i < cmd.actions.length; i++) {
      _printAction(i + 1, cmd.actions[i]);
    }

    return 0;
  }

  void _printArgument(CustomCommandArgument arg) {
    final buffer = StringBuffer();
    buffer.write('  --${arg.name}');

    if (arg.abbr != null) {
      buffer.write(', -${arg.abbr}');
    }

    final details = <String>[];
    if (arg.type == CustomCommandArgumentType.flag) {
      details.add('flag');
    } else {
      details.add('option');
    }

    if (arg.required) {
      details.add('required');
    }

    if (arg.defaultValue != null) {
      details.add('default: ${arg.defaultValue}');
    }

    if (arg.allowed != null && arg.allowed!.isNotEmpty) {
      details.add('allowed: ${arg.allowed!.join(', ')}');
    }

    buffer.write(' (${details.join(', ')})');

    printInfo(buffer.toString());

    if (arg.help != null) {
      printInfo('      ${arg.help}');
    }
  }

  void _printAction(int index, CustomCommandAction action) {
    printInfo('  $index. ${action.type}');

    if (action is ExecAction) {
      printInfo('      executable: ${action.executable}');
      if (action.args != null && action.args!.isNotEmpty) {
        printInfo('      args: ${action.args!.join(' ')}');
      }
      if (action.workingDir != null) {
        printInfo('      working_dir: ${action.workingDir}');
      }
    } else if (action is AlexAction) {
      printInfo('      command: ${action.command}');
      if (action.args.isNotEmpty) {
        printInfo('      args: ${action.args.join(' ')}');
      }
    } else if (action is ScriptAction) {
      printInfo('      path: ${action.path}');
      if (action.args.isNotEmpty) {
        printInfo('      args: ${action.args.join(' ')}');
      }
    }
  }
}
