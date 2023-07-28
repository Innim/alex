import 'package:alex/alex.dart';

import 'src/l10n_command_base.dart';

/// Command to extract strings from Dart code to arb file.
class ExtractCommand extends L10nCommandBase {
  ExtractCommand()
      : super('extract', 'Extract strings from Dart code to arb file.');

  @override
  Future<int> doRun() async {
    final config = findConfigAndSetWorkingDir();
    final l10nConfig = config.l10n;

    await extractLocalization(l10nConfig);

    final mainFile = await L10nUtils.getMainArb(l10nConfig);
    return success(
        message: 'Strings extracted to ARB file. '
            'You can send $mainFile to the translators or create an XML with "alex l10n to_xml" command if you need to.');
  }
}
