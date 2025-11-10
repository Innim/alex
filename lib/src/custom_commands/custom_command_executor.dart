import 'dart:io';

import 'package:alex/src/custom_commands/custom_command_action.dart';
import 'package:alex/src/custom_commands/custom_command_config.dart';
import 'package:alex/src/run/cmd.dart';
import 'package:logging/logging.dart';

/// Executor for custom commands.
class CustomCommandExecutor {
  final Logger _logger;
  final Cmd _cmd;

  CustomCommandExecutor({
    Logger? logger,
    Cmd? cmd,
  })  : _logger = logger ?? Logger('custom_command_executor'),
        _cmd = cmd ?? Cmd();

  /// Execute a custom command.
  Future<int> execute(
    CustomCommandDefinition definition,
    Map<String, dynamic> arguments,
  ) async {
    _logger.info('Executing custom command: ${definition.name}');

    for (var i = 0; i < definition.actions.length; i++) {
      final action = definition.actions[i];
      _logger.fine('Executing action ${i + 1}/${definition.actions.length}: ${action.type}');

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
    if (action is ExecAction) {
      return _executeExecAction(action, arguments);
    } else if (action is AlexAction) {
      return _executeAlexAction(action, arguments);
    } else if (action is ScriptAction) {
      return _executeScriptAction(action, arguments);
    } else if (action is CheckGitBranchAction) {
      return _executeCheckGitBranchAction(action, arguments);
    } else if (action is CheckGitCleanAction) {
      return _executeCheckGitCleanAction(action, arguments);
    } else if (action is ChangeDirAction) {
      return _executeChangeDirAction(action, arguments);
    } else if (action is DeleteFileAction) {
      return _executeDeleteFileAction(action, arguments);
    } else if (action is CheckFileExistsAction) {
      return _executeCheckFileExistsAction(action, arguments);
    } else if (action is CopyFileAction) {
      return _executeCopyFileAction(action, arguments);
    } else if (action is RenameFileAction) {
      return _executeRenameFileAction(action, arguments);
    } else if (action is MoveFileAction) {
      return _executeMoveFileAction(action, arguments);
    } else if (action is CreateFileAction) {
      return _executeCreateFileAction(action, arguments);
    } else if (action is CreateDirAction) {
      return _executeCreateDirAction(action, arguments);
    } else if (action is DeleteDirAction) {
      return _executeDeleteDirAction(action, arguments);
    } else if (action is RenameDirAction) {
      return _executeRenameDirAction(action, arguments);
    } else if (action is ReplaceInFileAction) {
      return _executeReplaceInFileAction(action, arguments);
    } else if (action is AppendToFileAction) {
      return _executeAppendToFileAction(action, arguments);
    } else if (action is PrependToFileAction) {
      return _executePrependToFileAction(action, arguments);
    } else if (action is PrintAction) {
      return _executePrintAction(action, arguments);
    } else if (action is WaitAction) {
      return _executeWaitAction(action, arguments);
    } else if (action is CheckPlatformAction) {
      return _executeCheckPlatformAction(action, arguments);
    } else if (action is CreateArchiveAction) {
      return _executeCreateArchiveAction(action, arguments);
    } else if (action is ExtractArchiveAction) {
      return _executeExtractArchiveAction(action, arguments);
    } else {
      throw Exception('Unknown action type: ${action.type}');
    }
  }

  Future<int> _executeExecAction(
    ExecAction action,
    Map<String, dynamic> arguments,
  ) async {
    final command = _substituteVariables(action.command, arguments);
    _logger.info('Executing: $command');

    // Parse command into executable and arguments
    final parts = _parseCommand(command);
    if (parts.isEmpty) {
      _logger.severe('Empty command');
      return 1;
    }

    final executable = parts.first;
    final args = parts.skip(1).toList();

    try {
      final result = await _cmd.run(
        executable,
        arguments: args,
        workingDir: action.workingDir,
      );

      if (result.exitCode != 0) {
        _logger.severe('Command failed: ${result.stderr}');
      }

      return result.exitCode;
    } catch (e) {
      _logger.severe('Failed to execute command: $e');
      return 1;
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
    } catch (e) {
      _logger.severe('Failed to execute alex command: $e');
      return 1;
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
    } catch (e) {
      _logger.severe('Failed to execute script: $e');
      return 1;
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

  /// Parse command string into parts, respecting quotes.
  List<String> _parseCommand(String command) {
    final parts = <String>[];
    final buffer = StringBuffer();
    var inQuotes = false;
    var quoteChar = '';

    for (var i = 0; i < command.length; i++) {
      final char = command[i];

      if ((char == '"' || char == "'") && !inQuotes) {
        inQuotes = true;
        quoteChar = char;
      } else if (char == quoteChar && inQuotes) {
        inQuotes = false;
        quoteChar = '';
      } else if (char == ' ' && !inQuotes) {
        if (buffer.isNotEmpty) {
          parts.add(buffer.toString());
          buffer.clear();
        }
      } else {
        buffer.write(char);
      }
    }

    if (buffer.isNotEmpty) {
      parts.add(buffer.toString());
    }

    return parts;
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
    } catch (e) {
      _logger.severe('Failed to check git branch: $e');
      return 1;
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
    } catch (e) {
      _logger.severe('Failed to check git status: $e');
      return 1;
    }
  }

  Future<int> _executeChangeDirAction(
    ChangeDirAction action,
    Map<String, dynamic> arguments,
  ) async {
    final path = _substituteVariables(action.path, arguments);
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
    } catch (e) {
      _logger.severe('Failed to change directory: $e');
      return 1;
    }
  }

  Future<int> _executeDeleteFileAction(
    DeleteFileAction action,
    Map<String, dynamic> arguments,
  ) async {
    final path = _substituteVariables(action.path, arguments);
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
    } catch (e) {
      _logger.severe('Failed to delete: $e');
      return 1;
    }
  }

  Future<int> _executeCheckFileExistsAction(
    CheckFileExistsAction action,
    Map<String, dynamic> arguments,
  ) async {
    final path = _substituteVariables(action.path, arguments);
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
    final source = _substituteVariables(action.source, arguments);
    final destination = _substituteVariables(action.destination, arguments);
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
    } catch (e) {
      _logger.severe('Failed to copy file: $e');
      return 1;
    }
  }

  Future<int> _executeRenameFileAction(
    RenameFileAction action,
    Map<String, dynamic> arguments,
  ) async {
    final oldPath = _substituteVariables(action.oldPath, arguments);
    final newPath = _substituteVariables(action.newPath, arguments);
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
    } catch (e) {
      _logger.severe('Failed to rename file: $e');
      return 1;
    }
  }

  Future<int> _executeMoveFileAction(
    MoveFileAction action,
    Map<String, dynamic> arguments,
  ) async {
    final source = _substituteVariables(action.source, arguments);
    final destination = _substituteVariables(action.destination, arguments);
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
    } catch (e) {
      _logger.severe('Failed to move file: $e');
      return 1;
    }
  }

  Future<int> _executeCreateFileAction(
    CreateFileAction action,
    Map<String, dynamic> arguments,
  ) async {
    final path = _substituteVariables(action.path, arguments);
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
    } catch (e) {
      _logger.severe('Failed to create file: $e');
      return 1;
    }
  }

  Future<int> _executeCreateDirAction(
    CreateDirAction action,
    Map<String, dynamic> arguments,
  ) async {
    final path = _substituteVariables(action.path, arguments);
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
    } catch (e) {
      _logger.severe('Failed to create directory: $e');
      return 1;
    }
  }

  Future<int> _executeDeleteDirAction(
    DeleteDirAction action,
    Map<String, dynamic> arguments,
  ) async {
    final path = _substituteVariables(action.path, arguments);
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
    } catch (e) {
      _logger.severe('Failed to delete directory: $e');
      return 1;
    }
  }

  Future<int> _executeRenameDirAction(
    RenameDirAction action,
    Map<String, dynamic> arguments,
  ) async {
    final oldPath = _substituteVariables(action.oldPath, arguments);
    final newPath = _substituteVariables(action.newPath, arguments);
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
    } catch (e) {
      _logger.severe('Failed to rename directory: $e');
      return 1;
    }
  }

  Future<int> _executeReplaceInFileAction(
    ReplaceInFileAction action,
    Map<String, dynamic> arguments,
  ) async {
    final path = _substituteVariables(action.path, arguments);
    final find = _substituteVariables(action.find, arguments);
    final replace = _substituteVariables(action.replace, arguments);
    _logger.info('Replacing in file: $path');

    final file = File(path);
    if (!file.existsSync()) {
      _logger.severe('File does not exist: $path');
      return 1;
    }

    try {
      var content = await file.readAsString();

      if (action.regex) {
        final regex = RegExp(find);
        content = content.replaceAll(regex, replace);
      } else {
        content = content.replaceAll(find, replace);
      }

      await file.writeAsString(content);
      _logger.info('File updated successfully');
      return 0;
    } catch (e) {
      _logger.severe('Failed to replace in file: $e');
      return 1;
    }
  }

  Future<int> _executeAppendToFileAction(
    AppendToFileAction action,
    Map<String, dynamic> arguments,
  ) async {
    final path = _substituteVariables(action.path, arguments);
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
    } catch (e) {
      _logger.severe('Failed to append to file: $e');
      return 1;
    }
  }

  Future<int> _executePrependToFileAction(
    PrependToFileAction action,
    Map<String, dynamic> arguments,
  ) async {
    final path = _substituteVariables(action.path, arguments);
    final content = _substituteVariables(action.content, arguments);
    _logger.info('Prepending to file: $path');

    final file = File(path);

    var existingContent = '';
    if (file.existsSync()) {
      existingContent = await file.readAsString();
    } else if (!action.createIfMissing) {
      _logger.severe('File does not exist: $path');
      return 1;
    }

    try {
      await file.writeAsString(content + existingContent);
      _logger.info('Content prepended successfully');
      return 0;
    } catch (e) {
      _logger.severe('Failed to prepend to file: $e');
      return 1;
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
    }

    _logger.info('Waiting for ${action.milliseconds}ms...');
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
    final source = _substituteVariables(action.source, arguments);
    final destination = _substituteVariables(action.destination, arguments);

    _logger.info('Creating archive: $destination from $source');

    try {
      // Use system commands for now (zip/tar)
      // TODO: Consider adding archive package for pure Dart implementation
      if (action.format == 'zip') {
        final result = await _cmd.run(
          'zip',
          arguments: ['-r', destination, source],
        );
        return result.exitCode;
      } else if (action.format == 'tar.gz' || action.format == 'tgz') {
        final result = await _cmd.run(
          'tar',
          arguments: ['-czf', destination, source],
        );
        return result.exitCode;
      } else {
        _logger.severe('Unsupported archive format: ${action.format}');
        return 1;
      }
    } catch (e) {
      _logger.severe('Failed to create archive: $e');
      return 1;
    }
  }

  Future<int> _executeExtractArchiveAction(
    ExtractArchiveAction action,
    Map<String, dynamic> arguments,
  ) async {
    final source = _substituteVariables(action.source, arguments);
    final destination = _substituteVariables(action.destination, arguments);

    _logger.info('Extracting archive: $source to $destination');

    // Ensure destination directory exists
    final destDir = Directory(destination);
    if (!destDir.existsSync()) {
      await destDir.create(recursive: true);
    }

    try {
      // Detect format from file extension
      if (source.endsWith('.zip')) {
        final result = await _cmd.run(
          'unzip',
          arguments: [source, '-d', destination],
        );
        return result.exitCode;
      } else if (source.endsWith('.tar.gz') || source.endsWith('.tgz')) {
        final result = await _cmd.run(
          'tar',
          arguments: ['-xzf', source, '-C', destination],
        );
        return result.exitCode;
      } else {
        _logger.severe('Unsupported archive format: $source');
        return 1;
      }
    } catch (e) {
      _logger.severe('Failed to extract archive: $e');
      return 1;
    }
  }

  /// Find alex executable (bin/alex.dart).
  /// Returns null if not found (will use global alex instead).
  String? _findAlexExecutable() {
    // Try to find bin/alex.dart relative to current directory
    var dir = Directory.current;
    for (var i = 0; i < 10; i++) {
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
