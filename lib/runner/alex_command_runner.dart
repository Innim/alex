import 'dart:async';

import 'package:alex/commands/changelog/changelog_command.dart';
import 'package:alex/commands/code/code_command.dart';
import 'package:alex/commands/custom/custom_command.dart';
import 'package:alex/commands/custom/user_custom_command.dart';
import 'package:alex/commands/feature/feature_command.dart';
import 'package:alex/commands/l10n/l10n_command.dart';
import 'package:alex/commands/pubspec/pubspec_command.dart';
import 'package:alex/commands/release/release_command.dart';
import 'package:alex/commands/settings/settings_command.dart';
import 'package:alex/runner/alex_command.dart';
import 'package:alex/commands/update/update_command.dart';
import 'package:alex/src/custom_commands/custom_command_config.dart';
import 'package:alex/src/local_data.dart';
import 'package:alex/src/system/update_checker.dart';
import 'package:alex/src/version.dart';
import 'package:args/args.dart';
import 'package:args/command_runner.dart';
import 'package:logging/logging.dart';
import 'package:alex/internal/print.dart' as print;

class AlexCommandRunner extends CommandRunner<int> {
  static const _argVersion = 'version';

  final _out = Logger('alex');
  final AlexLocalData _localData;

  AlexCommandRunner({AlexLocalData? localData})
      : _localData = localData ?? AlexLocalData(),
        super(
          'alex',
          'A command line tool for working with Flutter projects.',
        ) {
    <AlexCommand>[
      // HelloWorldCommand(),
      ReleaseCommand(),
      L10nCommand(),
      CodeCommand(),
      PubspecCommand(),
      FeatureCommand(),
      ChangelogCommand(),
      SettingsCommand(),
      UpdateCommand(),
      CustomCommand(),
    ].forEach(addCommand);

    // Load and register custom commands
    _loadCustomCommands();

    argParser
      ..addFlag(
        _argVersion,
        abbr: 'v',
        help: 'Show current version of alex',
        negatable: false,
      )
      ..addVerboseFlag();
  }

  void _loadCustomCommands() {
    try {
      _out.fine('Loading custom commands...');
      CustomCommandsConfig.load();
      final config = CustomCommandsConfig.instance;
      _out.fine(
          'Custom commands config loaded, found ${config.commands.length} command(s)');

      for (final definition in config.commands) {
        try {
          _out.fine('Registering custom command: ${definition.name}');
          final command = UserCustomCommand(definition);
          addCommand(command);
          _out.info(
              'Successfully registered custom command: ${definition.name}');
        } catch (e, stackTrace) {
          _out.severe(
              'Failed to register custom command ${definition.name}: $e');
          _out.fine('Stack trace: $stackTrace');
        }
      }

      if (config.commands.isNotEmpty) {
        _out.info('Loaded ${config.commands.length} custom command(s)');
      } else {
        _out.fine('No custom commands found in config');
      }
    } catch (e, stackTrace) {
      _out.warning('Failed to load custom commands: $e');
      _out.fine('Stack trace: $stackTrace');
    }
  }

  @override
  Future<int?> runCommand(ArgResults topLevelResults) async {
    final version = topLevelResults[_argVersion] as bool;
    final isVerbose = _hasVerbose(topLevelResults);

    print.setupRootLogger(isVerbose: isVerbose);

    // do not execute check for "update" command and its subcommands
    if (!_needSkipCheckForUpdates(topLevelResults)) {
      await _checkForUpdates();
    }

    if (version) {
      _out.info('v$packageVersion');
      return 0;
    } else {
      return super.runCommand(topLevelResults);
    }
  }

  Command<dynamic>? _getCommand(ArgResults? result) {
    if (result == null) return null;

    final commandName = result.name;
    return commandName != null ? commands[commandName] : null;
  }

  bool _needSkipCheckForUpdates(ArgResults topLevelResults) {
    final command = _getCommand(topLevelResults.command);
    return command is UpdateCommand;
  }

  Future<void> _checkForUpdates() async {
    final checker = UpdateChecker(_localData, _out);
    await checker.run(skipIfRecent: true);
  }

  bool _hasVerbose(ArgResults? results) {
    return results != null &&
        (results.isVerbose() || _hasVerbose(results.command));
  }
}
