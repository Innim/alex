import 'package:alex/runner/alex_command.dart';

import 'guide_command.dart';

/// Command to work with AI agents support.
class AgentsCommand extends AlexCommand {
  AgentsCommand()
      : super('agents', 'Support of AI agents and scripts.', ['agent']) {
    addSubcommand(GuideCommand());
  }

  @override
  Future<int> doRun() async {
    printUsage();
    return 0;
  }
}
