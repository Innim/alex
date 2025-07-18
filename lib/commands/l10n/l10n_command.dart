import 'package:alex/commands/l10n/check_translation_command.dart';
import 'package:alex/commands/l10n/cleanup_xml_command.dart';
import 'package:alex/commands/l10n/generate_command.dart';
import 'package:alex/runner/alex_command.dart';

import 'extract_command.dart';
import 'from_xml_command.dart';
import 'import_xml_command.dart';
import 'to_xml_command.dart';

/// Command to work with a localization.
class L10nCommand extends AlexCommand {
  L10nCommand() : super('l10n', 'Work with a localization', const ['l']) {
    addSubcommand(ExtractCommand());
    addSubcommand(GenerateCommand());
    addSubcommand(ToXmlCommand());
    addSubcommand(FromXmlCommand());
    addSubcommand(ImportXmlCommand());
    addSubcommand(CleanupXmlCommand());
    addSubcommand(CheckTranslationsCommand());
  }

  @override
  Future<int> doRun() async {
    printUsage();
    return 0;
  }
}
