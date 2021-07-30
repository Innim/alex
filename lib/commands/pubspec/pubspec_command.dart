import 'package:alex/commands/pubspec/update_command.dart';
import 'package:alex/runner/alex_command.dart';

class PubspecCommand extends AlexCommand {
  PubspecCommand() : super('pubspec', 'Work with pubspec.yaml.') {
    addSubcommand(UpdateCommand());
  }

  @override
  Future<int> run() async {
    printUsage();
    return 0;
  }
}
