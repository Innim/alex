import 'package:alex/runner/alex_command.dart';

import 'finish_command.dart';

class FeatureCommand extends AlexCommand {
  FeatureCommand() : super('feature', 'Work with feature branch', const ['f']) {
    addSubcommand(FinishCommand());
  }

  @override
  Future<int> doRun() async {
    printUsage();
    return 0;
  }
}
