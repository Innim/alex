import 'dart:io';

import 'package:alex/runner/alex_command.dart';
import 'package:alex/src/changelog/changelog.dart';
import 'package:alex/src/fs/fs.dart';
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
      FileSystem fs;
      GitCommands git;
      if (!isDemo) {
        fs = IOFileSystem();
        git = GitCommands(GitClient());
      } else {
        printInfo("Demonstration mode");
        fs = DemoFileSystem();
        git = GitCommands(DemoGit());
      }

      printVerbose('Pull develop and check status');
      git.ensureCleanAndChekoutDevelop();

      final branchName = await _getBranchName(git, issueId);
      if (branchName == null) {
        return error(1, message: "Can't find branch for issue #$issueId");
      }

      printVerbose('Finish feature $branchName');

      // TODO: Merge develop in remote feature branch?

      printVerbose('Merge feature branch (from remote) in develop');
      git.gitflowFeatureFinish(
        branchName.replaceFirst(branchFeaturePrefix, ''),
        deleteBranch: false,
      );

      printVerbose('Add entry in changelog');
      final changed = await _updateChangelog(fs);

      if (changed) {
        // TODO: printVerbose('Commit changelog');
      }

      // TODO: printVerbose('Push develop');
      // TODO: printVerbose('Remove branch from remote');
      // TODO: printVerbose('Merge develop in pipe/test');
      // TODO: handle merge conflicts

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

  Future<bool> _updateChangelog(FileSystem fs) async {
    final changelog = Changelog(fs);

    // check if need changelog (need only after first release)
    if (!(await changelog.hasAnyVersion())) {
      printVerbose('No need in changelog (no released versions)');
      return false;
    }

    // TODO: get changelog entry candidate from task
    printInfo('Enter changelog line:');
    final line = stdin.readLineSync();

    if (line.isEmpty) {
      printVerbose('No changelog info');
      return false;
    }

    // TODO: Can be in section Added, Fixed or even Pre-release.

    printVerbose('Write to changelog: $line');
    await changelog.addAddedEntry(line);
    await changelog.save();

    return true;
  }
}
