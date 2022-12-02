import 'package:alex/alex.dart';
import 'package:alex/src/exception/run_exception.dart';

import 'src/l10n_command_base.dart';

/// Command to extract strings from Dart code to arb file.
class ExtractCommand extends L10nCommandBase {
  ExtractCommand()
      : super('extract', 'Extract strings from Dart code to arb file.');

  @override
  Future<int> doRun() async {
    final config = findConfigAndSetWorkingDir();
    final l10nConfig = config.l10n;
    try {
    await extractLocalisation(l10nConfig);
    } on RunException catch (e) {
      return errorBy(e);
    }

    final mainFile = await L10nUtils.getMainArb(l10nConfig);
    return success(
        message: 'Strings extracted to ARB file. '
            'You can send $mainFile to the translators');
  }
}
