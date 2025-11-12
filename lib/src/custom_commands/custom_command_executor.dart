import 'dart:io';

import 'package:alex/src/custom_commands/custom_command_action.dart';
import 'package:alex/src/custom_commands/custom_command_config.dart';
import 'package:alex/src/run/cmd.dart';
import 'package:logging/logging.dart';
import 'package:path/path.dart' as p;

/// Executor for custom commands.
class CustomCommandExecutor {
  // Security limits
  static const int _maxRegexPatternLength = 200;
  static const int _maxReplacementLength = 10000;
  static const int _regexTimeoutMs = 250;
  static const int _maxFileSizeForProcessing = 1073741824; // 1GB
  static const int _largeFileWarningSize = 104857600; // 100MB

  // File search limits
  static const int _maxParentDirSearchDepth = 10;

  final Logger _logger;
  final Cmd _cmd;

  CustomCommandExecutor({
    Logger? logger,
    Cmd? cmd,
  })  : _logger = logger ?? Logger('custom_command_executor'),
        _cmd = cmd ?? Cmd();

  /// Log error with stack trace and return error code.
  int _logError(String message, Object error, StackTrace stackTrace) {
    _logger.severe('$message: $error');
    _logger.fine('Stack trace:\n$stackTrace');
    return 1;
  }

  /// Execute a custom command.
  Future<int> execute(
    CustomCommandDefinition definition,
    Map<String, dynamic> arguments,
  ) async {
    _logger.info('Executing custom command: ${definition.name}');

    for (var i = 0; i < definition.actions.length; i++) {
      final action = definition.actions[i];
      _logger.fine('Executing action ${i + 1}/${definition.actions.length}: ${action.type.value}');

      final exitCode = await _executeAction(action, arguments);
      if (exitCode != 0) {
        _logger.severe('Action failed with exit code: $exitCode');
        return exitCode;
      }
    }

    _logger.info('Custom command completed successfully');
    return 0;
  }

  Future<int> _executeAction(
    CustomCommandAction action,
    Map<String, dynamic> arguments,
  ) async {
    switch (action.type) {
      case CustomCommandActionType.exec:
        return _executeExecAction(action as ExecAction, arguments);
      case CustomCommandActionType.alex:
        return _executeAlexAction(action as AlexAction, arguments);
      case CustomCommandActionType.script:
        return _executeScriptAction(action as ScriptAction, arguments);
      case CustomCommandActionType.checkGitBranch:
        return _executeCheckGitBranchAction(action as CheckGitBranchAction, arguments);
      case CustomCommandActionType.checkGitClean:
        return _executeCheckGitCleanAction(action as CheckGitCleanAction, arguments);
      case CustomCommandActionType.changeDir:
        return _executeChangeDirAction(action as ChangeDirAction, arguments);
      case CustomCommandActionType.deleteFile:
        return _executeDeleteFileAction(action as DeleteFileAction, arguments);
      case CustomCommandActionType.checkFileExists:
        return _executeCheckFileExistsAction(action as CheckFileExistsAction, arguments);
      case CustomCommandActionType.copyFile:
        return _executeCopyFileAction(action as CopyFileAction, arguments);
      case CustomCommandActionType.renameFile:
        return _executeRenameFileAction(action as RenameFileAction, arguments);
      case CustomCommandActionType.moveFile:
        return _executeMoveFileAction(action as MoveFileAction, arguments);
      case CustomCommandActionType.createFile:
        return _executeCreateFileAction(action as CreateFileAction, arguments);
      case CustomCommandActionType.createDir:
        return _executeCreateDirAction(action as CreateDirAction, arguments);
      case CustomCommandActionType.deleteDir:
        return _executeDeleteDirAction(action as DeleteDirAction, arguments);
      case CustomCommandActionType.renameDir:
        return _executeRenameDirAction(action as RenameDirAction, arguments);
      case CustomCommandActionType.replaceInFile:
        return _executeReplaceInFileAction(action as ReplaceInFileAction, arguments);
      case CustomCommandActionType.appendToFile:
        return _executeAppendToFileAction(action as AppendToFileAction, arguments);
      case CustomCommandActionType.prependToFile:
        return _executePrependToFileAction(action as PrependToFileAction, arguments);
      case CustomCommandActionType.print:
        return _executePrintAction(action as PrintAction, arguments);
      case CustomCommandActionType.wait:
        return _executeWaitAction(action as WaitAction, arguments);
      case CustomCommandActionType.checkPlatform:
        return _executeCheckPlatformAction(action as CheckPlatformAction, arguments);
      case CustomCommandActionType.createArchive:
        return _executeCreateArchiveAction(action as CreateArchiveAction, arguments);
      case CustomCommandActionType.extractArchive:
        return _executeExtractArchiveAction(action as ExtractArchiveAction, arguments);
    }
  }

  Future<int> _executeExecAction(
    ExecAction action,
    Map<String, dynamic> arguments,
  ) async {
    // Substitute variables only in arguments, not in executable
    final args = action.args?.map((arg) => _substituteVariables(arg, arguments)).toList() ?? [];

    _logger.info('Executing: ${action.executable} ${args.join(" ")}');

    try {
      final result = await _cmd.run(
        action.executable,
        arguments: args,
        workingDir: action.workingDir,
      );

      if (result.exitCode != 0) {
        _logger.severe('Command failed with exit code ${result.exitCode}');
        final stderr = result.stderr.toString();
        if (stderr.isNotEmpty) {
          _logger.severe('stderr: $stderr');
        }
      }

      return result.exitCode;
    } catch (e, stackTrace) {
      return _logError('Failed to execute command', e, stackTrace);
    }
  }

  Future<int> _executeAlexAction(
    AlexAction action,
    Map<String, dynamic> arguments,
  ) async {
    final command = _substituteVariables(action.command, arguments);
    final args = action.args
        .map((arg) => _substituteVariables(arg, arguments))
        .toList();

    _logger.info('Executing alex command: $command ${args.join(' ')}');

    // Parse alex command (e.g., 'code gen' -> ['code', 'gen'])
    final commandParts = command.split(' ').where((s) => s.isNotEmpty).toList();
    final allArgs = [...commandParts, ...args];

    try {
      ProcessResult result;

      // Try to find local alex executable first (for development)
      final alexPath = _findAlexExecutable();
      if (alexPath != null && File(alexPath).existsSync()) {
        _logger.fine('Using local alex: $alexPath');
        result = await _cmd.run('dart', arguments: [alexPath, ...allArgs]);
      } else {
        // Use globally installed alex
        _logger.fine('Using global alex');
        result = await _cmd.run('alex', arguments: allArgs);
      }

      if (result.exitCode != 0) {
        _logger.severe('Alex command failed: ${result.stderr}');
      }

      return result.exitCode;
    } catch (e, stackTrace) {
      return _logError('Failed to execute alex command', e, stackTrace);
    }
  }

  Future<int> _executeScriptAction(
    ScriptAction action,
    Map<String, dynamic> arguments,
  ) async {
    final scriptPath = _substituteVariables(action.path, arguments);
    final args = action.args
        .map((arg) => _substituteVariables(arg, arguments))
        .toList();

    _logger.info('Executing script: $scriptPath ${args.join(' ')}');

    final file = File(scriptPath);
    if (!file.existsSync()) {
      _logger.severe('Script file not found: $scriptPath');
      return 1;
    }

    try {
      final result = await _cmd.run('dart', arguments: [scriptPath, ...args]);

      if (result.exitCode != 0) {
        _logger.severe('Script failed: ${result.stderr}');
      }

      return result.exitCode;
    } catch (e, stackTrace) {
      return _logError('Failed to execute script', e, stackTrace);
    }
  }

  /// Substitute variables in format {{var_name}} with actual values.
  String _substituteVariables(String input, Map<String, dynamic> arguments) {
    var result = input;

    // Replace {{arg_name}} with actual argument values
    arguments.forEach((key, value) {
      final pattern = '{{$key}}';
      result = result.replaceAll(pattern, value.toString());
    });

    // Also support ${arg_name} format
    arguments.forEach((key, value) {
      final pattern = '\${$key}';
      result = result.replaceAll(pattern, value.toString());
    });

    return result;
  }

  /// Validate and resolve path to prevent path traversal attacks.
  ///
  /// This method ensures that the resolved path stays within the allowed base directory.
  /// If [baseDir] is null, uses current working directory.
  ///
  /// Throws [ArgumentError] if path traversal is detected.
  String _validateAndResolvePath(String path, [String? baseDir]) {
    // Resolve to absolute path
    final absolutePath = p.absolute(path);
    final normalizedPath = p.normalize(absolutePath);

    // Get base directory (default to current working directory)
    final base = baseDir != null ? p.absolute(baseDir) : Directory.current.path;
    final normalizedBase = p.normalize(base);

    // Check if path is within allowed directory
    if (!p.isWithin(normalizedBase, normalizedPath) && normalizedPath != normalizedBase) {
      throw ArgumentError(
        'Path traversal detected: "$path" resolves to "$normalizedPath" '
        'which is outside allowed directory "$normalizedBase"'
      );
    }

    return normalizedPath;
  }

  /// Safely substitute variables in path and validate it.
  String _safelyResolvePath(String pathTemplate, Map<String, dynamic> arguments) {
    final pathInput = _substituteVariables(pathTemplate, arguments);
    return _validateAndResolvePath(pathInput);
  }

  Future<int> _executeCheckGitBranchAction(
    CheckGitBranchAction action,
    Map<String, dynamic> arguments,
  ) async {
    final branch = _substituteVariables(action.branch, arguments);
    _logger.info('Checking git branch: $branch');

    try {
      // Get current branch
      final currentBranchResult = await _cmd.run(
        'git',
        arguments: ['branch', '--show-current'],
        immediatePrintStd: false,
        immediatePrintErr: false,
      );

      if (currentBranchResult.exitCode != 0) {
        _logger.severe('Failed to get current branch');
        return 1;
      }

      final currentBranch = currentBranchResult.stdout.toString().trim();

      if (currentBranch == branch) {
        _logger.info('Already on branch: $branch');
        return 0;
      }

      if (!action.autoSwitch) {
        final message = action.errorMessage ?? 'Not on branch: $branch (current: $currentBranch)';
        _logger.severe(message);
        return 1;
      }

      // Check if branch exists
      final branchExistsResult = await _cmd.run(
        'git',
        arguments: ['rev-parse', '--verify', branch],
        immediatePrintStd: false,
        immediatePrintErr: false,
      );

      if (branchExistsResult.exitCode != 0) {
        final message = action.errorMessage ?? 'Branch does not exist: $branch';
        _logger.severe(message);
        return 1;
      }

      // Switch to branch
      _logger.info('Switching to branch: $branch');
      final checkoutResult = await _cmd.run(
        'git',
        arguments: ['checkout', branch],
      );

      if (checkoutResult.exitCode != 0) {
        _logger.severe('Failed to switch to branch: $branch');
        return 1;
      }

      return 0;
    } catch (e, stackTrace) {
      return _logError('Failed to check git branch', e, stackTrace);
    }
  }

  Future<int> _executeCheckGitCleanAction(
    CheckGitCleanAction action,
    Map<String, dynamic> arguments,
  ) async {
    _logger.info('Checking git working directory is clean');

    try {
      final result = await _cmd.run(
        'git',
        arguments: ['status', '--porcelain'],
        immediatePrintStd: false,
        immediatePrintErr: false,
      );

      if (result.exitCode != 0) {
        _logger.severe('Failed to check git status');
        return 1;
      }

      final output = result.stdout.toString().trim();
      if (output.isNotEmpty) {
        final message = action.errorMessage ?? 'Git working directory is not clean';
        _logger.severe(message);
        _logger.info('Uncommitted changes:\n$output');
        return 1;
      }

      _logger.info('Git working directory is clean');
      return 0;
    } catch (e, stackTrace) {
      return _logError('Failed to check git status', e, stackTrace);
    }
  }

  Future<int> _executeChangeDirAction(
    ChangeDirAction action,
    Map<String, dynamic> arguments,
  ) async {
    // Validate path to prevent traversal attacks
    String path;
    try {
      path = _safelyResolvePath(action.path, arguments);
    } catch (e) {
      _logger.severe('Invalid path: $e');
      return 1;
    }

    _logger.info('Changing directory to: $path');

    final dir = Directory(path);
    if (!dir.existsSync()) {
      final message = action.errorMessage ?? 'Directory does not exist: $path';
      _logger.severe(message);
      return 1;
    }

    try {
      Directory.current = dir;
      _logger.info('Changed directory to: ${Directory.current.path}');
      return 0;
    } catch (e, stackTrace) {
      return _logError('Failed to change directory', e, stackTrace);
    }
  }

  Future<int> _executeDeleteFileAction(
    DeleteFileAction action,
    Map<String, dynamic> arguments,
  ) async {
    final pathInput = _substituteVariables(action.path, arguments);

    // Validate path to prevent traversal attacks
    String path;
    try {
      path = _validateAndResolvePath(pathInput);
    } catch (e) {
      _logger.severe('Invalid path: $e');
      return 1;
    }

    _logger.info('Deleting: $path');

    final file = File(path);
    final dir = Directory(path);

    final exists = file.existsSync() || dir.existsSync();

    if (!exists) {
      if (action.ignoreNotFound) {
        _logger.info('File does not exist (ignored): $path');
        return 0;
      } else {
        _logger.severe('File does not exist: $path');
        return 1;
      }
    }

    try {
      if (file.existsSync()) {
        file.deleteSync();
        _logger.info('Deleted file: $path');
      } else if (dir.existsSync()) {
        dir.deleteSync(recursive: action.recursive);
        _logger.info('Deleted directory: $path');
      }
      return 0;
    } catch (e, stackTrace) {
      return _logError('Failed to delete', e, stackTrace);
    }
  }

  Future<int> _executeCheckFileExistsAction(
    CheckFileExistsAction action,
    Map<String, dynamic> arguments,
  ) async {
    // Validate path to prevent traversal attacks
    String path;
    try {
      path = _safelyResolvePath(action.path, arguments);
    } catch (e) {
      _logger.severe('Invalid path: $e');
      return 1;
    }

    _logger.info('Checking file exists: $path');

    final file = File(path);
    final dir = Directory(path);
    final exists = file.existsSync() || dir.existsSync();

    if (action.shouldExist && !exists) {
      final message = action.errorMessage ?? 'File does not exist: $path';
      _logger.severe(message);
      return 1;
    } else if (!action.shouldExist && exists) {
      final message = action.errorMessage ?? 'File exists but should not: $path';
      _logger.severe(message);
      return 1;
    }

    _logger.info('File check passed: $path');
    return 0;
  }

  Future<int> _executeCopyFileAction(
    CopyFileAction action,
    Map<String, dynamic> arguments,
  ) async {
    // Validate paths to prevent traversal attacks
    String source, destination;
    try {
      source = _safelyResolvePath(action.source, arguments);
      destination = _safelyResolvePath(action.destination, arguments);
    } catch (e) {
      _logger.severe('Invalid path: $e');
      return 1;
    }

    _logger.info('Copying file: $source -> $destination');

    final sourceFile = File(source);
    if (!sourceFile.existsSync()) {
      _logger.severe('Source file does not exist: $source');
      return 1;
    }

    final destFile = File(destination);
    if (destFile.existsSync() && !action.overwrite) {
      _logger.severe('Destination file already exists: $destination');
      return 1;
    }

    try {
      await sourceFile.copy(destination);
      _logger.info('File copied successfully');
      return 0;
    } catch (e, stackTrace) {
      return _logError('Failed to copy file', e, stackTrace);
    }
  }

  Future<int> _executeRenameFileAction(
    RenameFileAction action,
    Map<String, dynamic> arguments,
  ) async {
    // Validate paths to prevent traversal attacks
    String oldPath, newPath;
    try {
      oldPath = _safelyResolvePath(action.oldPath, arguments);
      newPath = _safelyResolvePath(action.newPath, arguments);
    } catch (e) {
      _logger.severe('Invalid path: $e');
      return 1;
    }

    _logger.info('Renaming file: $oldPath -> $newPath');

    final file = File(oldPath);
    if (!file.existsSync()) {
      _logger.severe('File does not exist: $oldPath');
      return 1;
    }

    try {
      await file.rename(newPath);
      _logger.info('File renamed successfully');
      return 0;
    } catch (e, stackTrace) {
      return _logError('Failed to rename file', e, stackTrace);
    }
  }

  Future<int> _executeMoveFileAction(
    MoveFileAction action,
    Map<String, dynamic> arguments,
  ) async {
    // Validate paths to prevent traversal attacks
    String source, destination;
    try {
      source = _safelyResolvePath(action.source, arguments);
      destination = _safelyResolvePath(action.destination, arguments);
    } catch (e) {
      _logger.severe('Invalid path: $e');
      return 1;
    }

    _logger.info('Moving file: $source -> $destination');

    final sourceFile = File(source);
    if (!sourceFile.existsSync()) {
      _logger.severe('Source file does not exist: $source');
      return 1;
    }

    try {
      await sourceFile.rename(destination);
      _logger.info('File moved successfully');
      return 0;
    } catch (e, stackTrace) {
      return _logError('Failed to move file', e, stackTrace);
    }
  }

  Future<int> _executeCreateFileAction(
    CreateFileAction action,
    Map<String, dynamic> arguments,
  ) async {
    final pathInput = _substituteVariables(action.path, arguments);

    // Validate path to prevent traversal attacks
    String path;
    try {
      path = _validateAndResolvePath(pathInput);
    } catch (e) {
      _logger.severe('Invalid path: $e');
      return 1;
    }

    final content = action.content != null
        ? _substituteVariables(action.content!, arguments)
        : '';
    _logger.info('Creating file: $path');

    final file = File(path);
    if (file.existsSync() && !action.overwrite) {
      _logger.severe('File already exists: $path');
      return 1;
    }

    try {
      // Create parent directories if needed
      final parent = file.parent;
      if (!parent.existsSync()) {
        parent.createSync(recursive: true);
      }

      await file.writeAsString(content);
      _logger.info('File created successfully');
      return 0;
    } catch (e, stackTrace) {
      return _logError('Failed to create file', e, stackTrace);
    }
  }

  Future<int> _executeCreateDirAction(
    CreateDirAction action,
    Map<String, dynamic> arguments,
  ) async {
    // Validate path to prevent traversal attacks
    String path;
    try {
      path = _safelyResolvePath(action.path, arguments);
    } catch (e) {
      _logger.severe('Invalid path: $e');
      return 1;
    }

    _logger.info('Creating directory: $path');

    final dir = Directory(path);
    if (dir.existsSync()) {
      _logger.info('Directory already exists: $path');
      return 0;
    }

    try {
      await dir.create(recursive: action.recursive);
      _logger.info('Directory created successfully');
      return 0;
    } catch (e, stackTrace) {
      return _logError('Failed to create directory', e, stackTrace);
    }
  }

  Future<int> _executeDeleteDirAction(
    DeleteDirAction action,
    Map<String, dynamic> arguments,
  ) async {
    // Validate path to prevent traversal attacks
    String path;
    try {
      path = _safelyResolvePath(action.path, arguments);
    } catch (e) {
      _logger.severe('Invalid path: $e');
      return 1;
    }

    _logger.info('Deleting directory: $path');

    final dir = Directory(path);
    if (!dir.existsSync()) {
      if (action.ignoreNotFound) {
        _logger.info('Directory does not exist (ignored): $path');
        return 0;
      } else {
        _logger.severe('Directory does not exist: $path');
        return 1;
      }
    }

    try {
      await dir.delete(recursive: action.recursive);
      _logger.info('Directory deleted successfully');
      return 0;
    } catch (e, stackTrace) {
      return _logError('Failed to delete directory', e, stackTrace);
    }
  }

  Future<int> _executeRenameDirAction(
    RenameDirAction action,
    Map<String, dynamic> arguments,
  ) async {
    // Validate paths to prevent traversal attacks
    String oldPath, newPath;
    try {
      oldPath = _safelyResolvePath(action.oldPath, arguments);
      newPath = _safelyResolvePath(action.newPath, arguments);
    } catch (e) {
      _logger.severe('Invalid path: $e');
      return 1;
    }

    _logger.info('Renaming directory: $oldPath -> $newPath');

    final dir = Directory(oldPath);
    if (!dir.existsSync()) {
      _logger.severe('Directory does not exist: $oldPath');
      return 1;
    }

    try {
      await dir.rename(newPath);
      _logger.info('Directory renamed successfully');
      return 0;
    } catch (e, stackTrace) {
      return _logError('Failed to rename directory', e, stackTrace);
    }
  }

  Future<int> _executeReplaceInFileAction(
    ReplaceInFileAction action,
    Map<String, dynamic> arguments,
  ) async {
    // Validate path to prevent traversal attacks
    String path;
    try {
      path = _safelyResolvePath(action.path, arguments);
    } catch (e) {
      _logger.severe('Invalid path: $e');
      return 1;
    }

    final find = _substituteVariables(action.find, arguments);
    final replace = _substituteVariables(action.replace, arguments);
    _logger.info('Replacing in file: $path');

    final file = File(path);
    if (!file.existsSync()) {
      _logger.severe('File does not exist: $path');
      return 1;
    }

    // Check file size to prevent memory issues
    final stat = await file.stat();
    if (stat.size > _largeFileWarningSize) {
      _logger.warning('File is very large (${stat.size} bytes), this may take a while');
    }
    if (stat.size > _maxFileSizeForProcessing) {
      _logger.severe('File too large for in-memory processing: ${stat.size} bytes');
      return 1;
    }

    try {
      var content = await file.readAsString();

      if (action.regex) {
        // Validate regex pattern length to prevent injection
        if (find.length > _maxRegexPatternLength) {
          _logger.severe('Regex pattern too complex (length > $_maxRegexPatternLength)');
          return 1;
        }

        // Validate replacement string length
        if (replace.length > _maxReplacementLength) {
          _logger.severe('Replacement string too long (length > $_maxReplacementLength)');
          return 1;
        }

        try {
          final regex = RegExp(find);

          // Test regex on multiple sample sizes to detect catastrophic backtracking
          final testSizes = [100, 500, 1000];
          for (final size in testSizes) {
            final testContent = content.length > size ? content.substring(0, size) : content;
            final startTime = DateTime.now();
            regex.allMatches(testContent).toList();
            final elapsed = DateTime.now().difference(startTime);

            if (elapsed.inMilliseconds > _regexTimeoutMs) {
              _logger.severe('Regex pattern appears to have catastrophic backtracking '
                  '(took ${elapsed.inMilliseconds}ms on $size chars, limit: ${_regexTimeoutMs}ms)');
              return 1;
            }
          }

          content = content.replaceAll(regex, replace);
        } catch (e) {
          _logger.severe('Invalid regex pattern: $find');
          _logger.severe('Error: $e');
          return 1;
        }
      } else {
        content = content.replaceAll(find, replace);
      }

      await file.writeAsString(content);
      _logger.info('File updated successfully');
      return 0;
    } catch (e, stackTrace) {
      return _logError('Failed to replace in file', e, stackTrace);
    }
  }

  Future<int> _executeAppendToFileAction(
    AppendToFileAction action,
    Map<String, dynamic> arguments,
  ) async {
    // Validate path to prevent traversal attacks
    String path;
    try {
      path = _safelyResolvePath(action.path, arguments);
    } catch (e) {
      _logger.severe('Invalid path: $e');
      return 1;
    }

    final content = _substituteVariables(action.content, arguments);
    _logger.info('Appending to file: $path');

    final file = File(path);
    if (!file.existsSync() && !action.createIfMissing) {
      _logger.severe('File does not exist: $path');
      return 1;
    }

    try {
      await file.writeAsString(content, mode: FileMode.append);
      _logger.info('Content appended successfully');
      return 0;
    } catch (e, stackTrace) {
      return _logError('Failed to append to file', e, stackTrace);
    }
  }

  Future<int> _executePrependToFileAction(
    PrependToFileAction action,
    Map<String, dynamic> arguments,
  ) async {
    // Validate path to prevent traversal attacks
    String path;
    try {
      path = _safelyResolvePath(action.path, arguments);
    } catch (e) {
      _logger.severe('Invalid path: $e');
      return 1;
    }

    final content = _substituteVariables(action.content, arguments);
    _logger.info('Prepending to file: $path');

    final file = File(path);

    var existingContent = '';
    if (file.existsSync()) {
      // Check file size before reading to prevent memory exhaustion
      final stat = await file.stat();
      if (stat.size > _largeFileWarningSize) {
        _logger.warning('File is very large (${stat.size} bytes), this may take a while');
      }
      if (stat.size > _maxFileSizeForProcessing) {
        _logger.severe('File too large for in-memory processing: ${stat.size} bytes');
        return 1;
      }

      existingContent = await file.readAsString();
    } else if (!action.createIfMissing) {
      _logger.severe('File does not exist: $path');
      return 1;
    }

    try {
      await file.writeAsString(content + existingContent);
      _logger.info('Content prepended successfully');
      return 0;
    } catch (e, stackTrace) {
      return _logError('Failed to prepend to file', e, stackTrace);
    }
  }

  Future<int> _executePrintAction(
    PrintAction action,
    Map<String, dynamic> arguments,
  ) async {
    final message = _substituteVariables(action.message, arguments);

    switch (action.level.toLowerCase()) {
      case 'error':
        _logger.severe(message);
        break;
      case 'warning':
        _logger.warning(message);
        break;
      default:
        _logger.info(message);
    }

    return 0;
  }

  Future<int> _executeWaitAction(
    WaitAction action,
    Map<String, dynamic> arguments,
  ) async {
    if (action.message != null) {
      final message = _substituteVariables(action.message!, arguments);
      _logger.info(message);
    } else {
      _logger.info('Waiting for ${action.milliseconds}ms...');
    }

    await Future<void>.delayed(Duration(milliseconds: action.milliseconds));

    return 0;
  }

  Future<int> _executeCheckPlatformAction(
    CheckPlatformAction action,
    Map<String, dynamic> arguments,
  ) async {
    final expectedPlatform = action.platform.toLowerCase();
    final currentPlatform = _getCurrentPlatform();

    _logger.info('Checking platform: expected=$expectedPlatform, current=$currentPlatform');

    if (currentPlatform != expectedPlatform) {
      final errorMsg = action.errorMessage ??
          'Platform mismatch: expected $expectedPlatform, but running on $currentPlatform';
      _logger.severe(errorMsg);
      return 1;
    }

    _logger.info('Platform check passed');
    return 0;
  }

  String _getCurrentPlatform() {
    if (Platform.isMacOS) return 'macos';
    if (Platform.isLinux) return 'linux';
    if (Platform.isWindows) return 'windows';
    return 'unknown';
  }

  Future<int> _executeCreateArchiveAction(
    CreateArchiveAction action,
    Map<String, dynamic> arguments,
  ) async {
    // Validate paths to prevent traversal attacks
    String source, destination;
    try {
      source = _safelyResolvePath(action.source, arguments);
      destination = _safelyResolvePath(action.destination, arguments);
    } catch (e) {
      _logger.severe('Invalid path: $e');
      return 1;
    }

    _logger.info('Creating archive: $destination from $source');

    try {
      // Use system commands for now (zip/tar)
      // TODO: Consider adding archive package for pure Dart implementation
      ProcessResult result;
      if (action.format == 'zip') {
        result = await _cmd.run(
          'zip',
          arguments: ['-r', destination, source],
        );
      } else if (action.format == 'tar.gz' || action.format == 'tgz') {
        result = await _cmd.run(
          'tar',
          arguments: ['-czf', destination, source],
        );
      } else {
        _logger.severe('Unsupported archive format: ${action.format}');
        return 1;
      }

      // Cleanup partially created archive on failure
      if (result.exitCode != 0) {
        final archiveFile = File(destination);
        if (archiveFile.existsSync()) {
          try {
            archiveFile.deleteSync();
            _logger.info('Cleaned up partially created archive: $destination');
          } catch (cleanupError) {
            _logger.warning('Failed to cleanup partial archive: $cleanupError');
          }
        }
      }

      return result.exitCode;
    } catch (e, stackTrace) {
      // Cleanup on exception
      final archiveFile = File(destination);
      if (archiveFile.existsSync()) {
        try {
          archiveFile.deleteSync();
          _logger.info('Cleaned up partially created archive after error: $destination');
        } catch (cleanupError) {
          _logger.warning('Failed to cleanup partial archive: $cleanupError');
        }
      }
      return _logError('Failed to create archive', e, stackTrace);
    }
  }

  Future<int> _executeExtractArchiveAction(
    ExtractArchiveAction action,
    Map<String, dynamic> arguments,
  ) async {
    // Validate paths to prevent traversal attacks
    String source, destination;
    try {
      source = _safelyResolvePath(action.source, arguments);
      destination = _safelyResolvePath(action.destination, arguments);
    } catch (e) {
      _logger.severe('Invalid path: $e');
      return 1;
    }

    _logger.info('Extracting archive: $source to $destination');

    // Ensure destination directory exists
    final destDir = Directory(destination);
    final dirCreatedByUs = !destDir.existsSync();
    if (dirCreatedByUs) {
      await destDir.create(recursive: true);
    }

    try {
      // Detect format from file extension
      ProcessResult result;
      if (source.endsWith('.zip')) {
        result = await _cmd.run(
          'unzip',
          arguments: [source, '-d', destination],
        );
      } else if (source.endsWith('.tar.gz') || source.endsWith('.tgz')) {
        result = await _cmd.run(
          'tar',
          arguments: ['-xzf', source, '-C', destination],
        );
      } else {
        _logger.severe('Unsupported archive format: $source');
        return 1;
      }

      // Cleanup on failure: only if we created the directory and it's empty
      if (result.exitCode != 0 && dirCreatedByUs) {
        try {
          final isEmpty = destDir.listSync().isEmpty;
          if (isEmpty) {
            destDir.deleteSync();
            _logger.info('Cleaned up empty extraction directory: $destination');
          } else {
            _logger.warning('Extraction failed but directory contains files, not cleaning up: $destination');
          }
        } catch (cleanupError) {
          _logger.warning('Failed to cleanup extraction directory: $cleanupError');
        }
      }

      return result.exitCode;
    } catch (e, stackTrace) {
      // Cleanup on exception: only if we created the directory and it's empty
      if (dirCreatedByUs) {
        try {
          if (destDir.existsSync()) {
            final isEmpty = destDir.listSync().isEmpty;
            if (isEmpty) {
              destDir.deleteSync();
              _logger.info('Cleaned up empty extraction directory after error: $destination');
            } else {
              _logger.warning('Extraction failed but directory contains files, not cleaning up: $destination');
            }
          }
        } catch (cleanupError) {
          _logger.warning('Failed to cleanup extraction directory: $cleanupError');
        }
      }
      return _logError('Failed to extract archive', e, stackTrace);
    }
  }

  /// Find alex executable (bin/alex.dart).
  /// Returns null if not found (will use global alex instead).
  String? _findAlexExecutable() {
    // Try to find bin/alex.dart relative to current directory
    var dir = Directory.current;
    for (var i = 0; i < _maxParentDirSearchDepth; i++) {
      final alexPath = '${dir.path}/bin/alex.dart';
      if (File(alexPath).existsSync()) {
        return alexPath;
      }

      final parent = dir.parent;
      if (parent.path == dir.path) {
        break;
      }
      dir = parent;
    }

    // Not found - will use global alex
    return null;
  }
}
