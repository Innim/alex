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
        git = GitCommands(GitClient(isVerbose: isVerbose));
      } else {
        printInfo("Demonstration mode");
        fs = DemoFileSystem();
        git = GitCommands(DemoGit());
      }

      printVerbose('Pull develop and check status');
      git.ensureCleanAndChekoutDevelop();

      final branch = await _getBranch(git, issueId);
      if (branch == null) {
        return error(1, message: "Can't find branch for issue #$issueId");
      }

      printVerbose('Finish feature $branch');

      // priotiry - remote if exist
      final branchName = branch.remoteName ?? branch.localName;

      // TODO: Merge develop in remote feature branch?

      printVerbose('Merge feature branch in develop');
      git.gitflowFeatureFinish(branchName, deleteBranch: false);

      printVerbose('Add entry in changelog');
      final changed = await _updateChangelog(fs);

      if (changed) {
        printVerbose('Commit changelog');
        git.addAll();
        git.commit("Changelog: issue #$issueId.");
      }

      printVerbose('Push develop');
      git.push(branchDevelop);

      printVerbose('Remove feature branch');
      git.branchDelete(branchName);

      // TODO: printVerbose('Merge develop in pipe/test');
      // TODO: handle merge conflicts

      return success(message: 'Finished 🏁');
    } on RunException catch (e) {
      return errorBy(e);
    } catch (e) {
      return error(2, message: 'Failed by: $e');
    }
  }

  Future<_Branch> _getBranch(GitCommands git, int issueId) async {
    final branchesNames = git.getBranches(all: true);
    final branches = branchesNames
        .map((n) => _Branch(n))
        .where((b) => b.isIssueFeature(issueId));
    if (branches.isEmpty) return null;

    final map = <String, _Branch>{};

    for (final branch in branches) {
      final existen = map[branch.name];
      if (existen != null) {
        map[branch.name] = existen.merge(branch);
      } else {
        map[branch.name] = branch;
      }
    }

    // TODO: if more than one - give a choise
    return map.values.first;
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

class _Branch {
  final String name;
  // TODO: multiple remotes
  final String remoteName;
  final String localName;

  factory _Branch(String name) {
    String baseName;
    String localName;
    String remoteName;

    if (name.startsWith(branchRemotePrefix)) {
      const sep = '/';
      remoteName = name;
      baseName = name.split(sep).sublist(2).join(sep);
    } else {
      baseName = name;
      localName = name;
    }

    return _Branch._(baseName, localName, remoteName);
  }

  _Branch._(this.name, this.localName, this.remoteName);

  bool get isFeature => name.startsWith(branchFeaturePrefix);

  bool isIssueFeature(int issueId) =>
      name.startsWith('$branchFeaturePrefix$issueId.');

  _Branch merge(_Branch other) => _Branch._(name ?? other.name,
      localName ?? other.localName, remoteName ?? other.remoteName);

  @override
  String toString() {
    final sb = StringBuffer(name);
    if (remoteName != null) {
      sb..write(' [')..write(remoteName)..write(']');
    }
    return sb.toString();
  }
}
