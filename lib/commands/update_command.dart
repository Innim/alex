import 'dart:io';
import 'package:alex/runner/alex_command.dart';

class UpdateCommand extends AlexCommand {
  UpdateCommand() : super('update', 'Update alex to the latest version from pub.dev.');

  @override
  Future<int> doRun() async {
    printInfo('Updating alex...');
    final result = await Process.run(
      'dart',
      ['pub', 'global', 'activate', 'alex'],
      runInShell: true,
    );
    if (result.stdout != null && result.stdout.toString().isNotEmpty) {
      printInfo(result.stdout.toString());
    }
    if (result.stderr != null && result.stderr.toString().isNotEmpty) {
      printError(result.stderr.toString());
    }
    if (result.exitCode == 0) {
      return success(message: 'alex has been updated to the latest version.');
    } else {
      return error(result.exitCode, message: 'Failed to update alex.');
    }
  }
}
