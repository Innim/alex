import 'package:alex/runner/alex_command.dart';
import 'package:alex/src/custom_commands/custom_command_argument.dart';
import 'package:alex/src/custom_commands/custom_command_config.dart';
import 'package:alex/src/custom_commands/custom_command_executor.dart';

/// A dynamically created command based on custom command definition.
class UserCustomCommand extends AlexCommand {
  final CustomCommandDefinition _definition;
  final CustomCommandExecutor _executor;

  UserCustomCommand(this._definition)
      : _executor = CustomCommandExecutor(),
        super(
          _definition.name,
          _definition.description,
          _definition.aliases,
        ) {
    // Add arguments from definition
    for (final arg in _definition.arguments) {
      _addArgument(arg);
    }
  }

  void _addArgument(CustomCommandArgument arg) {
    switch (arg.type) {
      case CustomCommandArgumentType.option:
        argParser.addOption(
          arg.name,
          abbr: arg.abbr,
          help: arg.help,
          defaultsTo: arg.defaultValue,
          allowed: arg.allowed,
          mandatory: arg.required,
        );
        break;
      case CustomCommandArgumentType.flag:
        argParser.addFlag(
          arg.name,
          abbr: arg.abbr,
          help: arg.help,
          defaultsTo: arg.defaultValue == 'true',
        );
        break;
    }
  }

  @override
  Future<int> doRun() async {
    // Collect argument values
    final arguments = <String, dynamic>{};

    for (final arg in _definition.arguments) {
      final value = argResults![arg.name];
      if (value != null) {
        arguments[arg.name] = value;
      }
    }

    printVerbose('Executing custom command: ${_definition.name}');
    printVerbose('Arguments: $arguments');
    printVerbose('Verbose mode: enabled');

    try {
      // Create executor with verbose logger if needed
      final executor = isVerbose
          ? CustomCommandExecutor(logger: out)
          : _executor;

      final exitCode = await executor.execute(_definition, arguments);
      return exitCode;
    } catch (e, st) {
      printError('Failed to execute custom command: $e');
      printVerbose('Stack trace: $st');
      return 1;
    }
  }
}
