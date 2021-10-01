import 'dart:core';
import 'dart:io';
import 'package:alex/internal/print.dart' as print;

const String branchMaster = "master";
const String branchDevelop = "develop";
const String branchRemotePrefix = "remotes/";
const String branchFeaturePrefix = "feature/";

/// Interface of a git client.
abstract class Git {
  /// Runs git process and returns result.
  ///
  /// If run fails, it will print an error and exit the process.
  String execute(List<String> args, String desc);
}

/// Git implementation.
class GitClient extends Git {
  @override
  String execute(List<String> args, String desc) {
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

  void tag(String tag) {
    git('tag -m "$tag" -a $tag', "set tag $tag");
  }

  String remoteGetUrl(String desc) {
    return git("remote get-url origin", desc);
  }

  String fetch(String branch, [String origin = "origin"]) {
    return git("fetch $origin", "fetch $origin");
  }

  void branchDelete(String branch) {
    git("branch -d $branch", "delete $branch");
  }

  void merge(String branch) {
    _git(["merge", "-m", "Merge branch '$branch'", "--no-edit", branch],
        "merge $branch");
  }

  String pull([String origin = "origin"]) {
    // TODO: git pull origin develop?
    return git("pull $origin", "pull $origin");
  }

  void push(String branch) {
    git("push -v --tags origin $branch:$branch", "pushing $branch");
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
