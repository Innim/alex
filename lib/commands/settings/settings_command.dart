import 'package:alex/runner/alex_command.dart';

import 'set_settings_command.dart';

class SettingsCommand extends AlexCommand {
  SettingsCommand() : super('settings', 'Global alex settings.') {
    addSubcommand(SetSettingsCommand());
  }

  @override
  Future<int> doRun() async {
    printUsage();
    return 0;
  }
}
