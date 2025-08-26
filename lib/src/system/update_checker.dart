import 'dart:async';

import 'package:alex/src/const.dart';
import 'package:alex/src/local_data.dart';
import 'package:alex/src/version.dart';
import 'package:in_date_utils/in_date_utils.dart';
import 'package:logging/logging.dart';
import 'package:pub_updater/pub_updater.dart';

const _kNextCheckAfterSuccess = Duration(days: 1);
const _kNextCheckAfterFail = Duration(hours: 1);

class UpdateChecker {
  final PubUpdater pubUpdater;
  final Logger out;
  final AlexLocalData localData;

  UpdateChecker(
    this.localData,
    this.out, {
    PubUpdater? pubUpdater,
  }) : pubUpdater = pubUpdater ?? PubUpdater();

  Future<UpdateCheckResult> run({
    bool skipIfRecent = false,
  }) async {
    out.fine('Checking for updates...');
    if (skipIfRecent && await _checkIfRecent()) {
      out.fine('Skipping, recent check already performed');
      return const UpdateCheckSkipped();
    }

    return _checkForUpdates();
  }

  Future<bool> _checkIfRecent() async {
    final nextUpdateCheck = await localData.nextUpdateCheck;
    if (nextUpdateCheck?.isAfter(DTU.now()) ?? false) {
      return true;
    }

    return false;
  }

  Future<UpdateCheckResult> _checkForUpdates() async {
    try {
      final isUpToDate = await pubUpdater.isUpToDate(
        packageName: packageName,
        currentVersion: packageVersion,
      );

      _saveNextUpdateCheck(_kNextCheckAfterSuccess);
      _saveLastSuccessCheck();

      if (isUpToDate) {
        out.fine('No update available');
        return const UpdateCheckResultUpToDate();
      }

      final latestVersion = await pubUpdater.getLatestVersion(packageName);

      final hLine = ''.padLeft(20, '-');
      out.info(
        '$hLine\n'
        '🔄 Update available!\n'
        '$packageVersion \u2192 $latestVersion\n'
        '$hLine\n'
        'Run "alex update" to update.',
      );
      return UpdateCheckResultUpdateAvailable(latestVersion);
    } catch (_) {
      _saveNextUpdateCheck(_kNextCheckAfterFail);
      // TODO: print verbose
      out.info('Failed to check for a new version');
      return UpdateCheckFailure('Failed to check for a new version');
    }
  }

  void _saveNextUpdateCheck(Duration inTime) {
    localData.setNextUpdateCheck(DTU.now().add(inTime));
  }

  void _saveLastSuccessCheck() {
    localData.setLastUpdateCheck(DTU.now());
  }
}

sealed class UpdateCheckResult {
  const UpdateCheckResult();
}

class UpdateCheckResultUpToDate extends UpdateCheckResult {
  const UpdateCheckResultUpToDate();
}

class UpdateCheckResultUpdateAvailable extends UpdateCheckResult {
  final String latestVersion;

  const UpdateCheckResultUpdateAvailable(this.latestVersion);
}

class UpdateCheckFailure extends UpdateCheckResult {
  final String errorMessage;

  UpdateCheckFailure(this.errorMessage);
}

class UpdateCheckSkipped extends UpdateCheckResult {
  const UpdateCheckSkipped();
}
