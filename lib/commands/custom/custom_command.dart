import 'package:alex/commands/custom/add_custom_command.dart';
import 'package:alex/commands/custom/check_custom_commands.dart';
import 'package:alex/commands/custom/edit_custom_command.dart';
import 'package:alex/commands/custom/list_custom_commands.dart';
import 'package:alex/commands/custom/remove_custom_command.dart';
import 'package:alex/commands/custom/show_custom_command.dart';
import 'package:alex/runner/alex_command.dart';

/// Manage custom commands.
class CustomCommand extends AlexCommand {
  CustomCommand()
      : super('custom', 'Manage custom commands.', ['cmd', 'commands']) {
    addSubcommand(ListCustomCommandsCommand());
    addSubcommand(ShowCustomCommand());
    addSubcommand(AddCustomCommand());
    addSubcommand(EditCustomCommand());
    addSubcommand(RemoveCustomCommand());
    addSubcommand(CheckCustomCommandsCommand());
  }

  @override
  Future<int> doRun() async {
    printUsage();
    return 0;
  }
}
