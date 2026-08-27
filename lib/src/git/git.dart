import 'dart:core';
import 'dart:io';
import 'package:alex/alex.dart';
import 'package:alex/internal/print.dart' as print;
import 'package:alex/src/exception/run_exception.dart';

const String _branchRemotePrefix = "remotes/";
const _sep = '/';

/// Interface of a git client.
abstract class Git {
  /// Runs git process and returns result.
  ///
  /// If run fails, it will print an error and exit the process.
  String execute(List<String> args, String desc, {bool printIfError = true});
}

/// Git implementation.
class GitClient extends Git {
  final bool isVerbose;

  GitClient({this.isVerbose = false});

  @override
  String execute(List<String> args, String desc, {bool printIfError = true}) {
    _verbose(desc);
    final result = Process.runSync("git", args);

    final out = result.stdout as String;
    final code = result.exitCode;
    final error = result.stderr as String;

    if (code == 0) {
      return out.trimRight();
    }

    if (printIfError) {
      print.info("git ${args.join(" ")}");
      print.info('"$desc" failed. Git exit code: $code.');
    }

    String? message;

    if (error.isNotEmpty) {
      if (printIfError) print.error("git stderr:\n$error\n");
      message = error;
    }

    if (out.isNotEmpty) {
      if (printIfError) print.info("git stdout:\n$out\n");
      message ??= out;
    }

    throw RunException.withCode(code, message);
  }

  void _verbose(String message) {
    if (isVerbose) print.verbose(message);
  }
}

class ConsoleGit extends Git {
  @override
  String execute(List<String> args, String desc, {bool printIfError = true}) {
    print.info("git ${args.join(" ")}");
    return "";
  }
}

class GitCommands {
  final Git _client;
  final AlexGitConfig _config;

  GitCommands(this._client, this._config);

  // String get branchRemotePrefix => _branchRemotePrefix;

  String get branchMaster => _config.branches.master;

  String get branchDevelop => _config.branches.develop;

  String get branchTest => _config.branches.test;

  String get branchFeaturePrefix => _config.branches.featurePrefix;

  String get defaultRemote => _config.remote;

  void ensureCleanStatus({
    bool printChanges = false,
  }) {
    ensure(
      () => status("check status of current branch", porcelain: true),
      (r) => r != "",
      (r) {
        final sb = StringBuffer(
            'There are uncommitted changes. Commit or reset them to proceed.');
        if (printChanges) {
          sb
            ..writeln()
            ..writeln('Changes:')
            ..writeln(r);
        }
        return sb.toString().trim();
      },
    );
  }

  void ensureRemoteUrl() {
    // TODO: not sure that's correct
    ensure(
      () => remoteGetUrl("ensure that upstream remote is valid"),
      (r) {
        // print("r: " + r);
        return !(r.startsWith("http") && r.length > 8 ||
            r.startsWith('git@') && r.endsWith('.git'));
      },
      (r) =>
          'Current directory has no valid upstream setting. Check remote URL.',
    );
  }

  /// Returns a name of the release branch for the release [name].
  String getReleaseBranch(String name) => "release/$name";

  void gitflowReleaseStart(String name, [String? desc]) {
    // gitflowRelease(
    //     "start '$name' $branchDevelop", desc ?? "git flow release $name");
    final branch = getReleaseBranch(name);

    git("checkout -b $branch $branchDevelop", desc ?? "git flow release $name");
  }

  void gitflowReleaseFinish(String name,
      {String? desc, bool failOnMergeConflict = false}) {
    // TODO: unused desc
    // gitflowRelease("finish -m \"merge\" '$name'", desc ?? "git flow finish $name");
    final branch = getReleaseBranch(name);
    checkout(branchMaster);
    merge(branch, failOnMergeConflict: failOnMergeConflict);
    tag(name);
    checkout(branchDevelop);
    merge(branch, failOnMergeConflict: failOnMergeConflict);
    branchDelete(branch);
  }

  void gitflowFeatureFinish(String branchName,
      {bool deleteBranch = true,
      bool failOnMergeConflict = false,
      bool squash = false,
      String? squashMessage}) {
    checkout(branchDevelop);
    if (squash) {
      mergeSquash(branchName, squashMessage ?? "Merge branch '$branchName'",
          failOnMergeConflict: failOnMergeConflict);
    } else {
      merge(branchName, failOnMergeConflict: failOnMergeConflict);
    }
    // Squash merge does not mark the branch as merged, so a force delete
    // is required to remove it.
    if (deleteBranch) branchDelete(branchName, force: squash);
  }

  void mergeDevelopInTest({String? remote, bool failOnMergeConflict = false}) {
    remote ??= defaultRemote;
    checkout(branchTest);
    pull(remote);
    merge(branchDevelop, failOnMergeConflict: failOnMergeConflict);
    push(branchTest, remote);
    checkout(branchDevelop);
  }

  void tag(String tag) {
    git('tag -m "$tag" -a $tag', "set tag $tag");
  }

  /// Removes a local tag.
  void tagDelete(String tag) {
    git('tag -d $tag', "delete tag $tag");
  }

  /// Returns `true` if a local tag with the given name exists.
  bool hasTag(String tag) {
    return git('tag -l $tag', "check tag $tag").isNotEmpty;
  }

  /// Returns `true` if a local branch with the given name exists.
  bool hasLocalBranch(String branch) {
    return git('branch --list $branch', "check branch $branch").isNotEmpty;
  }

  String getCurrentCommit(String branch) {
    return git('rev-parse $branch', "get current commit for $branch");
  }

  String getLastCommonCommit(String branchA, String branchB) {
    return git('merge-base $branchA $branchB',
        "get last common commit for $branchA and $branchB");
  }

  List<String> getModifiedFiles() {
    final res = status('get modified files', porcelain: true);
    if (res.isEmpty) {
      return const [];
    } else {
      return res
          .split('\n')
          .map((line) {
            // First two characters = status
            // From 4th character onwards = file path
            return line.substring(3);
          })
          .where((line) => line.isNotEmpty)
          .toList();
    }
  }

  String remoteGetUrl(String desc, [String? remote]) {
    remote ??= defaultRemote;
    return git("remote get-url $remote", desc);
  }

  String fetch(String branch, [String? remote]) {
    remote ??= defaultRemote;
    return git("fetch $remote", "fetch $remote");
  }

  void branchDelete(String branch, {bool force = false}) {
    if (branch.startsWith(_branchRemotePrefix)) {
      final parts = branch.split(_sep);
      final remote = parts[1];
      final remoteBranchName = parts.sublist(2).join(_sep);
      branchDeleteFromRemote(remoteBranchName, remote);
    } else {
      git("branch ${force ? '-D' : '-d'} $branch", "delete $branch");
    }
  }

  void branchDeleteFromRemote(String branch, [String? remote]) {
    remote ??= defaultRemote;
    git("push $remote --delete $branch", "delete $branch from $remote");
  }

  void merge(String branch, {bool failOnMergeConflict = false}) {
    try {
      _git(["merge", "-m", "Merge branch '$branch'", "--no-edit", branch],
          "merge $branch");
    } on RunException catch (e) {
      if (!failOnMergeConflict &&
          e.exitCode == 1 &&
          (e.message?.contains(
                  'Automatic merge failed; fix conflicts and then commit the result.') ??
              false)) {
        print.info('alex will continue after merge would be resolved');
        do {
          sleep(const Duration(seconds: 1));
        } while (isInMerge());

        // check if merged (it can be aborted)
        // get all merged branches
        final merged = getBranches(all: true, merged: true);
        if (!merged.contains(branch)) {
          fail("Branch $branch wasn't merged");
        }

        return;
      }

      rethrow;
    }
  }

  /// Merges [branch] into the current branch squashing all its commits,
  /// then records the result as a single commit with the given [message].
  void mergeSquash(String branch, String message,
      {bool failOnMergeConflict = false}) {
    try {
      _git(["merge", "--squash", branch], "squash merge $branch");
    } on RunException catch (e) {
      if (!failOnMergeConflict &&
          e.exitCode == 1 &&
          (e.message?.contains(
                  'Automatic merge failed; fix conflicts and then commit the result.') ??
              false)) {
        print.info('alex will continue after merge would be resolved');
        do {
          sleep(const Duration(seconds: 1));
          // Squash merge does not set MERGE_HEAD, so we wait until there are
          // no unmerged paths left instead of relying on isInMerge().
        } while (hasUnmergedPaths());
      } else {
        rethrow;
      }
    }

    commit(message);
  }

  bool hasUnmergedPaths() {
    final res = git('diff --name-only --diff-filter=U', 'check unmerged paths');
    return res.isNotEmpty;
  }

  bool isInMerge() {
    try {
      _git(['merge', 'HEAD'], 'Check if in merge', printIfError: false);
      return false;
    } on RunException catch (e) {
      if (e.exitCode == 128) {
        return true;
      } else {
        rethrow;
      }
    }
  }

  bool isRemoteBranch(String? branchName) =>
      branchName?.startsWith(_branchRemotePrefix) ?? false;

  bool isDefaultRemoteBranch(String? branchName) =>
      branchName?.startsWith('$_branchRemotePrefix$defaultRemote/') ?? false;

  String getBaseNameForRemoteBranch(String remoteBranchName) =>
      remoteBranchName.split(_sep).sublist(2).join(_sep);

  String pull([String? remote]) {
    remote ??= defaultRemote;
    return git("pull $remote", "pull $remote");
  }

  void push(String branch, [String? remote]) {
    remote ??= defaultRemote;
    git("push -v --tags $remote $branch:$branch", "pushing $branch");
  }

  void addAll() {
    git("add -A", "adding all changes");
  }

  /// Returns `true` if files in the [path] can't get in a commit
  /// after [addAll]: the path is ignored by git
  /// or it's outside the repository.
  bool isPathOutOfIndex(String path) {
    try {
      _git(['check-ignore', '-q', path], 'check if <$path> is ignored',
          printIfError: false);
      return true;
    } on RunException catch (e) {
      switch (e.exitCode) {
        // The path is not ignored.
        case 1:
          return false;
        // The path is outside the repository.
        case 128:
          return true;
        default:
          rethrow;
      }
    }
  }

  void commit(String message) {
    _git(["commit", "-m", message], "committing changes");
  }

  String status(String desc, {bool porcelain = false, String? errorMsg}) {
    // TODO: join -> split((
    return git(["status", if (porcelain) "--porcelain"].join(" "), desc);
  }

  String checkout(String branch) {
    return git("checkout $branch", "check out $branch branch");
  }

  String getCurrentBranch([String? desc]) {
    return git("branch --show-current", desc ?? "get current branch");
  }

  bool resetHard() {
    try {
      git("reset --hard", "reset hard");
      return true;
    } on RunException catch (_) {
      return false;
    }
  }

  /// Resets the current branch to the [commit], discarding all changes.
  void resetHardTo(String commit) {
    git("reset --hard $commit", "reset hard to $commit");
  }

  /// Aborts a merge in progress.
  void mergeAbort() {
    _git(["merge", "--abort"], "abort merge");
  }

  /// Removes untracked files and directories.
  ///
  /// Files ignored by git are not affected.
  void clean() {
    git("clean -fd", "remove untracked files");
  }

  Iterable<String> getBranches({
    bool all = false,
    bool merged = false,
    bool printIfError = true,
  }) {
    final cmd = StringBuffer('branch');
    if (all) cmd.write(' -a');
    if (merged) cmd.write(' --merged');
    final res =
        git(cmd.toString(), 'Get branches list', printIfError: printIfError);
    return res.split('\n').map((e) => e.trim()).where((e) => e.isNotEmpty);
  }

  void ensure(
    String Function() action,
    bool Function(String) isFailed,
    String Function(String) message,
  ) {
    final res = action();
    if (isFailed(res)) {
      fail(message(res));
    }
  }

  String git(String args, String desc, {bool printIfError = true}) {
    final arguments = args.split(' ');
    return _git(arguments, desc, printIfError: printIfError);
  }

  String _git(List<String> args, String desc, {bool printIfError = true}) =>
      _client.execute(args, desc, printIfError: printIfError);
}

void fail([String? message]) {
  throw RunException.err(message);
}

extension GitCommandsExtension on GitCommands {
  void ensureCleanAndCheckoutDevelop() {
    ensureCleanStatus();

    if (getCurrentBranch() != branchDevelop) {
      checkout(branchDevelop);
    }

    ensureRemoteUrl();

    pull();

    ensureCleanStatus();
  }
}
