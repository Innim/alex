import 'package:alex/commands/pubspec/update_command.dart';
import 'package:alex/runner/alex_command.dart';

import 'get_command.dart';

class PubspecCommand extends AlexCommand {
  PubspecCommand()
      : super('pubspec', 'Work with pubspec.yaml.', const ['pub']) {
    addSubcommand(UpdateCommand());
    addSubcommand(GetCommand());
  }

  @override
  Future<int> run() async {
    printUsage();
    return 0;
  }
}
