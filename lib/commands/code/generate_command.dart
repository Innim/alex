import 'package:alex/commands/code/src/code_generation.dart';

import 'src/code_command_base.dart';

/// Command to run code generation.
class GenerateCommand extends CodeCommandBase with CodeGenerationMixin {
  GenerateCommand() : super('gen', 'Run code generation.');

  @override
  Future<int> doRun() async {
    printInfo('Start code generation...');

    final count = await generateCode();

    return count == 0
        ? success(
            message: '🔍 No pubspec.yaml with build_runner dependency found.',
          )
        : success(message: '🛠️ Code generation complete!');
  }
}
