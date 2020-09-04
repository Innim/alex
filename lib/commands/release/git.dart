import 'dart:core';
import 'dart:io';

const String branchDevelop = "develop";

void ensureCleanStatus() {
  ensure(() => gitStatus("check status of current branch", porcelain: true),
      (r) {
    // print("r: " + r);
    return r != "";
  }, "Git repository isn't clean. You are to clean it before continuing.");
}

void ensureRemoteUrl() {
  // TODO: not sure that's correct
  ensure(() => gitRemoteGetUrl("ensure that upstream remote is valid"), (r) {
    // print("r: " + r);
    return !(r.startsWith("http") && r.length > 8);
  }, "Current directory has no valid upstream setting.");
}

void gitflowReleaseStart(String name, [String desc]) {
  gitflowRelease(
      "start '$name' $branchDevelop", desc ?? "git flow release $name");
}

void gitflowReleaseFinish(String name, [String desc]) {
  gitflowRelease("finish '$name'", desc ?? "git flow finish $name");
}

String gitRemoteGetUrl(String desc) {
  return git("remote get-url origin", desc);
}

String gitFetch(String branch, [String origin = "origin"]) {
  return git("fetch $origin", "fetch $origin");
}

String gitPull([String origin = "origin"]) {
  // TODO: git pull origin develop?
  return git("pull $origin", "pull $origin");
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

String gitflowRelease(String args, String desc) {
  return gitflow("release $args", desc);
}

String gitflow(String args, String desc) {
  return git("flow $args", desc);
}

/// Runs git process and returns result.
///
/// If run fails, it will print an error and exit the process.
String git(String args, String desc) {
  final arguments = args.split(' ');
  final result = Process.runSync("git", arguments);

  final out = result.stdout as String;
  final code = result.exitCode;
  final error = result.stderr as String;

  if (code == 0) {
    return out.trim();
  }

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
