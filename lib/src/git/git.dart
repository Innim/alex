import 'dart:core';
import 'dart:io';
import 'package:alex/internal/print.dart' as print;

const String branchMaster = "master";
const String branchDevelop = "develop";
const String branchTest = "pipe/test";
const String branchRemotePrefix = "remotes/";
const String branchFeaturePrefix = "feature/";
const String defaultRemote = "origin";
const _sep = '/';

/// Interface of a git client.
abstract class Git {
  /// Runs git process and returns result.
  ///
  /// If run fails, it will print an error and exit the process.
  String execute(List<String> args, String desc);
}

/// Git implementation.
class GitClient extends Git {
  final bool isVerbose;

  GitClient({this.isVerbose = false});

  @override
  String execute(List<String> args, String desc) {
    _verbose(desc);
    final result = Process.runSync("git", args);

    final out = result.stdout as String;
    final code = result.exitCode;
    final error = result.stderr as String;

    if (code == 0) {
      return out.trim();
    }

    print.info("git ${args.join(" ")}");
    print.info('"$desc" failed. Git exit code: $code. Error: $error');

    if (out.isNotEmpty) {
      print.info("git stdout:\n$out\n");
    }

    if (error.isNotEmpty) {
      print.error("git stderr:\n$error\n");
    }

    return fail();
  }

  void _verbose(String message) {
    if (isVerbose) print.verbose(message);
  }
}

class ConsoleGit extends Git {
  @override
  String execute(List<String> args, String desc) {
    print.info("git ${args.join(" ")}");
    return "";
  }
}

class GitCommands {
  final Git _client;

  GitCommands(this._client) : assert(_client != null);

  void ensureCleanStatus() {
    ensure(() => status("check status of current branch", porcelain: true),
        (r) {
      // print("r: " + r);
      return r != "";
    }, "There are unstaged changes. Commit or reset them to proceed.");
  }

  void ensureRemoteUrl() {
    // TODO: not sure that's correct
    ensure(() => remoteGetUrl("ensure that upstream remote is valid"), (r) {
      // print("r: " + r);
      return !(r.startsWith("http") && r.length > 8);
    }, "Current directory has no valid upstream setting.");
  }

  void gitflowReleaseStart(String name, [String desc]) {
    // gitflowRelease(
    //     "start '$name' $branchDevelop", desc ?? "git flow release $name");
    final branch = "release/$name";

    git("checkout -b $branch $branchDevelop", desc ?? "git flow release $name");
  }

  void gitflowReleaseFinish(String name, [String desc]) {
    // TODO: unused desc
    // gitflowRelease("finish -m \"merge\" '$name'", desc ?? "git flow finish $name");
    final branch = "release/$name";
    checkout(branchMaster);
    merge(branch);
    tag(name);
    checkout(branchDevelop);
    merge(branch);
    branchDelete(branch);
  }

  void gitflowFeatureFinish(String branchName, {bool deleteBranch = true}) {
    checkout(branchDevelop);
    merge(branchName);
    if (deleteBranch) branchDelete(branchName);
  }

  void mergeDevelopInTest([String remote = defaultRemote]) {
    checkout(branchTest);
    pull(remote);
    merge(branchDevelop);
    push(branchTest, remote);
    checkout(branchDevelop);
  }

  void tag(String tag) {
    git('tag -m "$tag" -a $tag', "set tag $tag");
  }

  String remoteGetUrl(String desc, [String remote = defaultRemote]) {
    return git("remote get-url $remote", desc);
  }

  String fetch(String branch, [String remote = defaultRemote]) {
    return git("fetch $remote", "fetch $remote");
  }

  void branchDelete(String branch) {
    if (branch.startsWith(branchRemotePrefix)) {
      final parts = branch.split(_sep);
      final remote = parts[1];
      final remoteBranchName = parts.sublist(2).join(_sep);
      branchDeleteFromRemote(remoteBranchName, remote);
    } else {
      git("branch -d $branch", "delete $branch");
    }
  }

  void branchDeleteFromRemote(String branch, [String remote = defaultRemote]) {
    git("push $remote --delete $branch", "delete $branch from $remote");
  }

  void merge(String branch) {
    _git(["merge", "-m", "Merge branch '$branch'", "--no-edit", branch],
        "merge $branch");
  }

  String pull([String remote = defaultRemote]) {
    // TODO: git pull origin develop?
    return git("pull $remote", "pull $remote");
  }

  void push(String branch, [String remote = defaultRemote]) {
    git("push -v --tags $remote $branch:$branch", "pushing $branch");
  }

  void addAll() {
    git("add -A", "adding all changes");
  }

  void commit(String message) {
    _git(["commit", "-m", message], "committing changes");
  }

  String status(String desc, {bool porcelain = false, String errorMsg}) {
    // TODO: join -> split((
    return git(["status", if (porcelain) "--porcelain"].join(" "), desc);
  }

  String checkout(String branch) {
    return git("checkout $branch", "check out $branch branch");
  }

  String getCurrentBranch([String desc]) {
    return git("branch --show-current", desc ?? "get current branch");
  }

  Iterable<String> getBranches({bool all = false}) {
    final cmd = StringBuffer('branch');
    if (all) cmd.write(' -a');
    final res = git(cmd.toString(), 'Get branches list');
    return res.split('\n').map((e) => e.trim()).where((e) => e.isNotEmpty);
  }

  void ensure(String Function() action, bool Function(String) isFailed,
      String message) {
    if (isFailed(action())) {
      fail<void>(message);
    }
  }

  String git(String args, String desc) {
    final arguments = args.split(' ');
    return _git(arguments, desc);
  }

  String _git(List<String> args, String desc) => _client.execute(args, desc);
}

T fail<T>([String message]) {
  if (message != null) {
    print.error(message);
  }

  exit(1);
}

extension GitCommandsExtension on GitCommands {
  void ensureCleanAndChekoutDevelop() {
    ensureCleanStatus();

    if (getCurrentBranch() != branchDevelop) {
      checkout(branchDevelop);
    }

    ensureRemoteUrl();

    pull();

    ensureCleanStatus();
  }
}
