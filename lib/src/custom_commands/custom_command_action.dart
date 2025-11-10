import 'package:yaml/yaml.dart';

/// Base class for custom command actions.
abstract class CustomCommandAction {
  /// Type of the action.
  CustomCommandActionType get type;

  /// Custom error message to display if action fails.
  String? get errorMessage;

  /// Create action from YAML data.
  factory CustomCommandAction.fromYaml(YamlMap data) {
    final typeStr = data['type'] as String?;
    if (typeStr == null) {
      throw Exception('Action type is required');
    }

    final type = CustomCommandActionType.fromString(typeStr);

    switch (type) {
      case CustomCommandActionType.exec:
        return ExecAction.fromYaml(data);
      case CustomCommandActionType.alex:
        return AlexAction.fromYaml(data);
      case CustomCommandActionType.script:
        return ScriptAction.fromYaml(data);
      case CustomCommandActionType.checkGitBranch:
        return CheckGitBranchAction.fromYaml(data);
      case CustomCommandActionType.checkGitClean:
        return CheckGitCleanAction.fromYaml(data);
      case CustomCommandActionType.changeDir:
        return ChangeDirAction.fromYaml(data);
      case CustomCommandActionType.createDir:
        return CreateDirAction.fromYaml(data);
      case CustomCommandActionType.deleteDir:
        return DeleteDirAction.fromYaml(data);
      case CustomCommandActionType.renameDir:
        return RenameDirAction.fromYaml(data);
      case CustomCommandActionType.deleteFile:
        return DeleteFileAction.fromYaml(data);
      case CustomCommandActionType.checkFileExists:
        return CheckFileExistsAction.fromYaml(data);
      case CustomCommandActionType.copyFile:
        return CopyFileAction.fromYaml(data);
      case CustomCommandActionType.renameFile:
        return RenameFileAction.fromYaml(data);
      case CustomCommandActionType.moveFile:
        return MoveFileAction.fromYaml(data);
      case CustomCommandActionType.createFile:
        return CreateFileAction.fromYaml(data);
      case CustomCommandActionType.replaceInFile:
        return ReplaceInFileAction.fromYaml(data);
      case CustomCommandActionType.appendToFile:
        return AppendToFileAction.fromYaml(data);
      case CustomCommandActionType.prependToFile:
        return PrependToFileAction.fromYaml(data);
      case CustomCommandActionType.print:
        return PrintAction.fromYaml(data);
      case CustomCommandActionType.wait:
        return WaitAction.fromYaml(data);
      case CustomCommandActionType.checkPlatform:
        return CheckPlatformAction.fromYaml(data);
      case CustomCommandActionType.createArchive:
        return CreateArchiveAction.fromYaml(data);
      case CustomCommandActionType.extractArchive:
        return ExtractArchiveAction.fromYaml(data);
    }
  }

  /// Convert action to YAML map.
  Map<String, dynamic> toYaml();
}

/// Execute shell command or program.
class ExecAction implements CustomCommandAction {
  @override
  final CustomCommandActionType type = CustomCommandActionType.exec;

  /// Command to execute.
  final String command;

  /// Working directory (optional).
  final String? workingDir;

  @override
  final String? errorMessage;

  ExecAction({
    required this.command,
    this.workingDir,
    this.errorMessage,
  });

  factory ExecAction.fromYaml(YamlMap data) {
    return ExecAction(
      command: data['command'] as String? ??
          (throw Exception('exec action requires "command" field')),
      workingDir: data['working_dir'] as String?,
      errorMessage: data['error_message'] as String?,
    );
  }

  @override
  Map<String, dynamic> toYaml() {
    final result = <String, dynamic>{
      'type': type.value,
      'command': command,
    };
    if (workingDir != null) {
      result['working_dir'] = workingDir;
    }
    if (errorMessage != null) {
      result['error_message'] = errorMessage;
    }
    return result;
  }
}

/// Execute existing alex command.
class AlexAction implements CustomCommandAction {
  @override
  final CustomCommandActionType type = CustomCommandActionType.alex;

  /// Alex command to execute (e.g., 'code gen', 'l10n extract').
  final String command;

  /// Additional arguments for the command.
  final List<String> args;

  @override
  final String? errorMessage;

  AlexAction({
    required this.command,
    this.args = const [],
    this.errorMessage,
  });

  factory AlexAction.fromYaml(YamlMap data) {
    final args = data['args'] as YamlList?;
    return AlexAction(
      command: data['command'] as String? ??
          (throw Exception('alex action requires "command" field')),
      args: args?.map((e) => e.toString()).toList() ?? [],
      errorMessage: data['error_message'] as String?,
    );
  }

  @override
  Map<String, dynamic> toYaml() {
    final result = <String, dynamic>{
      'type': type.value,
      'command': command,
    };
    if (args.isNotEmpty) {
      result['args'] = args;
    }
    if (errorMessage != null) {
      result['error_message'] = errorMessage;
    }
    return result;
  }
}

/// Execute Dart script.
class ScriptAction implements CustomCommandAction {
  @override
  final CustomCommandActionType type = CustomCommandActionType.script;

  /// Path to Dart script file.
  final String path;

  /// Arguments to pass to the script.
  final List<String> args;

  @override
  final String? errorMessage;

  ScriptAction({
    required this.path,
    this.args = const [],
    this.errorMessage,
  });

  factory ScriptAction.fromYaml(YamlMap data) {
    final args = data['args'] as YamlList?;
    return ScriptAction(
      path: data['path'] as String? ??
          (throw Exception('script action requires "path" field')),
      args: args?.map((e) => e.toString()).toList() ?? [],
      errorMessage: data['error_message'] as String?,
    );
  }

  @override
  Map<String, dynamic> toYaml() {
    final result = <String, dynamic>{
      'type': type.value,
      'path': path,
    };
    if (args.isNotEmpty) {
      result['args'] = args;
    }
    if (errorMessage != null) {
      result['error_message'] = errorMessage;
    }
    return result;
  }
}

/// Check git branch and optionally switch to it.
class CheckGitBranchAction implements CustomCommandAction {
  @override
  final CustomCommandActionType type = CustomCommandActionType.checkGitBranch;

  /// Expected branch name.
  final String branch;

  /// Whether to switch to branch if not on it.
  final bool autoSwitch;

  @override
  final String? errorMessage;

  CheckGitBranchAction({
    required this.branch,
    this.autoSwitch = true,
    this.errorMessage,
  });

  factory CheckGitBranchAction.fromYaml(YamlMap data) {
    return CheckGitBranchAction(
      branch: data['branch'] as String? ??
          (throw Exception('check_git_branch action requires "branch" field')),
      autoSwitch: data['auto_switch'] as bool? ?? true,
      errorMessage: data['error_message'] as String?,
    );
  }

  @override
  Map<String, dynamic> toYaml() {
    final result = <String, dynamic>{
      'type': type.value,
      'branch': branch,
    };
    if (!autoSwitch) {
      result['auto_switch'] = autoSwitch;
    }
    if (errorMessage != null) {
      result['error_message'] = errorMessage;
    }
    return result;
  }
}

/// Check that git working directory is clean.
class CheckGitCleanAction implements CustomCommandAction {
  @override
  final CustomCommandActionType type = CustomCommandActionType.checkGitClean;

  @override
  final String? errorMessage;

  CheckGitCleanAction({
    this.errorMessage,
  });

  factory CheckGitCleanAction.fromYaml(YamlMap data) {
    return CheckGitCleanAction(
      errorMessage: data['error_message'] as String?,
    );
  }

  @override
  Map<String, dynamic> toYaml() {
    final result = <String, dynamic>{
      'type': type.value,
    };
    if (errorMessage != null) {
      result['error_message'] = errorMessage;
    }
    return result;
  }
}

/// Change working directory.
class ChangeDirAction implements CustomCommandAction {
  @override
  final CustomCommandActionType type = CustomCommandActionType.changeDir;

  /// Directory path to change to.
  final String path;

  @override
  final String? errorMessage;

  ChangeDirAction({
    required this.path,
    this.errorMessage,
  });

  factory ChangeDirAction.fromYaml(YamlMap data) {
    return ChangeDirAction(
      path: data['path'] as String? ??
          (throw Exception('change_dir action requires "path" field')),
      errorMessage: data['error_message'] as String?,
    );
  }

  @override
  Map<String, dynamic> toYaml() {
    final result = <String, dynamic>{
      'type': type.value,
      'path': path,
    };
    if (errorMessage != null) {
      result['error_message'] = errorMessage;
    }
    return result;
  }
}

/// Delete a file or directory.
class DeleteFileAction implements CustomCommandAction {
  @override
  final CustomCommandActionType type = CustomCommandActionType.deleteFile;

  /// Path to file or directory to delete.
  final String path;

  /// Whether to delete recursively (for directories).
  final bool recursive;

  /// Whether to ignore if file doesn't exist.
  final bool ignoreNotFound;

  @override
  final String? errorMessage;

  DeleteFileAction({
    required this.path,
    this.recursive = false,
    this.ignoreNotFound = true,
    this.errorMessage,
  });

  factory DeleteFileAction.fromYaml(YamlMap data) {
    return DeleteFileAction(
      path: data['path'] as String? ??
          (throw Exception('delete_file action requires "path" field')),
      recursive: data['recursive'] as bool? ?? false,
      ignoreNotFound: data['ignore_not_found'] as bool? ?? true,
      errorMessage: data['error_message'] as String?,
    );
  }

  @override
  Map<String, dynamic> toYaml() {
    final result = <String, dynamic>{
      'type': type.value,
      'path': path,
    };
    if (recursive) {
      result['recursive'] = recursive;
    }
    if (!ignoreNotFound) {
      result['ignore_not_found'] = ignoreNotFound;
    }
    if (errorMessage != null) {
      result['error_message'] = errorMessage;
    }
    return result;
  }
}

/// Check if file or directory exists.
class CheckFileExistsAction implements CustomCommandAction {
  @override
  final CustomCommandActionType type = CustomCommandActionType.checkFileExists;

  /// Path to file or directory to check.
  final String path;

  /// Whether file should exist (true) or not exist (false).
  final bool shouldExist;

  @override
  final String? errorMessage;

  CheckFileExistsAction({
    required this.path,
    this.shouldExist = true,
    this.errorMessage,
  });

  factory CheckFileExistsAction.fromYaml(YamlMap data) {
    return CheckFileExistsAction(
      path: data['path'] as String? ??
          (throw Exception('check_file_exists action requires "path" field')),
      shouldExist: data['should_exist'] as bool? ?? true,
      errorMessage: data['error_message'] as String?,
    );
  }

  @override
  Map<String, dynamic> toYaml() {
    final result = <String, dynamic>{
      'type': type.value,
      'path': path,
    };
    if (!shouldExist) {
      result['should_exist'] = shouldExist;
    }
    if (errorMessage != null) {
      result['error_message'] = errorMessage;
    }
    return result;
  }
}

/// Copy a file.
class CopyFileAction implements CustomCommandAction {
  @override
  final CustomCommandActionType type = CustomCommandActionType.copyFile;

  /// Source file path.
  final String source;

  /// Destination file path.
  final String destination;

  /// Whether to overwrite if destination exists.
  final bool overwrite;

  @override
  final String? errorMessage;

  CopyFileAction({
    required this.source,
    required this.destination,
    this.overwrite = false,
    this.errorMessage,
  });

  factory CopyFileAction.fromYaml(YamlMap data) {
    return CopyFileAction(
      source: data['source'] as String? ??
          (throw Exception('copy_file action requires "source" field')),
      destination: data['destination'] as String? ??
          (throw Exception('copy_file action requires "destination" field')),
      overwrite: data['overwrite'] as bool? ?? false,
      errorMessage: data['error_message'] as String?,
    );
  }

  @override
  Map<String, dynamic> toYaml() {
    final result = <String, dynamic>{
      'type': type.value,
      'source': source,
      'destination': destination,
    };
    if (overwrite) {
      result['overwrite'] = overwrite;
    }
    if (errorMessage != null) {
      result['error_message'] = errorMessage;
    }
    return result;
  }
}

/// Rename a file.
class RenameFileAction implements CustomCommandAction {
  @override
  final CustomCommandActionType type = CustomCommandActionType.renameFile;

  /// Current file path.
  final String oldPath;

  /// New file path.
  final String newPath;

  @override
  final String? errorMessage;

  RenameFileAction({
    required this.oldPath,
    required this.newPath,
    this.errorMessage,
  });

  factory RenameFileAction.fromYaml(YamlMap data) {
    return RenameFileAction(
      oldPath: data['old_path'] as String? ??
          (throw Exception('rename_file action requires "old_path" field')),
      newPath: data['new_path'] as String? ??
          (throw Exception('rename_file action requires "new_path" field')),
      errorMessage: data['error_message'] as String?,
    );
  }

  @override
  Map<String, dynamic> toYaml() {
    final result = <String, dynamic>{
      'type': type.value,
      'old_path': oldPath,
      'new_path': newPath,
    };
    if (errorMessage != null) {
      result['error_message'] = errorMessage;
    }
    return result;
  }
}

/// Move a file.
class MoveFileAction implements CustomCommandAction {
  @override
  final CustomCommandActionType type = CustomCommandActionType.moveFile;

  /// Source file path.
  final String source;

  /// Destination file path.
  final String destination;

  @override
  final String? errorMessage;

  MoveFileAction({
    required this.source,
    required this.destination,
    this.errorMessage,
  });

  factory MoveFileAction.fromYaml(YamlMap data) {
    return MoveFileAction(
      source: data['source'] as String? ??
          (throw Exception('move_file action requires "source" field')),
      destination: data['destination'] as String? ??
          (throw Exception('move_file action requires "destination" field')),
      errorMessage: data['error_message'] as String?,
    );
  }

  @override
  Map<String, dynamic> toYaml() {
    final result = <String, dynamic>{
      'type': type.value,
      'source': source,
      'destination': destination,
    };
    if (errorMessage != null) {
      result['error_message'] = errorMessage;
    }
    return result;
  }
}

/// Create a file with optional content.
class CreateFileAction implements CustomCommandAction {
  @override
  final CustomCommandActionType type = CustomCommandActionType.createFile;

  /// File path to create.
  final String path;

  /// File content (optional).
  final String? content;

  /// Whether to overwrite if file exists.
  final bool overwrite;

  @override
  final String? errorMessage;

  CreateFileAction({
    required this.path,
    this.content,
    this.overwrite = false,
    this.errorMessage,
  });

  factory CreateFileAction.fromYaml(YamlMap data) {
    return CreateFileAction(
      path: data['path'] as String? ??
          (throw Exception('create_file action requires "path" field')),
      content: data['content'] as String?,
      overwrite: data['overwrite'] as bool? ?? false,
      errorMessage: data['error_message'] as String?,
    );
  }

  @override
  Map<String, dynamic> toYaml() {
    final result = <String, dynamic>{
      'type': type.value,
      'path': path,
    };
    if (content != null) {
      result['content'] = content;
    }
    if (overwrite) {
      result['overwrite'] = overwrite;
    }
    if (errorMessage != null) {
      result['error_message'] = errorMessage;
    }
    return result;
  }
}

/// Create a directory.
class CreateDirAction implements CustomCommandAction {
  @override
  final CustomCommandActionType type = CustomCommandActionType.createDir;

  /// Directory path to create.
  final String path;

  /// Whether to create parent directories.
  final bool recursive;

  @override
  final String? errorMessage;

  CreateDirAction({
    required this.path,
    this.recursive = true,
    this.errorMessage,
  });

  factory CreateDirAction.fromYaml(YamlMap data) {
    return CreateDirAction(
      path: data['path'] as String? ??
          (throw Exception('create_dir action requires "path" field')),
      recursive: data['recursive'] as bool? ?? true,
      errorMessage: data['error_message'] as String?,
    );
  }

  @override
  Map<String, dynamic> toYaml() {
    final result = <String, dynamic>{
      'type': type.value,
      'path': path,
    };
    if (!recursive) {
      result['recursive'] = recursive;
    }
    if (errorMessage != null) {
      result['error_message'] = errorMessage;
    }
    return result;
  }
}

/// Delete a directory.
class DeleteDirAction implements CustomCommandAction {
  @override
  final CustomCommandActionType type = CustomCommandActionType.deleteDir;

  /// Directory path to delete.
  final String path;

  /// Whether to delete recursively.
  final bool recursive;

  /// Whether to ignore if directory doesn't exist.
  final bool ignoreNotFound;

  @override
  final String? errorMessage;

  DeleteDirAction({
    required this.path,
    this.recursive = true,
    this.ignoreNotFound = true,
    this.errorMessage,
  });

  factory DeleteDirAction.fromYaml(YamlMap data) {
    return DeleteDirAction(
      path: data['path'] as String? ??
          (throw Exception('delete_dir action requires "path" field')),
      recursive: data['recursive'] as bool? ?? true,
      ignoreNotFound: data['ignore_not_found'] as bool? ?? true,
      errorMessage: data['error_message'] as String?,
    );
  }

  @override
  Map<String, dynamic> toYaml() {
    final result = <String, dynamic>{
      'type': type.value,
      'path': path,
    };
    if (!recursive) {
      result['recursive'] = recursive;
    }
    if (!ignoreNotFound) {
      result['ignore_not_found'] = ignoreNotFound;
    }
    if (errorMessage != null) {
      result['error_message'] = errorMessage;
    }
    return result;
  }
}

/// Rename a directory.
class RenameDirAction implements CustomCommandAction {
  @override
  final CustomCommandActionType type = CustomCommandActionType.renameDir;

  /// Current directory path.
  final String oldPath;

  /// New directory path.
  final String newPath;

  @override
  final String? errorMessage;

  RenameDirAction({
    required this.oldPath,
    required this.newPath,
    this.errorMessage,
  });

  factory RenameDirAction.fromYaml(YamlMap data) {
    return RenameDirAction(
      oldPath: data['old_path'] as String? ??
          (throw Exception('rename_dir action requires "old_path" field')),
      newPath: data['new_path'] as String? ??
          (throw Exception('rename_dir action requires "new_path" field')),
      errorMessage: data['error_message'] as String?,
    );
  }

  @override
  Map<String, dynamic> toYaml() {
    final result = <String, dynamic>{
      'type': type.value,
      'old_path': oldPath,
      'new_path': newPath,
    };
    if (errorMessage != null) {
      result['error_message'] = errorMessage;
    }
    return result;
  }
}

/// Replace text in file.
class ReplaceInFileAction implements CustomCommandAction {
  @override
  final CustomCommandActionType type = CustomCommandActionType.replaceInFile;

  /// Path to file.
  final String path;

  /// Text or pattern to find.
  final String find;

  /// Replacement text.
  final String replace;

  /// Whether to use regex matching.
  final bool regex;

  @override
  final String? errorMessage;

  ReplaceInFileAction({
    required this.path,
    required this.find,
    required this.replace,
    this.regex = false,
    this.errorMessage,
  });

  factory ReplaceInFileAction.fromYaml(YamlMap data) {
    return ReplaceInFileAction(
      path: data['path'] as String? ??
          (throw Exception('replace_in_file action requires "path" field')),
      find: data['find'] as String? ??
          (throw Exception('replace_in_file action requires "find" field')),
      replace: data['replace'] as String? ??
          (throw Exception('replace_in_file action requires "replace" field')),
      regex: data['regex'] as bool? ?? false,
      errorMessage: data['error_message'] as String?,
    );
  }

  @override
  Map<String, dynamic> toYaml() {
    final result = <String, dynamic>{
      'type': type.value,
      'path': path,
      'find': find,
      'replace': replace,
    };
    if (regex) {
      result['regex'] = regex;
    }
    if (errorMessage != null) {
      result['error_message'] = errorMessage;
    }
    return result;
  }
}

/// Append text to file.
class AppendToFileAction implements CustomCommandAction {
  @override
  final CustomCommandActionType type = CustomCommandActionType.appendToFile;

  /// Path to file.
  final String path;

  /// Content to append.
  final String content;

  /// Create file if it doesn't exist.
  final bool createIfMissing;

  @override
  final String? errorMessage;

  AppendToFileAction({
    required this.path,
    required this.content,
    this.createIfMissing = true,
    this.errorMessage,
  });

  factory AppendToFileAction.fromYaml(YamlMap data) {
    return AppendToFileAction(
      path: data['path'] as String? ??
          (throw Exception('append_to_file action requires "path" field')),
      content: data['content'] as String? ??
          (throw Exception('append_to_file action requires "content" field')),
      createIfMissing: data['create_if_missing'] as bool? ?? true,
      errorMessage: data['error_message'] as String?,
    );
  }

  @override
  Map<String, dynamic> toYaml() {
    final result = <String, dynamic>{
      'type': type.value,
      'path': path,
      'content': content,
    };
    if (!createIfMissing) {
      result['create_if_missing'] = createIfMissing;
    }
    if (errorMessage != null) {
      result['error_message'] = errorMessage;
    }
    return result;
  }
}

/// Prepend text to file.
class PrependToFileAction implements CustomCommandAction {
  @override
  final CustomCommandActionType type = CustomCommandActionType.prependToFile;

  /// Path to file.
  final String path;

  /// Content to prepend.
  final String content;

  /// Create file if it doesn't exist.
  final bool createIfMissing;

  @override
  final String? errorMessage;

  PrependToFileAction({
    required this.path,
    required this.content,
    this.createIfMissing = true,
    this.errorMessage,
  });

  factory PrependToFileAction.fromYaml(YamlMap data) {
    return PrependToFileAction(
      path: data['path'] as String? ??
          (throw Exception('prepend_to_file action requires "path" field')),
      content: data['content'] as String? ??
          (throw Exception('prepend_to_file action requires "content" field')),
      createIfMissing: data['create_if_missing'] as bool? ?? true,
      errorMessage: data['error_message'] as String?,
    );
  }

  @override
  Map<String, dynamic> toYaml() {
    final result = <String, dynamic>{
      'type': type.value,
      'path': path,
      'content': content,
    };
    if (!createIfMissing) {
      result['create_if_missing'] = createIfMissing;
    }
    if (errorMessage != null) {
      result['error_message'] = errorMessage;
    }
    return result;
  }
}

/// Print message to console.
class PrintAction implements CustomCommandAction {
  @override
  final CustomCommandActionType type = CustomCommandActionType.print;

  /// Message to print.
  final String message;

  /// Message level (info, warning, error).
  final String level;

  @override
  final String? errorMessage;

  PrintAction({
    required this.message,
    this.level = 'info',
    this.errorMessage,
  });

  factory PrintAction.fromYaml(YamlMap data) {
    return PrintAction(
      message: data['message'] as String? ??
          (throw Exception('print action requires "message" field')),
      level: data['level'] as String? ?? 'info',
      errorMessage: data['error_message'] as String?,
    );
  }

  @override
  Map<String, dynamic> toYaml() {
    final result = <String, dynamic>{
      'type': type.value,
      'message': message,
    };
    if (level != 'info') {
      result['level'] = level;
    }
    if (errorMessage != null) {
      result['error_message'] = errorMessage;
    }
    return result;
  }
}

/// Wait for specified duration.
class WaitAction implements CustomCommandAction {
  @override
  final CustomCommandActionType type = CustomCommandActionType.wait;

  /// Duration in milliseconds.
  final int milliseconds;

  /// Optional message to display.
  final String? message;

  @override
  final String? errorMessage;

  WaitAction({
    required this.milliseconds,
    this.message,
    this.errorMessage,
  });

  factory WaitAction.fromYaml(YamlMap data) {
    return WaitAction(
      milliseconds: data['milliseconds'] as int? ??
          (throw Exception('wait action requires "milliseconds" field')),
      message: data['message'] as String?,
      errorMessage: data['error_message'] as String?,
    );
  }

  @override
  Map<String, dynamic> toYaml() {
    final result = <String, dynamic>{
      'type': type.value,
      'milliseconds': milliseconds,
    };
    if (message != null) {
      result['message'] = message;
    }
    if (errorMessage != null) {
      result['error_message'] = errorMessage;
    }
    return result;
  }
}

/// Check current platform.
class CheckPlatformAction implements CustomCommandAction {
  @override
  final CustomCommandActionType type = CustomCommandActionType.checkPlatform;

  /// Expected platform (macos, linux, windows).
  final String platform;

  @override
  final String? errorMessage;

  CheckPlatformAction({
    required this.platform,
    this.errorMessage,
  });

  factory CheckPlatformAction.fromYaml(YamlMap data) {
    return CheckPlatformAction(
      platform: data['platform'] as String? ??
          (throw Exception('check_platform action requires "platform" field')),
      errorMessage: data['error_message'] as String?,
    );
  }

  @override
  Map<String, dynamic> toYaml() {
    final result = <String, dynamic>{
      'type': type.value,
      'platform': platform,
    };
    if (errorMessage != null) {
      result['error_message'] = errorMessage;
    }
    return result;
  }
}

/// Create archive from files or directory.
class CreateArchiveAction implements CustomCommandAction {
  @override
  final CustomCommandActionType type = CustomCommandActionType.createArchive;

  /// Source path (file or directory).
  final String source;

  /// Destination archive path.
  final String destination;

  /// Archive format (zip or tar.gz).
  final String format;

  @override
  final String? errorMessage;

  CreateArchiveAction({
    required this.source,
    required this.destination,
    this.format = 'zip',
    this.errorMessage,
  });

  factory CreateArchiveAction.fromYaml(YamlMap data) {
    return CreateArchiveAction(
      source: data['source'] as String? ??
          (throw Exception('create_archive action requires "source" field')),
      destination: data['destination'] as String? ??
          (throw Exception(
              'create_archive action requires "destination" field')),
      format: data['format'] as String? ?? 'zip',
      errorMessage: data['error_message'] as String?,
    );
  }

  @override
  Map<String, dynamic> toYaml() {
    final result = <String, dynamic>{
      'type': type.value,
      'source': source,
      'destination': destination,
    };
    if (format != 'zip') {
      result['format'] = format;
    }
    if (errorMessage != null) {
      result['error_message'] = errorMessage;
    }
    return result;
  }
}

/// Extract archive.
class ExtractArchiveAction implements CustomCommandAction {
  @override
  final CustomCommandActionType type = CustomCommandActionType.extractArchive;

  /// Source archive path.
  final String source;

  /// Destination directory.
  final String destination;

  @override
  final String? errorMessage;

  ExtractArchiveAction({
    required this.source,
    required this.destination,
    this.errorMessage,
  });

  factory ExtractArchiveAction.fromYaml(YamlMap data) {
    return ExtractArchiveAction(
      source: data['source'] as String? ??
          (throw Exception('extract_archive action requires "source" field')),
      destination: data['destination'] as String? ??
          (throw Exception(
              'extract_archive action requires "destination" field')),
      errorMessage: data['error_message'] as String?,
    );
  }

  @override
  Map<String, dynamic> toYaml() {
    final result = <String, dynamic>{
      'type': type.value,
      'source': source,
      'destination': destination,
    };
    if (errorMessage != null) {
      result['error_message'] = errorMessage;
    }
    return result;
  }
}

/// Type of custom command action.
enum CustomCommandActionType {
  exec('exec', 'Execute shell command'),
  alex('alex', 'Execute alex command'),
  script('script', 'Execute Dart script'),
  checkGitBranch('check_git_branch', 'Check/switch git branch'),
  checkGitClean('check_git_clean', 'Check git is clean'),
  changeDir('change_dir', 'Change directory'),
  deleteFile('delete_file', 'Delete file'),
  checkFileExists('check_file_exists', 'Check file exists'),
  copyFile('copy_file', 'Copy file'),
  renameFile('rename_file', 'Rename file'),
  moveFile('move_file', 'Move file'),
  createFile('create_file', 'Create file'),
  createDir('create_dir', 'Create directory'),
  deleteDir('delete_dir', 'Delete directory'),
  renameDir('rename_dir', 'Rename directory'),
  replaceInFile('replace_in_file', 'Replace text in file'),
  appendToFile('append_to_file', 'Append to file'),
  prependToFile('prepend_to_file', 'Prepend to file'),
  print('print', 'Print message'),
  wait('wait', 'Wait/sleep'),
  checkPlatform('check_platform', 'Check platform'),
  createArchive('create_archive', 'Create archive'),
  extractArchive('extract_archive', 'Extract archive');

  const CustomCommandActionType(this.value, this.description);

  /// YAML serialization value
  final String value;

  /// Command description
  final String description;

  static final Map<String, CustomCommandActionType> _values = {
    for (final e in values) e.value: e
  };

  static CustomCommandActionType fromString(String value) {
    final result = _values[value];
    if (result == null) {
      throw ArgumentError('Unknown action type: $value');
    }
    return result;
  }
}
