import 'package:alex/src/exception/run_exception.dart';
import 'src/code_command_base.dart';

/// Command to run code generation.
class GenerateCommand extends CodeCommandBase {
  GenerateCommand() : super('gen', 'Run code generation.');

  @override
  Future<int> run() async {
    printInfo('Start code generation...');

    try {
      await runPubOrFail('build_runner', [
        'build',
        '--delete-conflicting-outputs',
      ]);
    } on RunException catch (e) {
      return errorBy(e);
    }

    return success(message: 'Code generation complete!');
  }
}
