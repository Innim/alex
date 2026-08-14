import 'dart:io';
import 'package:alex/runner/alex_command.dart';
import 'package:alex/src/exception/run_exception.dart';
import 'package:alex/src/local_data.dart';
import 'package:alex/src/system/update_checker.dart';
import 'package:alex/src/version.dart';

class UpdateCommand extends AlexCommand {
  static const _argChange = CmdArg('check');

  final AlexLocalData _localData;
  UpdateCommand({AlexLocalData? localData})
      : _localData = localData ?? AlexLocalData(),
        super(
          'update',
          'Update alex to the latest version from pub.dev.',
        ) {
    argParser
      ..addFlagArg(
        _argChange,
        help: 'Run check if there are updates available for alex.',
      );
  }

  @override
  Future<int> doRun() async {
    final ar = argResults!;
    final isCheck = ar.getBool(_argChange) || ar.rest.contains('check');

    if (isCheck) {
      return _runCheck();
    } else {
      return _runUpdate();
    }
  }

  Future<int> _runUpdate() async {
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

  Future<int> _runCheck() async {
    final checker = UpdateChecker(_localData, out);
    final result = await checker.run();

    switch (result) {
      case UpdateCheckResultUpToDate():
        return success(message: '✅ alex is up to date.');
      case UpdateCheckResultUpdateAvailable():
        return success();
      case UpdateCheckFailure():
        return error(
          1,
          message:
              "❌ Update check failed. Check your internet connection or try again later.",
        );
      case UpdateCheckSkipped():
        throw const RunException.err('Unexpected result: check was skipped.');
    }
  }

  String? _parseNewVersion(String? output) {
    if (output == null) return null;
    final versionRegex = RegExp(r'Activated alex (\d+\.\d+\.\d+).');
    final match = versionRegex.firstMatch(output);
    return match?.group(1);
  }
}
