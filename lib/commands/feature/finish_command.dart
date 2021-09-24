import 'package:alex/runner/alex_command.dart';
import 'package:alex/src/git/git.dart';
import 'package:alex/src/exception/run_exception.dart';

import 'src/feature_command_base.dart';
import 'src/demo.dart';

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
    final isDemo = argResults.getBool(_argDemo);
    final issueId = argResults.getInt(_argIssue);

    if (issueId == null) {
      printUsage();
      return success();
    }

    try {
      GitCommands git;
      if (!isDemo) {
        git = GitCommands(GitClient());
      } else {
        printInfo("Demonstration mode");
        git = GitCommands(DemoGit());
      }

      // Pull develop
      git.ensureCleanAndChekoutDevelop();

      final branchName = await _getBranchName(git, issueId);
      if (branchName == null) {
        return error(1, message: "Can't find branch for issue #$issueId");
      }

      printVerbose('Finish feature $branchName');

      // TODO: Merge develop in remote feature branch?

      // Merge feature branch (from remote) in develop
      git.gitflowFeatureFinish(
          branchName.replaceFirst(branchFeaturePrefix, ''));

      // TODO: Add entry in changelog (in a merge commit or in a new one after it)
      //  - Can be in section Added, Fixed or even Pre-release.
      // TODO: Push develop
      // TODO: Remove branch from remote
      // TODO: Merge develop in pipe/test (optional?)

// Some potential problems:
// Merge conflicts
// How to define feature branch (issue number should be enough in most cases)

      return success(message: 'Finished 🏁');
    } on RunException catch (e) {
      return errorBy(e);
    } catch (e) {
      return error(2, message: 'Failed by: $e');
    }
  }

  Future<String> _getBranchName(GitCommands git, int issueId) async {
    final branches = git.getBranches(all: true);

    final res = branches
        .map(_trimRemote)
        .where((b) => b.startsWith(branchFeaturePrefix))
        .toSet();
    if (res.isEmpty) return null;

    // TODO: if more than one - give a choise
    return res.first;
  }

  String _trimRemote(String branchName) {
    if (branchName.startsWith(branchRemotePrefix)) {
      const sep = '/';
      return branchName.split(sep).sublist(2).join(sep);
    } else {
      return branchName;
    }
  }
}
