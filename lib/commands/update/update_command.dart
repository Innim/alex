import 'dart:io';
import 'package:alex/runner/alex_command.dart';
import 'package:alex/src/version.dart';

import 'check_command.dart';

class UpdateCommand extends AlexCommand {
  UpdateCommand()
      : super(
          'update',
          'Update alex to the latest version from pub.dev.',
        ) {
    addSubcommand(UpdateCheckCommand());
  }

  @override
  Future<int> doRun() async {
    printInfo('Updating alex...');
    const currentVersion = packageVersion;

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
      final newVersion = _parseNewVersion(result.stdout?.toString());
      final String message;
      if (newVersion == null) {
        printInfo('⚠️ Failed to parse new version. Contact developer.');
        message = '🎯 alex has been updated to the latest version.';
      } else if (newVersion == currentVersion) {
        message = '✅ alex is already at the latest version ($currentVersion).';
      } else {
        message = '⬆️ alex updated from $currentVersion to $newVersion.';
      }
      return success(message: message);
    } else {
      return error(result.exitCode, message: 'Failed to update alex.');
    }
  }

  String? _parseNewVersion(String? output) {
    if (output == null) return null;
    final versionRegex = RegExp(r'Activated alex (\d+\.\d+\.\d+).');
    final match = versionRegex.firstMatch(output);
    return match?.group(1);
  }
}
