import 'package:alex/runner/alex_command.dart';
import 'package:alex/src/exception/run_exception.dart';
import 'package:alex/src/local_data.dart';
import 'package:alex/src/system/update_checker.dart';

class UpdateCheckCommand extends AlexCommand {
  final AlexLocalData _localData;

  UpdateCheckCommand({AlexLocalData? localData})
      : _localData = localData ?? AlexLocalData(),
        super(
          'check',
          'Check if there are updates available for alex.',
        );

  @override
  Future<int> doRun() async {
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
}
