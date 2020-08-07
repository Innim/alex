import 'dart:core';
import 'dart:io';

void insureCleanStatus() {
  insure(() => gitStatus("check status of current branch"), (r) => r != "",
      "Git repository isn't clean. You are to clean it before continuing.");
}

void insureRemoteUrl() {
  // TODO: not sure that's correct
  insure(
      () => gitRemoteGetUrl("insure that upstream remote is valid"),
      (r) => r.startsWith("http") && r.length > 8,
      "Current directory has no valid upstream setting.");
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
  return git(["status", if (porcelain) " --porcelain"].join(" "), desc);
}

String gitCheckout(String branch) {
  return git("checkout $branch", "check out $branch branch");
}

void insure(
    String Function() action, bool Function(String) isFailed, String message) {
  if (isFailed(action())) {
    print(message);
  }
}

/// Runs git process and returns result.
///
/// If run fails, it will print an error and exit the process.
String git(String args, String desc) {
  final result = Process.runSync("git", args.split(' '));

  final out = result.stdout as String;
  final code = result.exitCode;
  final error = result.stderr as String;

  if (error.isEmpty && code == 0) {
    return out.trim();
  }

  print("Failed to $desc. Git exit code: $code.");

  if (out.isNotEmpty) {
    print("git stdout:\n$out\n");
  }

  if (error.isNotEmpty) {
    print("git stderr:\n$error\n");
  }

  return fail();
}

T fail<T>() {
  exit(1);
  return null;
}
