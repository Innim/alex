import 'dart:io';
import 'package:alex/runner/alex_command.dart';
import 'package:alex/internal/print.dart' as print;

class UpdateCommand extends AlexCommand {
  UpdateCommand() : super('update', 'Update alex to the latest version from pub.dev.');

  @override
  Future<int> doRun() async {
    print.printInfo('Updating alex...');
    final result = await Process.run(
      'dart',
      ['pub', 'global', 'activate', 'alex'],
      runInShell: true,
    );
    if (result.stdout != null && result.stdout.toString().isNotEmpty) {
      print.printInfo(result.stdout.toString());
    }
    if (result.stderr != null && result.stderr.toString().isNotEmpty) {
      print.printError(result.stderr.toString());
    }
    if (result.exitCode == 0) {
      print.printInfo('alex has been updated to the latest version.');
    } else {
      print.printError('Failed to update alex.');
    }
    return result.exitCode;
  }
}
