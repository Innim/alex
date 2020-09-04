import 'dart:io';

import 'package:alex/alex.dart';
import 'package:alex/src/exception/run_exception.dart';

import 'src/l10n_command_base.dart';
import 'package:path/path.dart' as path;

/// Command to generate dart files by arb files.
class GenerateCommand extends L10nCommandBase {
  GenerateCommand()
      : super('generate', 'Generate strings dart files by arb files.');

  @override
  Future<int> run() async {
    final config = l10nConfig;
    final arbFiles = await _getArbFiles(config);

    try {
      await runIntlOrFail('generate_from_arb', [
        '--output-dir=${config.outputDir}',
        config.sourceFile,
        ...arbFiles,
      ]);
    } on RunException catch (e) {
      return errorBy(e);
    }

    // TODO: check if all translations for all keys are exist

    return success(message: 'All translations imported.');
  }

  Future<List<String>> _getArbFiles(L10nConfig config) async {
    final dir = config.outputDir;
    final l10nDir = Directory(dir);
    final arbMessagesFile = L10nUtils.getArbMessagesFile(config);
    final arbParts = L10nUtils.getArbFileParts(config);
    final arbStart = arbParts[0];
    final arbEnd = arbParts[1];

    final res = <String>[];
    await for (final file in l10nDir.list()) {
      final filename = path.basename(file.path);
      if (filename != arbMessagesFile &&
          filename.startsWith(arbStart) &&
          filename.endsWith(arbEnd)) {
        res.add(path.join(dir, filename));
      }
    }

    return res;
  }
}
