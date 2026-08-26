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
  static const _argSquash = CmdArg('squash', abbr: 's');
  static const _argSection = CmdArg('section');

  static const _sectionAdded = 'added';
  static const _sectionFixed = 'fixed';
  static const _sectionPreRelease = 'pre-release';

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
      )
      ..addFlag(
        _argSquash.name,
        abbr: _argSquash.abbr,
        help: 'Squash all feature commits into a single commit when merging '
            'into develop. Useful for tasks like golden tests updates.',
      )
      ..addArg(
        _argSection,
        help: 'Section of CHANGELOG.md to add the line in. '
            'Optional, you can provide it in interactive mode. '
            'Default is $_sectionAdded.',
        allowed: const [_sectionAdded, _sectionFixed, _sectionPreRelease],
        valueHelp: 'SECTION',
      );
  }

  @override
  bool get isInteractive => true;

  @override
  Future<int> doRun() async {
    final args = argResults!;

    final isDemo = args.getBool(_argDemo);
    var issueId = args.getInt(_argIssue);
    final changelog = args.getString(_argChangelog);
    final squash = args.getBool(_argSquash);

    // Everything that would be asked should be provided upfront,
    // so the command fails before it has changed anything.
    if (isNonInteractive) {
      if (issueId == null) {
        return errorNoAnswer('issue id', '--${_argIssue.name}=NUMBER');
      }

      if (changelog == null) {
        return errorNoAnswer(
            'changelog line',
            '--${_argChangelog.name}="Some line" '
                '(pass an empty value to skip the changelog)');
      }
    }

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

      while (issueId == null) {
        final issueIdStr = console.readLineSync();

        // No input at all - there is nobody to answer,
        // so it makes no sense to ask again.
        if (issueIdStr == null) {
          return error(1, message: 'Issue id is not provided.');
        }

        if (issueIdStr.isNotEmpty) issueId = int.tryParse(issueIdStr);
      }
    }

    final branch = await _getBranch(branches, issueId);
    if (branch == null) {
      return error(1, message: "Can't find branch for issue #$issueId");
    }

    printInfo('Finish feature $branch');

    // priority - remote if exist
    final branchName = (branch.remoteName ?? branch.localName)!;

    // TODO: Merge develop in remote feature branch if conflict

    printVerbose(squash
        ? 'Squash merge feature branch in develop'
        : 'Merge feature branch in develop');
    git.gitflowFeatureFinish(
      branchName,
      deleteBranch: false,
      squash: squash,
      squashMessage: 'Feature #$issueId: ${branch.name}.\n\nBy alex.',
    );

    printVerbose('Add entry in changelog');
    final changed = await _updateChangelog(console, fs, issueId, changelog,
        args.getString(_argSection), config.issueUrl);

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
        // Squash merge does not mark the branch as merged in git.
        git.branchDelete(localName, force: squash);
      } else {
        printVerbose('Local branch different from remote. '
            'Do not delete $localName');
      }
    }

    printVerbose('Remove feature branch');
    git.branchDelete(branchName, force: squash);

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

  /// Asks which section of CHANGELOG.md to add the line in.
  ///
  /// In the non-interactive mode the default section is used,
  /// as it is for an empty answer.
  Future<String> _getSection(Console console) async {
    if (isNonInteractive) return _sectionAdded;

    while (true) {
      printInfo('''
Which section to add:
[1]: Added (Default)
[2]: Fixed
[3]: Pre-release
?''');

      final input = console.readLineSync();
      if (input == null || input.trim().isEmpty) {
        printInfo('Use default Added');
        return _sectionAdded;
      }

      switch (int.tryParse(input)) {
        case 1:
          return _sectionAdded;
        case 2:
          return _sectionFixed;
        case 3:
          return _sectionPreRelease;
        default:
          printVerbose('Invalid value <$input>');
      }
    }
  }

  Future<bool> _updateChangelog(Console console, FileSystem fs, int issueId,
      String? changelogLine, String? section, String? issueUrl) async {
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
      // An empty value is the documented way to skip the changelog,
      // and there is nobody to ask anyway.
      if (isNonInteractive) {
        printInfo('No changelog record - an empty '
            '--${_argChangelog.name} was passed');
        return false;
      }

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
    final target = section ?? await _getSection(console);

    printVerbose('Write to changelog: $line ($target)');
    switch (target) {
      case _sectionFixed:
        await changelog.addFixedEntry(line, issueId, issueUrl);
        break;
      case _sectionPreRelease:
        await changelog.addPreReleaseEntry(line, issueId, issueUrl);
        break;
      case _sectionAdded:
      default:
        await changelog.addAddedEntry(line, issueId, issueUrl);
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
