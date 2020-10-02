import 'package:alex/commands/l10n/generate_command.dart';
import 'package:alex/runner/alex_command.dart';
import 'extract_command.dart';
import 'from_xml_command.dart';
import 'to_xml_command.dart';

/// Command to work with a localization.
class L10nCommand extends AlexCommand {
  L10nCommand() : super('l10n', 'Work with a localization') {
    addSubcommand(ExtractCommand());
    addSubcommand(GenerateCommand());
    addSubcommand(ToXmlCommand());
    addSubcommand(FromXmlCommand());
  }

  @override
  Future<int> run() async {
    printUsage();
    return 0;
  }
}
