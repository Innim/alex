import 'package:alex/commands/l10n/src/l10n_command_base.dart';

/// Command to generate dart files by arb files.
class GenerateCommand extends L10nCommandBase {
  GenerateCommand()
      : super('generate', 'Generate strings dart files by arb files.',
            const ['gen']);

  @override
  Future<int> doRun() async {
    final config = findConfigAndSetWorkingDir();
    final l10nConfig = config.l10n;

    await generateLocalization(l10nConfig);

    return success(message: 'All translations imported.');
  }
}
