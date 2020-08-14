import 'package:alex/runner/alex_command.dart';

import 'generate_command.dart';

/// Command to work with code.
class CodeCommand extends AlexCommand {
  CodeCommand() : super('code', 'Work with code') {
    addSubcommand(GenerateCommand());
  }

  @override
  Future<int> run() async {
    printUsage();
    return 0;
  }
}
