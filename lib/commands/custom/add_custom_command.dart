import 'dart:io';

import 'package:alex/runner/alex_command.dart';
import 'package:alex/src/custom_commands/custom_command_action.dart';
import 'package:alex/src/custom_commands/custom_command_argument.dart';
import 'package:alex/src/custom_commands/custom_command_config.dart';

/// Add a new custom command.
class AddCustomCommand extends AlexCommand {
  AddCustomCommand() : super('add', 'Add a new custom command.');

  @override
  Future<int> doRun() async {
    final config = CustomCommandsConfig.instance;

    printInfo('Add new custom command');
    printInfo('');

    // Get command name
    final name = _prompt('Command name');
    if (name.isEmpty) {
      printError('Command name is required');
      return 1;
    }

    if (config.hasCommand(name)) {
      printError('Command already exists: $name');
      return 1;
    }

    // Get description
    final description = _prompt('Description (optional)');

    // Get aliases
    final aliasesStr = _prompt('Aliases (comma-separated, optional)');
    final aliases = aliasesStr.isNotEmpty
        ? aliasesStr.split(',').map((e) => e.trim()).toList()
        : <String>[];

    // Get arguments
    final arguments = <CustomCommandArgument>[];
    while (true) {
      final addArg = _prompt('Add argument? (y/n)', defaultValue: 'n');
      if (addArg.toLowerCase() != 'y') break;

      final arg = _promptArgument();
      if (arg != null) {
        arguments.add(arg);
      }
    }

    // Get actions
    final actions = <CustomCommandAction>[];
    while (true) {
      final addAction = _prompt('Add action? (y/n)', defaultValue: actions.isEmpty ? 'y' : 'n');
      if (addAction.toLowerCase() != 'y') {
        if (actions.isEmpty) {
          printError('At least one action is required');
          continue;
        }
        break;
      }

      final action = _promptAction();
      if (action != null) {
        actions.add(action);
      }
    }

    if (actions.isEmpty) {
      printError('At least one action is required');
      return 1;
    }

    // Create command definition
    final command = CustomCommandDefinition(
      name: name,
      description: description,
      aliases: aliases,
      arguments: arguments,
      actions: actions,
    );

    try {
      config.addCommand(command);
      config.save();

      printInfo('');
      printInfo('Custom command added: $name');
      printInfo('Config saved to: ${config.getOrCreateConfigPath()}');
      printInfo('');
      printInfo('You can now use it with:');
      printInfo('  alex $name');

      return 0;
    } catch (e) {
      printError('Failed to add command: $e');
      return 1;
    }
  }

  CustomCommandArgument? _promptArgument() {
    printInfo('');
    printInfo('Argument configuration:');

    final name = _prompt('  Argument name');
    if (name.isEmpty) return null;

    final typeStr = _prompt('  Type (option/flag)', defaultValue: 'option');
    final type = typeStr.toLowerCase() == 'flag'
        ? CustomCommandArgumentType.flag
        : CustomCommandArgumentType.option;

    final help = _prompt('  Help text (optional)');
    final abbr = _prompt('  Abbreviation (optional, single char)');
    final defaultValue = _prompt('  Default value (optional)');

    String? allowedStr;
    List<String>? allowed;
    if (type == CustomCommandArgumentType.option) {
      allowedStr = _prompt('  Allowed values (comma-separated, optional)');
      if (allowedStr.isNotEmpty) {
        allowed = allowedStr.split(',').map((e) => e.trim()).toList();
      }
    }

    final requiredStr = _prompt('  Required? (y/n)', defaultValue: 'n');
    final required = requiredStr.toLowerCase() == 'y';

    return CustomCommandArgument(
      name: name,
      type: type,
      help: help.isNotEmpty ? help : null,
      abbr: abbr.isNotEmpty ? abbr : null,
      defaultValue: defaultValue.isNotEmpty ? defaultValue : null,
      allowed: allowed,
      required: required,
    );
  }

  CustomCommandAction? _promptAction() {
    printInfo('');
    printInfo('Action configuration:');

    final typeStr = _prompt('  Action type (exec/alex/script)', defaultValue: 'exec');
    final type = typeStr.toLowerCase();

    switch (type) {
      case 'exec':
        return _promptExecAction();
      case 'alex':
        return _promptAlexAction();
      case 'script':
        return _promptScriptAction();
      default:
        printError('Unknown action type: $type');
        return null;
    }
  }

  ExecAction _promptExecAction() {
    final command = _prompt('  Command');
    final workingDir = _prompt('  Working directory (optional)');

    return ExecAction(
      command: command,
      workingDir: workingDir.isNotEmpty ? workingDir : null,
    );
  }

  AlexAction _promptAlexAction() {
    final command = _prompt('  Alex command (e.g., "code gen")');
    final argsStr = _prompt('  Arguments (space-separated, optional)');

    final args = argsStr.isNotEmpty ? argsStr.split(' ') : <String>[];

    return AlexAction(
      command: command,
      args: args,
    );
  }

  ScriptAction _promptScriptAction() {
    final path = _prompt('  Script path');
    final argsStr = _prompt('  Arguments (space-separated, optional)');

    final args = argsStr.isNotEmpty ? argsStr.split(' ') : <String>[];

    return ScriptAction(
      path: path,
      args: args,
    );
  }

  String _prompt(String message, {String defaultValue = ''}) {
    if (defaultValue.isNotEmpty) {
      stdout.write('$message [$defaultValue]: ');
    } else {
      stdout.write('$message: ');
    }

    final input = stdin.readLineSync() ?? '';
    return input.isEmpty ? defaultValue : input;
  }
}
