import 'dart:io';

import 'package:alex/runner/alex_command.dart';
import 'package:alex/src/custom_commands/custom_command_config.dart';
import 'package:yaml/yaml.dart';

/// Check custom commands configuration validity.
class CheckCustomCommandsCommand extends AlexCommand {
  CheckCustomCommandsCommand()
      : super(
          'check',
          'Check custom commands configuration for errors.',
        );

  @override
  Future<int> doRun() async {
    printInfo('Checking custom commands configuration...');
    printInfo('');

    // Find config file
    final configPath = _findConfigFile();
    if (configPath == null) {
      printInfo('Custom commands config file not found.');
      printInfo('');
      printInfo('Expected location: alex_custom_commands.yaml');
      printInfo('Searched in current directory and parent directories (up to 10 levels)');
      printInfo('');
      printInfo('To create a config file, use:');
      printInfo('  alex custom add');
      return 0;
    }

    printInfo('Found config file: $configPath');
    printInfo('');

    // Try to load and parse directly to catch errors
    try {
      // Read and parse YAML directly
      final file = File(configPath);
      if (!file.existsSync()) {
        printError('Config file not found: $configPath');
        return 1;
      }

      final yamlString = file.readAsStringSync();
      final yamlData = loadYaml(yamlString);

      if (yamlData == null) {
        printInfo('Config file is empty.');
        printInfo('');
        printInfo('To add a command, use:');
        printInfo('  alex custom add');
        return 0;
      }

      if (yamlData is! YamlMap) {
        printError('Invalid config file format: expected YAML map, got ${yamlData.runtimeType}');
        return 1;
      }

      final commandsList = yamlData['custom_commands'] as YamlList?;
      if (commandsList == null || commandsList.isEmpty) {
        printInfo('Config file exists but contains no commands.');
        printInfo('');
        printInfo('To add a command, use:');
        printInfo('  alex custom add');
        return 0;
      }

      // Parse each command to validate
      final commands = <CustomCommandDefinition>[];
      for (var i = 0; i < commandsList.length; i++) {
        final cmdData = commandsList[i] as YamlMap;
        final cmd = CustomCommandDefinition.fromYaml(cmdData);
        commands.add(cmd);
      }

      // All commands parsed successfully

      // Show summary
      printInfo('✓ Configuration is valid!');
      printInfo('');
      printInfo('Found ${commands.length} custom command(s):');
      printInfo('');

      for (final cmd in commands) {
        printInfo('  ${cmd.name}');
        if (cmd.description.isNotEmpty) {
          printInfo('    Description: ${cmd.description}');
        }
        if (cmd.aliases.isNotEmpty) {
          printInfo('    Aliases: ${cmd.aliases.join(", ")}');
        }
        if (cmd.arguments.isNotEmpty) {
          printInfo('    Arguments: ${cmd.arguments.length}');
          for (final arg in cmd.arguments) {
            final required = arg.required ? ' (required)' : '';
            final defaultVal = arg.defaultValue != null ? ' [default: ${arg.defaultValue}]' : '';
            printInfo('      --${arg.name}$required$defaultVal');
          }
        }
        printInfo('    Actions: ${cmd.actions.length}');
        for (var i = 0; i < cmd.actions.length; i++) {
          final action = cmd.actions[i];
          printInfo('      ${i + 1}. ${action.type.value}');
        }
        printInfo('');
      }

      printInfo('You can run these commands with:');
      for (final cmd in commands) {
        printInfo('  alex ${cmd.name}');
      }

      return 0;
    } catch (e, stackTrace) {
      printError('Failed to load custom commands config!');
      printInfo('');
      printError('Error: $e');
      printInfo('');

      // Try to extract line information from error message
      final errorStr = e.toString();

      // Try multiple patterns to extract line number
      var lineMatch = RegExp(r'line (\d+):(\d+)').firstMatch(errorStr);
      lineMatch ??= RegExp(r'line (\d+)').firstMatch(errorStr);

      if (lineMatch != null) {
        final lineNum = lineMatch.group(1);
        final column = lineMatch.groupCount > 1 ? lineMatch.group(2) : null;

        var locationStr = '$configPath:$lineNum';
        if (column != null) {
          locationStr += ':$column';
        }
        printInfo('Location: $locationStr');
        printInfo('');

        // Try to show the problematic line
        try {
          final file = File(configPath);
          final lines = file.readAsLinesSync();
          final lineIndex = int.parse(lineNum!) - 1;

          if (lineIndex >= 0 && lineIndex < lines.length) {
            printInfo('Problematic line:');
            // Show context: 2 lines before, the error line, 2 lines after
            final start = (lineIndex - 2).clamp(0, lines.length);
            final end = (lineIndex + 3).clamp(0, lines.length);

            for (var i = start; i < end; i++) {
              final prefix = i == lineIndex ? '>>>' : '   ';
              printInfo('$prefix ${i + 1}: ${lines[i]}');
            }
            printInfo('');
          }
        } catch (_) {
          // Ignore errors while trying to show context
        }
      } else {
        // If no line number found, try to extract command/action info
        final commandMatch = RegExp('command "([^"]+)"').firstMatch(errorStr);
        final actionMatch = RegExp(r'action (\d+)').firstMatch(errorStr);

        if (commandMatch != null || actionMatch != null) {
          var hint = 'Hint: ';
          if (commandMatch != null) {
            hint += 'Check command "${commandMatch.group(1)}"';
          }
          if (actionMatch != null) {
            if (commandMatch != null) hint += ', ';
            hint += 'action #${actionMatch.group(1)}';
          }
          printInfo(hint);
          printInfo('');
        }
      }

      printInfo('Stack trace:');
      printInfo(stackTrace.toString());
      printInfo('');
      printInfo('Common issues:');
      printInfo('  • YAML syntax errors (check indentation, quotes)');
      printInfo('  • Missing required fields (name, actions)');
      printInfo('  • Invalid action types');
      printInfo('  • Unescaped special characters in strings');
      printInfo('  • Type mismatches (e.g., number where string expected)');
      printInfo('');
      printInfo('Try editing the config file:');
      printInfo('  alex custom edit');
      return 1;
    }
  }

  String? _findConfigFile() {
    const configFileName = 'alex_custom_commands.yaml';
    var dir = Directory.current;

    for (var i = 0; i < 10; i++) {
      final configFile = File('${dir.path}/$configFileName');
      if (configFile.existsSync()) {
        return configFile.path;
      }

      final parent = dir.parent;
      if (parent.path == dir.path) {
        break; // Reached root
      }
      dir = parent;
    }

    return null;
  }
}
