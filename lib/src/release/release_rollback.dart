import 'package:alex/src/exception/run_exception.dart';
import 'package:alex/src/git/git.dart';

/// Signature of a logger used by [ReleaseRollback].
typedef ReleaseRollbackLogger = void Function(String message);

void _ignoreLog(String message) {}

/// Rollback of the repository changes made during a release.
///
/// A release changes a repository step by step: commits generated files,
/// creates a release branch, merges it in master and develop, sets a tag,
/// increments a version. If some step fails, then the repository stays
/// in a half-done state, and it should be cleaned up before the next attempt.
///
/// This class remembers what was already done and reverts it:
/// created branch and tag are removed, and master and develop branches
/// are restored to the state before the release.
///
/// Changes which are already pushed to the remote are never reverted:
/// they are published, so it's up to the user to decide what to do with them.
/// In that case rollback only reports the state of the repository.
class ReleaseRollback {
  final GitCommands _git;
  final ReleaseRollbackLogger _info;
  final ReleaseRollbackLogger _warning;
  final ReleaseRollbackLogger _error;
  final ReleaseRollbackLogger _verbose;

  String? _baseDevelopCommit;
  String? _baseMasterCommit;
  String? _releaseBranch;
  String? _tag;
  final _pushedBranches = <String>[];

  bool _armed = false;
  bool _done = false;

  ReleaseRollback(
    this._git, {
    ReleaseRollbackLogger info = _ignoreLog,
    ReleaseRollbackLogger warning = _ignoreLog,
    ReleaseRollbackLogger error = _ignoreLog,
    ReleaseRollbackLogger verbose = _ignoreLog,
  })  : _info = info,
        _warning = warning,
        _error = error,
        _verbose = verbose;

  /// Whether the rollback can be performed.
  bool get isArmed => _armed && !_done;

  /// Remembers the state of the repository before the release is started.
  ///
  /// Should be called when the working tree is clean and all the changes
  /// are pulled, because the rollback restores exactly this state
  /// and discards everything else.
  void start() {
    _baseDevelopCommit = _readCommit(_git.branchDevelop);
    _baseMasterCommit = _readCommit(_git.branchMaster);
    _armed = true;
    _verbose('Rollback point: '
        '${_git.branchDevelop} at <$_baseDevelopCommit>, '
        '${_git.branchMaster} at <$_baseMasterCommit>.');
  }

  /// Registers a release branch which is about to be created.
  ///
  /// Should be called before the branch is created, because the creation
  /// can fail in the middle.
  ///
  /// A branch which already exists is not registered: it was created
  /// not by this release, so the rollback should not remove it.
  void setReleaseBranch(String branch) {
    if (_exists('branch <$branch>', () => _git.hasLocalBranch(branch))) return;
    _releaseBranch = branch;
  }

  /// Registers a tag which is about to be set.
  ///
  /// Should be called before the tag is set, because the operation
  /// which sets it can fail after that.
  ///
  /// A tag which already exists is not registered: it was set
  /// not by this release, so the rollback should not remove it.
  void setTag(String tag) {
    if (_exists('tag <$tag>', () => _git.hasTag(tag))) return;
    _tag = tag;
  }

  /// Registers a branch which is about to be pushed to the remote.
  ///
  /// Should be called before the push, because a push can update the remote
  /// even if it failed as a whole - for example, if a branch was accepted,
  /// but a tag was rejected by a hook. After that the rollback will not change
  /// the repository, because a part of the release can be already published.
  void onPushStarted(String branch) {
    if (!_pushedBranches.contains(branch)) _pushedBranches.add(branch);
  }

  /// Reverts everything that was done since the [start],
  /// if nothing was pushed to the remote yet.
  ///
  /// Never throws: if some step fails, then the others are still performed
  /// and instructions for a manual cleanup are printed.
  void run({String? reason}) {
    if (!isArmed) {
      _verbose('There is nothing to rollback.');
      return;
    }

    _done = true;

    if (_pushedBranches.isNotEmpty) {
      _warning('Release changes can be already pushed to '
          '<${_git.defaultRemote}>: ${_pushedBranches.join(', ')}. '
          'Nothing will be rolled back, '
          'because a published release should not be rewritten.');
      _warning('Finish or revert the release manually.');
      return;
    }

    _info('Rolling back the release changes...');
    if (reason != null && reason.isNotEmpty) {
      _verbose('Rollback reason: $reason');
    }

    final failed = <String>[];

    _step('abort merge in progress', failed, _abortMerge);
    _step('discard uncommitted changes', failed, _discardChanges);
    _step('remove untracked files', failed, _git.clean);
    _step('delete tag', failed, _deleteTag);
    _step('restore ${_git.branchMaster}', failed,
        () => _restoreBranch(_git.branchMaster, _baseMasterCommit));
    _step('restore ${_git.branchDevelop}', failed,
        () => _restoreBranch(_git.branchDevelop, _baseDevelopCommit));
    _step('delete release branch', failed, _deleteReleaseBranch);
    _step('checkout ${_git.branchDevelop}', failed, _checkoutDevelop);

    if (failed.isEmpty) {
      _info('Rollback is completed: the repository is restored '
          'to the state before the release.');
    } else {
      _error("Rollback failed on: ${failed.join('; ')}.");
      _error(_manualCleanupHint());
    }
  }

  void _abortMerge() {
    if (!_git.isInMerge()) return;
    _info('Aborting merge in progress.');
    _git.mergeAbort();
  }

  void _discardChanges() {
    // Failure should not be silent: the working tree is left dirty,
    // so all the next steps will most likely fail too.
    if (!_git.resetHard()) {
      throw const RunException.err("Can't discard uncommitted changes.");
    }
  }

  void _deleteTag() {
    final tag = _tag;
    if (tag == null) return;
    if (!_git.hasTag(tag)) {
      _verbose('Tag <$tag> is not set - nothing to delete.');
      return;
    }

    _info('Deleting tag <$tag>.');
    _git.tagDelete(tag);
  }

  void _restoreBranch(String branch, String? baseCommit) {
    if (baseCommit == null || baseCommit.isEmpty) {
      _verbose('There is no saved state for <$branch> - skip.');
      return;
    }

    if (!_git.hasLocalBranch(branch)) {
      _verbose('There is no local branch <$branch> - skip.');
      return;
    }

    if (_git.getCurrentCommit(branch) == baseCommit) {
      _verbose('Branch <$branch> is not changed - skip.');
      return;
    }

    _info('Restoring <$branch> to <$baseCommit>.');
    if (_git.getCurrentBranch() != branch) _git.checkout(branch);
    _git.resetHardTo(baseCommit);
  }

  void _deleteReleaseBranch() {
    final branch = _releaseBranch;
    if (branch == null) return;
    if (!_git.hasLocalBranch(branch)) {
      _verbose('There is no branch <$branch> - nothing to delete.');
      return;
    }

    if (_git.getCurrentBranch() == branch) _git.checkout(_git.branchDevelop);

    _info('Deleting branch <$branch>.');
    // Force delete, because the branch can be not merged.
    _git.branchDelete(branch, force: true);
  }

  void _checkoutDevelop() {
    final develop = _git.branchDevelop;
    if (_git.getCurrentBranch() == develop) return;
    _git.checkout(develop);
  }

  /// Returns `true` if the reference already exists,
  /// or if it's not possible to check it.
  ///
  /// It's better to leave something not removed
  /// than to remove something which was not created by the release.
  bool _exists(String title, bool Function() check) {
    final bool res;
    try {
      res = check();
      // ignore: avoid_catches_without_on_clauses
    } catch (e) {
      _warning("Can't check if $title already exists: $e. "
          'It will not be removed by the rollback.');
      return true;
    }

    if (res) {
      _verbose('There is $title before the release - '
          'it will not be removed by the rollback.');
    }

    return res;
  }

  String? _readCommit(String branch) {
    try {
      final res = _git.getCurrentCommit(branch).trim();
      return res.isNotEmpty ? res : null;
    } on RunException catch (e) {
      _verbose("Can't get current commit for <$branch>: ${e.message ?? e}");
      return null;
    }
  }

  void _step(String title, List<String> failed, void Function() action) {
    _verbose('Rollback step: $title.');
    try {
      action();
      // ignore: avoid_catches_without_on_clauses
    } catch (e) {
      final message = e is RunException ? e.message ?? '$e' : '$e';
      _warning('Rollback step <$title> failed: $message');
      failed.add(title);
    }
  }

  String _manualCleanupHint() {
    final sb = StringBuffer('Check the state of the repository '
        'and clean it up manually:');

    final branch = _releaseBranch;
    if (branch != null) {
      sb
        ..writeln()
        ..write('  git branch -D $branch');
    }

    final tag = _tag;
    if (tag != null) {
      sb
        ..writeln()
        ..write('  git tag -d $tag');
    }

    final master = _baseMasterCommit;
    if (master != null) {
      sb
        ..writeln()
        ..write('  git checkout ${_git.branchMaster} '
            '&& git reset --hard $master');
    }

    final develop = _baseDevelopCommit;
    if (develop != null) {
      sb
        ..writeln()
        ..write('  git checkout ${_git.branchDevelop} '
            '&& git reset --hard $develop');
    }

    return sb.toString();
  }
}
