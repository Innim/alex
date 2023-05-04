import 'package:alex/runner/alex_command.dart';
import 'package:alex/src/changelog/changelog.dart';
import 'package:alex/src/console/console.dart';
import 'package:alex/src/fs/fs.dart';
import 'package:alex/src/git/git.dart';
import 'package:alex/src/pub_spec.dart';

import 'src/feature_command_base.dart';
import 'src/demo.dart';

/// Command to finish feature branch.
class FinishCommand extends FeatureCommandBase {
  static const _argDemo = CmdArg('demo');
  static const _argIssue = CmdArg('issue', abbr: 'i');
  static const _argChangelog = CmdArg('changelog', abbr: 'c');

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
        help: 'Issue number, which used for branch name. '
            'Optional, you can provide it in interactive mode.',
        valueHelp: 'NUMBER',
      )
      ..addArg(
        _argChangelog,
        help: 'Line to add in CHANGELOG.md. '
            'Optional, you can provide it in interactive mode. '
            'Example: alex finish feature -${_argChangelog.abbr}"Some new feature"',
        valueHelp: 'CHANGELOG',
      );
  }

  @override
  Future<int> doRun() async {
    final args = argResults!;

    final isDemo = args.getBool(_argDemo);
    var issueId = args.getInt(_argIssue);
    final changelog = args.getString(_argChangelog);

    final console = this.console;
    final gitConfig = config.git;

    FileSystem fs;
    GitCommands git;
    if (!isDemo) {
      fs = const IOFileSystem();
      git = GitCommands(GitClient(isVerbose: isVerbose), gitConfig);
    } else {
      printInfo("Demonstration mode");
      fs = DemoFileSystem();
      git = GitCommands(DemoGit(), gitConfig);
    }

    printVerbose('Check if this is a project directory');
    final pubspecExists = await Spec.exists(fs);
    if (!pubspecExists) {
      return error(1,
          message: 'You should run command from project root directory.');
    }

    final prevBranch = git.getCurrentBranch();
    printVerbose('Current branch: $prevBranch');
    printVerbose('Pull develop and check status');
    git.ensureCleanAndCheckoutDevelop();

    final branches = await _getFeatureBranches(git);

    if (issueId == null) {
      printInfo('You should specified issue id to finish feature.');
      printInfo('Current feature branches:');
      branches.forEach((b) => printInfo('- ${b.name}'));

      printInfo('Enter issue id:');

      do {
        final issueIdStr = console.readLineSync();

        if (issueIdStr != null && issueIdStr.isNotEmpty) {
          issueId = int.tryParse(issueIdStr);
        }
        // ignore: invariant_booleans
      } while (issueId == null);
    }

    final branch = await _getBranch(branches, issueId);
    if (branch == null) {
      return error(1, message: "Can't find branch for issue #$issueId");
    }

    printInfo('Finish feature $branch');

    // priority - remote if exist
    final branchName = (branch.remoteName ?? branch.localName)!;

    // TODO: Merge develop in remote feature branch if conflict

    printVerbose('Merge feature branch in develop');
    git.gitflowFeatureFinish(branchName, deleteBranch: false);

    printVerbose('Add entry in changelog');
    final changed = await _updateChangelog(console, fs, issueId, changelog);

    if (changed) {
      printVerbose('Commit changelog');
      git.addAll();
      git.commit("Changelog: issue #$issueId.\n\nBy alex.");
    }

    printVerbose('Push develop');
    final branchDevelop = git.branchDevelop;
    git.push(branchDevelop);

    if (branchName == branch.remoteName && branch.localName != null) {
      final localName = branch.localName!;
      printVerbose('Check local feature branch $localName');

      final localCommit = git.getCurrentCommit(localName);
      final commonCommit = git.getLastCommonCommit(localName, branchName);

      if (localCommit == commonCommit) {
        printVerbose('Remove local feature branch');
        git.branchDelete(localName);
      } else {
        printVerbose('Local branch different from remote. '
            'Do not delete $localName');
      }
    }

    printVerbose('Remove feature branch');
    git.branchDelete(branchName);

    printVerbose('Merge develop in ${git.branchTest}');
    git.mergeDevelopInTest();

    // TODO: handle merge conflicts

    if (prevBranch != branchDevelop && prevBranch != branch.localName) {
      printVerbose('Return to the branch $prevBranch');
      git.checkout(prevBranch);
    }

    return success(message: 'Finished 🏁');
  }

  Future<List<_Branch>> _getFeatureBranches(GitCommands git) async {
    final branchesNames = git.getBranches(all: true);
    printVerbose('Branches: $branchesNames');

    final branches =
        branchesNames.map((n) => _Branch(git, n)).where((b) => b.isFeature);

    if (branches.isEmpty) return [];

    final map = <String, _Branch>{};

    for (final branch in branches) {
      final existing = map[branch.name];
      if (existing != null) {
        map[branch.name] = existing.merge(branch);
      } else {
        map[branch.name] = branch;
      }
    }

    final res = map.values.toList();
    res.sort((a, b) => a.name.compareTo(b.name));
    return res;
  }

  Future<_Branch?> _getBranch(Iterable<_Branch> branches, int issueId) async {
    final res = branches.where((b) => b.isIssueFeature(issueId));
    if (res.isEmpty) return null;

    // TODO: if more than one - give a choice
    return res.first;
  }

  Future<bool> _updateChangelog(Console console, FileSystem fs, int issueId,
      String? changelogLine) async {
    final changelog = Changelog(fs);

    if (!(await changelog.exists)) {
      printInfo('Changelog file is not found, skip update');
      return false;
    }

    // check if need changelog (need only after first release)
    if (!(await changelog.hasAnyVersion())) {
      printInfo('No need in changelog update (no released versions)');
      return false;
    }

    // TODO: get changelog entry candidate from task
    final String? line;
    if (changelogLine == null || changelogLine.isEmpty) {
      printInfo('Enter changelog line:');
      line = console.readLineSync();
    } else {
      line = changelogLine;
      printInfo('Changelog line: $line');
    }

    if (line == null || line.isEmpty) {
      printInfo('No changelog record');
      return false;
    }

    // Can be in section Added, Fixed or even Pre-release.
    int? section;
    do {
      printInfo('''
Which section to add:
[1]: Added (Default)
[2]: Fixed
[3]: Pre-release
?''');

      final sectionInput = console.readLineSync();
      if (sectionInput == null || sectionInput.trim().isEmpty) {
        printInfo('Use default Added');
        section = 1;
      } else {
        final intValue = int.tryParse(sectionInput);
        if (![1, 2, 3].contains(intValue)) {
          printVerbose('Invalid value <$sectionInput>');
        } else {
          section = intValue;
        }
      }
    } while (section == null);

    printVerbose('Write to changelog: $line');
    switch (section) {
      case 1:
        await changelog.addAddedEntry(line, issueId);
        break;
      case 2:
        await changelog.addFixedEntry(line, issueId);
        break;
      case 3:
        await changelog.addPreReleaseEntry(line, issueId);
        break;
    }
    await changelog.save();

    return true;
  }
}

class _Branch {
  final GitCommands git;
  final String name;
  // TODO: multiple remotes
  final String? remoteName;
  final String? localName;

  factory _Branch(GitCommands git, String name) {
    final String baseName;
    final String? localName;
    final String? remoteName;

    if (git.isDefaultRemoteBranch(name)) {
      remoteName = name;
      baseName = git.getBaseNameForRemoteBranch(name);
      localName = null;
    } else {
      baseName = name;
      localName = name;
      remoteName = null;
    }

    return _Branch._(git, baseName, localName, remoteName);
  }

  _Branch._(this.git, this.name, this.localName, this.remoteName);

  bool get isFeature => name.startsWith(git.branchFeaturePrefix);

  bool isIssueFeature(int issueId) =>
      name.startsWith('${git.branchFeaturePrefix}$issueId.');

  _Branch merge(_Branch other) => _Branch._(
        git,
        name,
        localName ?? other.localName,
        remoteName == null || git.isDefaultRemoteBranch(other.remoteName)
            ? other.remoteName
            : remoteName,
      );

  @override
  String toString() {
    final sb = StringBuffer(name);
    if (remoteName != null) {
      sb
        ..write(' [')
        ..write(remoteName)
        ..write(']');
    }
    return sb.toString();
  }
}
