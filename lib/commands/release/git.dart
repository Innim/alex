import 'dart:core';
import 'dart:io';

const String branchMaster = "master";
const String branchDevelop = "develop";

void ensureCleanStatus() {
  ensure(() => gitStatus("check status of current branch", porcelain: true),
      (r) {
    // print("r: " + r);
    return r != "";
  }, "There are unstaged changes. Commit or reset them to proceed.");
}

void ensureRemoteUrl() {
  // TODO: not sure that's correct
  ensure(() => gitRemoteGetUrl("ensure that upstream remote is valid"), (r) {
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
  gitCheckout(branchMaster);
  gitMerge(branch);
  gitTag(name);
  gitCheckout(branchDevelop);
  gitMerge(branch);
  gitBranchDelete(branch);
}

void gitTag(String tag) {
  git("tag -m \"$tag\" -a $tag", "set tag $tag");
}

String gitRemoteGetUrl(String desc) {
  return git("remote get-url origin", desc);
}

String gitFetch(String branch, [String origin = "origin"]) {
  return git("fetch $origin", "fetch $origin");
}

void gitBranchDelete(String branch) {
  git("branch -d $branch", "delete $branch");
}

void gitMerge(String branch) {
  _git(["merge", "-m", "Merge branch '$branch'", "--no-edit", branch],
      "merge $branch");
}

String gitPull([String origin = "origin"]) {
  // TODO: git pull origin develop?
  return git("pull $origin", "pull $origin");
}

void gitPush(String branch) {
  git("push -v --tags origin $branch:$branch", "pushing $branch");
}

void gitAddAll() {
  git("add -A", "adding all changes");
}

void gitCommit(String message) {
  _git(["commit", "-m", "$message"], "committing changes");
}

String gitStatus(String desc, {bool porcelain = false, String errorMsg}) {
  // TODO: join -> split((
  return git(["status", if (porcelain) "--porcelain"].join(" "), desc);
}

String gitCheckout(String branch) {
  return git("checkout $branch", "check out $branch branch");
}

String gitGetCurrentBranch([String desc]) {
  return git("branch --show-current", desc ?? "get current branch");
}

void ensure(
    String Function() action, bool Function(String) isFailed, String message) {
  if (isFailed(action())) {
    fail<void>(message);
  }
}

/// Runs git process and returns result.
///
/// If run fails, it will print an error and exit the process.
String git(String args, String desc) {
  final arguments = args.split(' ');
  return _git(arguments, desc);
}

/// Runs git process and returns result.
///
/// If run fails, it will print an error and exit the process.
String _git(List<String> args, String desc) {
  final result = Process.runSync("git", args);

  final out = result.stdout as String;
  final code = result.exitCode;
  final error = result.stderr as String;

  if (code == 0) {
    return out.trim();
  }

  print("git ${args.join(" ")}");
  print("\"$desc\" failed. Git exit code: $code. Error: $error");

  if (out.isNotEmpty) {
    print("git stdout:\n$out\n");
  }

  if (error.isNotEmpty) {
    print("git stderr:\n$error\n");
  }

  return fail();
}

T fail<T>([String message]) {
  if (message != null) {
    print(message);
  }

  exit(1);
  return null;
}
