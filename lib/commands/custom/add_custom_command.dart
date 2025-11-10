import 'dart:io';

import 'package:alex/runner/alex_command.dart';
import 'package:alex/src/custom_commands/custom_command_action.dart';
import 'package:alex/src/custom_commands/custom_command_argument.dart';
import 'package:alex/src/custom_commands/custom_command_config.dart';

/// Add a new custom command.
class AddCustomCommand extends AlexCommand {
  AddCustomCommand() : super('add', 'Add a new custom command.');

  @override
  Future<int> doRun() async {
    final config = CustomCommandsConfig.instance;

    printInfo('Add new custom command');
    printInfo('');

    // Get command name
    final name = _prompt('Command name');
    if (name.isEmpty) {
      printError('Command name is required');
      return 1;
    }

    if (config.hasCommand(name)) {
      printError('Command already exists: $name');
      return 1;
    }

    // Get description
    final description = _prompt('Description (optional)');

    // Get aliases
    final aliasesStr = _prompt('Aliases (comma-separated, optional)');
    final aliases = aliasesStr.isNotEmpty
        ? aliasesStr.split(',').map((e) => e.trim()).toList()
        : <String>[];

    // Get arguments
    final arguments = <CustomCommandArgument>[];
    while (true) {
      final addArg = _prompt('Add argument? (y/n)', defaultValue: 'n');
      if (addArg.toLowerCase() != 'y') break;

      final arg = _promptArgument();
      if (arg != null) {
        arguments.add(arg);
      }
    }

    // Get actions
    final actions = <CustomCommandAction>[];
    while (true) {
      final addAction = _prompt('Add action? (y/n)', defaultValue: actions.isEmpty ? 'y' : 'n');
      if (addAction.toLowerCase() != 'y') {
        if (actions.isEmpty) {
          printError('At least one action is required');
          continue;
        }
        break;
      }

      final action = _promptAction();
      if (action != null) {
        actions.add(action);
      }
    }

    if (actions.isEmpty) {
      printError('At least one action is required');
      return 1;
    }

    // Create command definition
    final command = CustomCommandDefinition(
      name: name,
      description: description,
      aliases: aliases,
      arguments: arguments,
      actions: actions,
    );

    try {
      config.addCommand(command);
      config.save();

      printInfo('');
      printInfo('Custom command added: $name');
      printInfo('Config saved to: ${config.getOrCreateConfigPath()}');
      printInfo('');
      printInfo('You can now use it with:');
      printInfo('  alex $name');

      return 0;
    } catch (e) {
      printError('Failed to add command: $e');
      return 1;
    }
  }

  CustomCommandArgument? _promptArgument() {
    printInfo('');
    printInfo('Argument configuration:');

    final name = _prompt('  Argument name');
    if (name.isEmpty) return null;

    printInfo('  Type:');
    final typeStr = _promptChoice('Select type', ['option', 'flag'], defaultValue: 'option');
    final type = typeStr.toLowerCase() == 'flag'
        ? CustomCommandArgumentType.flag
        : CustomCommandArgumentType.option;

    final help = _prompt('  Help text (optional)');
    final abbr = _prompt('  Abbreviation (optional, single char)');
    final defaultValue = _prompt('  Default value (optional)');

    String? allowedStr;
    List<String>? allowed;
    if (type == CustomCommandArgumentType.option) {
      allowedStr = _prompt('  Allowed values (comma-separated, optional)');
      if (allowedStr.isNotEmpty) {
        allowed = allowedStr.split(',').map((e) => e.trim()).toList();
      }
    }

    final requiredStr = _prompt('  Required? (y/n)', defaultValue: 'n');
    final required = requiredStr.toLowerCase() == 'y';

    return CustomCommandArgument(
      name: name,
      type: type,
      help: help.isNotEmpty ? help : null,
      abbr: abbr.isNotEmpty ? abbr : null,
      defaultValue: defaultValue.isNotEmpty ? defaultValue : null,
      allowed: allowed,
      required: required,
    );
  }

  CustomCommandAction? _promptAction() {
    printInfo('');
    printInfo('Action configuration:');
    printInfo('');
    printInfo('Available action types:');

    // Get all action types from enum
    const allTypes = CustomCommandActionType.values;
    for (var i = 0; i < allTypes.length; i++) {
      final type = allTypes[i];
      printInfo('  ${i + 1}. ${type.value} - ${type.description}');
    }
    printInfo('');

    // Prompt with validation loop
    CustomCommandActionType? actionType;
    while (actionType == null) {
      final input = _prompt('  Enter action type number (1-${allTypes.length})', defaultValue: '1');
      final number = int.tryParse(input);

      if (number == null || number < 1 || number > allTypes.length) {
        printError('Invalid number. Please enter a number between 1 and ${allTypes.length}.');
        continue;
      }

      actionType = allTypes[number - 1];
    }

    return _promptActionByType(actionType);
  }

  CustomCommandAction? _promptActionByType(CustomCommandActionType type) {
    switch (type) {
      case CustomCommandActionType.exec:
        return _promptExecAction();
      case CustomCommandActionType.alex:
        return _promptAlexAction();
      case CustomCommandActionType.script:
        return _promptScriptAction();
      case CustomCommandActionType.checkGitBranch:
        return _promptCheckGitBranchAction();
      case CustomCommandActionType.checkGitClean:
        return _promptCheckGitCleanAction();
      case CustomCommandActionType.changeDir:
        return _promptChangeDirAction();
      case CustomCommandActionType.deleteFile:
        return _promptDeleteFileAction();
      case CustomCommandActionType.checkFileExists:
        return _promptCheckFileExistsAction();
      case CustomCommandActionType.copyFile:
        return _promptCopyFileAction();
      case CustomCommandActionType.renameFile:
        return _promptRenameFileAction();
      case CustomCommandActionType.moveFile:
        return _promptMoveFileAction();
      case CustomCommandActionType.createFile:
        return _promptCreateFileAction();
      case CustomCommandActionType.createDir:
        return _promptCreateDirAction();
      case CustomCommandActionType.deleteDir:
        return _promptDeleteDirAction();
      case CustomCommandActionType.renameDir:
        return _promptRenameDirAction();
      case CustomCommandActionType.replaceInFile:
        return _promptReplaceInFileAction();
      case CustomCommandActionType.appendToFile:
        return _promptAppendToFileAction();
      case CustomCommandActionType.prependToFile:
        return _promptPrependToFileAction();
      case CustomCommandActionType.print:
        return _promptPrintAction();
      case CustomCommandActionType.wait:
        return _promptWaitAction();
      case CustomCommandActionType.checkPlatform:
        return _promptCheckPlatformAction();
      case CustomCommandActionType.createArchive:
        return _promptCreateArchiveAction();
      case CustomCommandActionType.extractArchive:
        return _promptExtractArchiveAction();
    }
  }

  ExecAction _promptExecAction() {
    final command = _prompt('  Command');
    final workingDir = _prompt('  Working directory (optional)');

    return ExecAction(
      command: command,
      workingDir: workingDir.isNotEmpty ? workingDir : null,
    );
  }

  AlexAction _promptAlexAction() {
    final command = _prompt('  Alex command (e.g., "code gen")');
    final argsStr = _prompt('  Arguments (space-separated, optional)');

    final args = argsStr.isNotEmpty ? argsStr.split(' ') : <String>[];

    return AlexAction(
      command: command,
      args: args,
    );
  }

  ScriptAction _promptScriptAction() {
    final path = _prompt('  Script path');
    final argsStr = _prompt('  Arguments (space-separated, optional)');

    final args = argsStr.isNotEmpty ? argsStr.split(' ') : <String>[];

    return ScriptAction(
      path: path,
      args: args,
    );
  }

  CheckGitBranchAction _promptCheckGitBranchAction() {
    final branch = _prompt('  Branch name');
    final autoSwitchStr = _prompt('  Auto switch to branch if not on it? (y/n)', defaultValue: 'y');
    final autoSwitch = autoSwitchStr.toLowerCase() == 'y';

    return CheckGitBranchAction(
      branch: branch,
      autoSwitch: autoSwitch,
    );
  }

  CheckGitCleanAction _promptCheckGitCleanAction() {
    return CheckGitCleanAction();
  }

  ChangeDirAction _promptChangeDirAction() {
    final path = _prompt('  Directory path');

    return ChangeDirAction(path: path);
  }

  DeleteFileAction _promptDeleteFileAction() {
    final path = _prompt('  File path to delete');
    final recursiveStr = _prompt('  Delete recursively (for directories)? (y/n)', defaultValue: 'n');
    final recursive = recursiveStr.toLowerCase() == 'y';
    final ignoreNotFoundStr = _prompt('  Ignore if not found? (y/n)', defaultValue: 'y');
    final ignoreNotFound = ignoreNotFoundStr.toLowerCase() == 'y';

    return DeleteFileAction(
      path: path,
      recursive: recursive,
      ignoreNotFound: ignoreNotFound,
    );
  }

  CheckFileExistsAction _promptCheckFileExistsAction() {
    final path = _prompt('  File/directory path to check');
    final shouldExistStr = _prompt('  Should exist? (y=must exist, n=must not exist)', defaultValue: 'y');
    final shouldExist = shouldExistStr.toLowerCase() == 'y';

    return CheckFileExistsAction(
      path: path,
      shouldExist: shouldExist,
    );
  }

  CopyFileAction _promptCopyFileAction() {
    final source = _prompt('  Source file path');
    final destination = _prompt('  Destination file path');
    final overwriteStr = _prompt('  Overwrite if exists? (y/n)', defaultValue: 'n');
    final overwrite = overwriteStr.toLowerCase() == 'y';

    return CopyFileAction(
      source: source,
      destination: destination,
      overwrite: overwrite,
    );
  }

  RenameFileAction _promptRenameFileAction() {
    final oldPath = _prompt('  Current file path');
    final newPath = _prompt('  New file path');

    return RenameFileAction(
      oldPath: oldPath,
      newPath: newPath,
    );
  }

  MoveFileAction _promptMoveFileAction() {
    final source = _prompt('  Source file path');
    final destination = _prompt('  Destination file path');

    return MoveFileAction(
      source: source,
      destination: destination,
    );
  }

  CreateFileAction _promptCreateFileAction() {
    final path = _prompt('  File path to create');
    final content = _prompt('  File content (optional, supports variables)');
    final overwriteStr = _prompt('  Overwrite if exists? (y/n)', defaultValue: 'n');
    final overwrite = overwriteStr.toLowerCase() == 'y';

    return CreateFileAction(
      path: path,
      content: content.isNotEmpty ? content : null,
      overwrite: overwrite,
    );
  }

  CreateDirAction _promptCreateDirAction() {
    final path = _prompt('  Directory path to create');
    final recursiveStr = _prompt('  Create parent directories? (y/n)', defaultValue: 'y');
    final recursive = recursiveStr.toLowerCase() == 'y';

    return CreateDirAction(
      path: path,
      recursive: recursive,
    );
  }

  DeleteDirAction _promptDeleteDirAction() {
    final path = _prompt('  Directory path to delete');
    final recursiveStr = _prompt('  Delete recursively? (y/n)', defaultValue: 'y');
    final recursive = recursiveStr.toLowerCase() == 'y';
    final ignoreNotFoundStr = _prompt('  Ignore if not found? (y/n)', defaultValue: 'y');
    final ignoreNotFound = ignoreNotFoundStr.toLowerCase() == 'y';

    return DeleteDirAction(
      path: path,
      recursive: recursive,
      ignoreNotFound: ignoreNotFound,
    );
  }

  RenameDirAction _promptRenameDirAction() {
    final oldPath = _prompt('  Current directory path');
    final newPath = _prompt('  New directory path');

    return RenameDirAction(
      oldPath: oldPath,
      newPath: newPath,
    );
  }

  ReplaceInFileAction _promptReplaceInFileAction() {
    final path = _prompt('  File path');
    final find = _prompt('  Text/pattern to find');
    final replace = _prompt('  Replacement text');
    final regexStr = _prompt('  Use regex matching? (y/n)', defaultValue: 'n');
    final regex = regexStr.toLowerCase() == 'y';

    return ReplaceInFileAction(
      path: path,
      find: find,
      replace: replace,
      regex: regex,
    );
  }

  AppendToFileAction _promptAppendToFileAction() {
    final path = _prompt('  File path');
    final content = _prompt('  Content to append');
    final createIfMissingStr = _prompt('  Create file if missing? (y/n)', defaultValue: 'y');
    final createIfMissing = createIfMissingStr.toLowerCase() == 'y';

    return AppendToFileAction(
      path: path,
      content: content,
      createIfMissing: createIfMissing,
    );
  }

  PrependToFileAction _promptPrependToFileAction() {
    final path = _prompt('  File path');
    final content = _prompt('  Content to prepend');
    final createIfMissingStr = _prompt('  Create file if missing? (y/n)', defaultValue: 'y');
    final createIfMissing = createIfMissingStr.toLowerCase() == 'y';

    return PrependToFileAction(
      path: path,
      content: content,
      createIfMissing: createIfMissing,
    );
  }

  PrintAction _promptPrintAction() {
    final message = _prompt('  Message to print');

    printInfo('  Level:');
    final level = _promptChoice('Select level', ['info', 'warning', 'error'], defaultValue: 'info');

    return PrintAction(
      message: message,
      level: level,
    );
  }

  WaitAction _promptWaitAction() {
    final millisecondsStr = _prompt('  Duration in milliseconds');
    final milliseconds = int.tryParse(millisecondsStr) ?? 1000;
    final message = _prompt('  Message to display (optional)');

    return WaitAction(
      milliseconds: milliseconds,
      message: message.isNotEmpty ? message : null,
    );
  }

  CheckPlatformAction _promptCheckPlatformAction() {
    printInfo('  Expected platform:');
    final platform = _promptChoice('Select platform', ['macos', 'linux', 'windows'], defaultValue: 'macos');

    return CheckPlatformAction(platform: platform);
  }

  CreateArchiveAction _promptCreateArchiveAction() {
    final source = _prompt('  Source path (file or directory)');
    final destination = _prompt('  Destination archive path');

    printInfo('  Archive format:');
    final format = _promptChoice('Select format', ['zip', 'tar.gz'], defaultValue: 'zip');

    return CreateArchiveAction(
      source: source,
      destination: destination,
      format: format,
    );
  }

  ExtractArchiveAction _promptExtractArchiveAction() {
    final source = _prompt('  Source archive path');
    final destination = _prompt('  Destination directory');

    return ExtractArchiveAction(
      source: source,
      destination: destination,
    );
  }

  // Prompt user to choose from a list of options.
  // User can enter either the option text or its number (1-based).
  String _promptChoice(
    String message,
    List<String> choices, {
    String? defaultValue,
  }) {
    if (choices.isEmpty) {
      throw ArgumentError('choices cannot be empty');
    }

    // Print choices
    for (var i = 0; i < choices.length; i++) {
      printInfo('    ${i + 1}. ${choices[i]}');
    }

    // Determine default index
    final defaultIndex = defaultValue != null && choices.contains(defaultValue)
        ? choices.indexOf(defaultValue) + 1
        : 1;

    while (true) {
      stdout.write('  $message (1-${choices.length}) [$defaultIndex]: ');
      final input = stdin.readLineSync() ?? '';
      final value = input.isEmpty ? defaultIndex.toString() : input.trim();

      // Try to parse as number
      final number = int.tryParse(value);
      if (number != null && number >= 1 && number <= choices.length) {
        return choices[number - 1];
      }

      // Try to find exact match (case-insensitive)
      final lowerValue = value.toLowerCase();
      for (final choice in choices) {
        if (choice.toLowerCase() == lowerValue) {
          return choice;
        }
      }

      printError('Invalid choice. Please enter a number (1-${choices.length}) or one of: ${choices.join(", ")}');
    }
  }

  String _prompt(String message, {String defaultValue = ''}) {
    if (defaultValue.isNotEmpty) {
      stdout.write('$message [$defaultValue]: ');
    } else {
      stdout.write('$message: ');
    }

    final input = stdin.readLineSync() ?? '';
    return input.isEmpty ? defaultValue : input;
  }
}
