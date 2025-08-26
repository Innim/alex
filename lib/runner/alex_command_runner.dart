import 'dart:async';

import 'package:alex/commands/code/code_command.dart';
import 'package:alex/commands/feature/feature_command.dart';
import 'package:alex/commands/l10n/l10n_command.dart';
import 'package:alex/commands/pubspec/pubspec_command.dart';
import 'package:alex/commands/release/release_command.dart';
import 'package:alex/commands/settings/settings_command.dart';
import 'package:alex/runner/alex_command.dart';
import 'package:alex/commands/update/update_command.dart';
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
      SettingsCommand(),
      UpdateCommand(),
    ].forEach(addCommand);

    argParser
      ..addFlag(
        _argVersion,
        abbr: 'v',
        help: 'Show current version of alex',
        negatable: false,
      )
      ..addVerboseFlag();
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
