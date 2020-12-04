import 'dart:io';

/// Abstraction to access io functions.
abstract class FileSystem {
  /// Reads file contents.
  Future<String> readString(String path);

  /// Writes file contents.
  Future<void> writeString(String path, String contents);

  /// Creates a file.
  Future<void> createFile(String path, {bool recursive = false});
}

/// File system implementation.
class IOFileSystem extends FileSystem {
  @override
  Future<String> readString(String path) => File(path).readAsString();

  @override
  Future<void> writeString(String path, String contents) =>
      File(path).writeAsString(contents);

  @override
  Future<void> createFile(String path, {bool recursive = false}) =>
      File(path).create(recursive: recursive);
}

/// File system that redirects dump every command to console.
///
/// Nothing will be made with any file.
class ConsoleFileSystem extends FileSystem {
  @override
  Future<void> createFile(String path, {bool recursive = false}) async {
    print("fs.createFile $path, recursive: $recursive");
  }

  @override
  Future<String> readString(String path) async {
    print("fs.readString $path");
    return "";
  }

  @override
  Future<void> writeString(String path, String contents) async {
    print("fs.writeString $path, contents: $contents");
  }
}
