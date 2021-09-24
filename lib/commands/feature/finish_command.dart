import 'package:alex/runner/alex_command.dart';
import 'package:alex/src/exception/run_exception.dart';

import 'src/feature_command_base.dart';

/// Command to finish feature branch.
class FinishCommand extends FeatureCommandBase {
  static const _argDemo = CmdArg('demo');
  static const _argIssue = CmdArg('issue', abbr: 'i');

  FinishCommand()
      : super(
            'finish',
            'Finish feature by issue id: '
                'merge and remove branch, and update changelog.',
            const ['f']) {
    argParser
      ..addFlag(
        _argDemo.name,
        help: 'Runs command in demonstration mode.',
      )
      ..addArg(
        _argIssue,
        help: 'Issue number, which used for branch name. Required.',
        valueHelp: 'NUMBER',
      );
  }

  @override
  Future<int> run() async {
    final issueId = argResults.getInt(_argIssue);

    if (issueId == null) {
      printUsage();
      return success();
    }

    try {
      return success(message: 'Finished 🏁');
    } on RunException catch (e) {
      return errorBy(e);
    } catch (e) {
      return error(2, message: 'Failed by: $e');
    }
  }
}
