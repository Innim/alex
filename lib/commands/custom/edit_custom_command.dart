import 'dart:io';

import 'package:alex/runner/alex_command.dart';
import 'package:alex/src/custom_commands/custom_command_config.dart';

/// Edit custom commands configuration.
class EditCustomCommand extends AlexCommand {
  EditCustomCommand()
      : super('edit', 'Edit custom commands configuration file.') {
    argParser.addOption(
      'editor',
      abbr: 'e',
      help: r'Editor to use (default: $EDITOR or vim)',
    );
  }

  @override
  Future<int> doRun() async {
    final config = CustomCommandsConfig.instance;
    final configPath = config.getOrCreateConfigPath();

    // Create config file if it doesn't exist
    final configFile = File(configPath);
    if (!configFile.existsSync()) {
      printInfo('Creating new config file: $configPath');
      config.save();
    }

    // Determine editor to use
    final editorArg = argResults!['editor'] as String?;
    final editor = editorArg ??
        Platform.environment['EDITOR'] ??
        Platform.environment['VISUAL'] ??
        (Platform.isMacOS || Platform.isLinux ? 'vim' : 'notepad');

    printInfo('Opening config file in $editor: $configPath');

    try {
      final result = await Process.run(
        editor,
        [configPath],
      );

      if (result.exitCode == 0) {
        printInfo('');
        printInfo('Reloading configuration...');

        // Reload configuration
        try {
          CustomCommandsConfig.reload();
          printInfo('Configuration reloaded successfully');
          return 0;
        } catch (e) {
          printError('Failed to reload configuration: $e');
          printError('Please check the config file for errors');
          return 1;
        }
      } else {
        printError('Editor exited with code: ${result.exitCode}');
        return result.exitCode;
      }
    } catch (e) {
      printError('Failed to open editor: $e');
      printInfo('');
      printInfo('You can edit the file manually at: $configPath');
      return 1;
    }
  }
}
