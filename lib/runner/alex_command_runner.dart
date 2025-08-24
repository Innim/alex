import 'dart:async';

import 'package:alex/commands/code/code_command.dart';
import 'package:alex/commands/feature/feature_command.dart';
import 'package:alex/commands/l10n/l10n_command.dart';
import 'package:alex/commands/pubspec/pubspec_command.dart';
import 'package:alex/commands/release/release_command.dart';
import 'package:alex/commands/settings/settings_command.dart';
import 'package:alex/runner/alex_command.dart';
import 'package:alex/commands/update_command.dart';
import 'package:alex/src/const.dart';
import 'package:alex/src/local_data.dart';
import 'package:alex/src/version.dart';
import 'package:args/args.dart';
import 'package:args/command_runner.dart';
import 'package:in_date_utils/in_date_utils.dart';
import 'package:logging/logging.dart';
import 'package:alex/internal/print.dart' as print;
import 'package:pub_updater/pub_updater.dart';

class AlexCommandRunner extends CommandRunner<int> {
  static const _argVersion = 'version';
  final _out = Logger('alex');
  final PubUpdater _pubUpdater;
  final AlexLocalData _localData;

  AlexCommandRunner({PubUpdater? pubUpdater, AlexLocalData? localData})
      : _pubUpdater = pubUpdater ?? PubUpdater(),
        _localData = localData ?? AlexLocalData(),
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

    argParser.addFlag(
      _argVersion,
      abbr: 'v',
      help: 'Show current version of alex',
      negatable: false,
    );
  }

  @override
  Future<int?> runCommand(ArgResults topLevelResults) async {
    final version = topLevelResults[_argVersion] as bool;

    print.setupRootLogger();

    await _checkForUpdates();

    if (version) {
      _out.info('v$packageVersion');
      return 0;
    } else {
      return super.runCommand(topLevelResults);
    }
  }

  Future<void> _checkForUpdates() async {
    const nextCheckAfterSuccess = Duration(days: 1);
    const nextCheckAfterFail = Duration(hours: 1);

    try {
      final nextUpdateCheck = await _localData.nextUpdateCheck;
      if (nextUpdateCheck?.isAfter(DTU.now()) ?? false) {
        return;
      }

      final isUpToDate = await _pubUpdater.isUpToDate(
        packageName: packageName,
        currentVersion: packageVersion,
      );

      unawaited(
          _localData.setNextUpdateCheck(DTU.now().add(nextCheckAfterSuccess)));
      unawaited(_localData.setLastUpdateCheck(DTU.now()));

      if (isUpToDate) return;

      final latestVersion = await _pubUpdater.getLatestVersion(packageName);

      final hLine = ''.padLeft(20, '-');
      _out.info(
        '$hLine\n'
        '🔄 Update available!\n'
        '$packageVersion \u2192 $latestVersion\n'
        '$hLine\n',
      );
    } catch (_) {
      unawaited(
          _localData.setNextUpdateCheck(DTU.now().add(nextCheckAfterFail)));
      // TODO: print verbose
      _out.info('Failed to check for a new version');
    }
  }
}
