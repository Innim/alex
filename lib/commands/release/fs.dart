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
