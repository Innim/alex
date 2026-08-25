import 'dart:io';

import 'package:alex/src/config.dart';
import 'package:alex/src/pub_spec.dart';
import 'package:path/path.dart' as p;
import 'package:version/version.dart';
import 'package:yaml/yaml.dart';
import 'src/code_command_base.dart';

/// Command to run code generation.
class GenerateCommand extends CodeCommandBase {
  static const _buildRunner = 'build_runner';
  static const _pubspecLockFileName = 'pubspec.lock';

  /// Minimal `build_runner` version that supports the `--workspace` flag.
  static final _minWorkspaceVersion = Version(2, 11, 0);

  GenerateCommand() : super('gen', 'Run code generation.');

  @override
  Future<int> doRun() async {
    printInfo('Start code generation...');

    final rootDirPath = p.current;
    printVerbose('Current directory: $rootDirPath');
    printVerbose('Search for pubspec with $_buildRunner dependency');

    final targets = await _findTargets();
    printVerbose('Found ${targets.length} target(s)');

    if (targets.isEmpty) {
      return success(
        message: '🔍 No pubspec.yaml with $_buildRunner dependency found.',
      );
    }

    for (final target in targets) {
      final relativePath = p.relative(target.pubspec.path, from: rootDirPath);
      printInfo('Generating code for $relativePath'
          '${target.useWorkspace ? ' (workspace)' : ''}');

      setCurrentDir(target.pubspec.parent.path);
      printVerbose('Current directory: ${Directory.current.path}');

      await flutter.runPubOrFail(
        'build_runner',
        [
          'build',
          '--delete-conflicting-outputs',
          if (target.useWorkspace) '--workspace',
        ],
        // Deps are already resolved while gating workspace generation, so avoid
        // a redundant pub get here.
        prependWithPubGet: !target.depsResolved,
        title: 'Running code generation',
      );

      printInfo('Generation for $relativePath - DONE');
    }

    return success(message: '🛠️ Code generation complete!');
  }

  Future<List<_GenTarget>> _findTargets() async {
    final files = await Spec.getPubspecs();
    printVerbose('Found ${files.length} pubspec files');

    // There may be more than one independent workspace in the scanned tree,
    // so we track each root (keyed by its directory) rather than a single one.
    // Workspace roots are always listed before their members (see the sort in
    // Spec.getPubspecs), so a member's root is already known when we reach it.
    final workspaces = <String, _WorkspaceInfo>{};
    final standalone = <File>[];

    for (final file in files) {
      final pubspec = Spec.byFile(file);
      printVerbose('Checking ${file.path}');

      final hasBuildRunner = pubspec.hasDevDependency(_buildRunner);

      if (pubspec.isWorkspaceRoot()) {
        printVerbose('Workspace root found');
        final info = workspaces.putIfAbsent(
            file.parent.path, () => _WorkspaceInfo(file));
        if (hasBuildRunner) info.rootHasBuildRunner = true;
        continue;
      }

      if (pubspec.isResolveFromWorkspace()) {
        if (!hasBuildRunner) {
          printVerbose('Resolved from workspace, no $_buildRunner - skipped');
          continue;
        }

        final info = _findWorkspaceForMember(workspaces, file.parent.path);
        if (info != null) {
          printVerbose('Resolved from workspace with $_buildRunner');
          info.memberHasBuildRunner = true;
        } else {
          printVerbose('Resolved from workspace with $_buildRunner, '
              'but no workspace root found - skipped');
        }
        continue;
      }

      if (!hasBuildRunner) {
        printVerbose('No $_buildRunner - skipped');
        continue;
      }

      printVerbose('Found $_buildRunner');
      standalone.add(file);
    }

    final targets = <_GenTarget>[];

    for (final info in workspaces.values) {
      final rootPath = p.relative(info.root.path);

      if (info.rootHasBuildRunner) {
        // Workspace-wide builds and dependency resolution are rooted at the
        // workspace root, and `build_runner` must be launched from a package
        // that depends on it, so we always run from the root here.
        final workspaceEnabled = _isWorkspaceGenEnabled();
        // Gating resolves dependencies at the root (refreshing a stale/missing
        // lockfile), so the build step can skip its own pub get in that case.
        final supported =
            workspaceEnabled && await _isWorkspaceFlagSupported(info.root);
        if (supported) {
          printVerbose('Using --workspace flag for workspace $rootPath');
          targets.add(_GenTarget(info.root,
              useWorkspace: true, depsResolved: workspaceEnabled));
        } else {
          // Fallback to the legacy behavior: run generation from the workspace
          // root only (with a custom build.yaml), packages are skipped.
          printVerbose('Workspace flag is not used, '
              'generating for workspace root $rootPath only');
          targets.add(_GenTarget(info.root, depsResolved: workspaceEnabled));
        }
      } else if (info.memberHasBuildRunner) {
        // We could only launch a workspace build from a member package, which
        // is not the intended entry point. Ask the user to add build_runner to
        // the root instead of silently generating from an unexpected package.
        printInfo('Workspace $rootPath declares $_buildRunner only in member '
            'packages. Add $_buildRunner to the workspace root '
            'dev_dependencies to enable workspace code generation. Skipping.');
      } else {
        printVerbose('No $_buildRunner in workspace $rootPath - skipped');
      }
    }

    targets.addAll(standalone.map(_GenTarget.new));

    return targets;
  }

  /// Returns the workspace whose root directory is the closest ancestor of
  /// [memberDir], or `null` if none of the known workspaces contains it.
  _WorkspaceInfo? _findWorkspaceForMember(
      Map<String, _WorkspaceInfo> workspaces, String memberDir) {
    _WorkspaceInfo? best;
    var bestLen = -1;
    for (final entry in workspaces.entries) {
      final rootDir = entry.key;
      if (p.equals(rootDir, memberDir) || p.isWithin(rootDir, memberDir)) {
        final len = p.split(rootDir).length;
        if (len > bestLen) {
          bestLen = len;
          best = entry.value;
        }
      }
    }
    return best;
  }

  bool _isWorkspaceGenEnabled() {
    try {
      final enabled = config.code.useWorkspace;
      printVerbose('Config use_workspace: $enabled');
      return enabled;
    } catch (e) {
      printVerbose('Unable to load config, using default use_workspace '
          'value (${CodeConfig.defaultUseWorkspace}): $e');
      return CodeConfig.defaultUseWorkspace;
    }
  }

  Future<bool> _isWorkspaceFlagSupported(File workspaceRoot) async {
    final dirPath = workspaceRoot.parent.path;

    // Always resolve dependencies before reading the version: the lockfile may
    // be missing (fresh checkout) or stale (e.g. right after the build_runner
    // constraint was bumped), and a stale version would wrongly disable the
    // --workspace flag. Run pub get with the workspace as the working directory
    // (`pub get` ignores a positional package path).
    printVerbose('Running pub get in $dirPath '
        'to resolve the $_buildRunner version');
    await flutter.runOrFail(
      () => flutter.pub(
        'get',
        workingDir: dirPath,
        immediatePrintStd: isVerbose,
        immediatePrintErr: false,
      ),
      printStdOut: false,
    );

    final version = _getLockedBuildRunnerVersion(dirPath);
    if (version == null) {
      printVerbose('Unable to determine $_buildRunner version, '
          '--workspace flag is not used');
      return false;
    }

    final supported = version >= _minWorkspaceVersion;
    printVerbose('$_buildRunner version: $version '
        '(--workspace supported: $supported)');
    return supported;
  }

  Version? _getLockedBuildRunnerVersion(String dirPath) {
    final lockFile = File(p.join(dirPath, _pubspecLockFileName));
    if (!lockFile.existsSync()) {
      printVerbose('$_pubspecLockFileName not found in $dirPath');
      return null;
    }

    try {
      final yaml = loadYaml(lockFile.readAsStringSync());
      final packages = (yaml as YamlMap?)?['packages'] as YamlMap?;
      final entry = packages?[_buildRunner] as YamlMap?;
      final versionStr = entry?['version'] as String?;
      if (versionStr == null) return null;
      return Version.parse(versionStr);
    } catch (e) {
      printVerbose('Failed to parse $_pubspecLockFileName: $e');
      return null;
    }
  }
}

/// A single pubspec for which code generation should be run.
class _GenTarget {
  final File pubspec;
  final bool useWorkspace;

  /// Whether dependencies were already resolved (via pub get) while gating
  /// workspace generation, so the build step can skip its own pub get.
  final bool depsResolved;

  _GenTarget(this.pubspec,
      {this.useWorkspace = false, this.depsResolved = false});
}

/// Aggregated info about a single pub workspace discovered during the scan.
class _WorkspaceInfo {
  /// The workspace root pubspec.
  final File root;

  /// Whether the root package itself declares `build_runner`.
  bool rootHasBuildRunner = false;

  /// Whether any member package declares `build_runner`.
  bool memberHasBuildRunner = false;

  _WorkspaceInfo(this.root);
}
