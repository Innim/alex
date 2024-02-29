import 'package:alex/commands/code/code_command.dart';
import 'package:alex/commands/feature/feature_command.dart';
import 'package:alex/commands/l10n/l10n_command.dart';
import 'package:alex/commands/pubspec/pubspec_command.dart';
import 'package:alex/commands/release/release_command.dart';
import 'package:alex/commands/settings/settings_command.dart';
import 'package:alex/runner/alex_command.dart';
import 'package:alex/src/version.dart';
import 'package:args/args.dart';
import 'package:args/command_runner.dart';
import 'package:logging/logging.dart';
import 'package:alex/internal/print.dart' as print;

class AlexCommandRunner extends CommandRunner<int> {
  static const _argVersion = 'version';
  final _out = Logger('alex');

  AlexCommandRunner()
      : super(
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

    if (version) {
      _out.info('v$packageVersion');
      return 0;
    } else {
      return super.runCommand(topLevelResults);
    }
  }
}
