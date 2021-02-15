import 'dart:io';
import 'package:alex/internal/print.dart' as print;

/// Abstraction to access io functions.
abstract class FileSystem {
  /// Reads file contents.
  Future<String> readString(String path);

  /// Writes file contents.
  Future<void> writeString(String path, String contents);

  /// Creates a file.
  Future<void> createFile(String path, {bool recursive = false});

  /// Checks whether the file system entity with this path exists.
  Future<bool> existsFile(String path);
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

  @override
  Future<bool> existsFile(String path) => File(path).exists();
}

/// File system that redirects dump every command to console.
///
/// Nothing will be made with any file.
class ConsoleFileSystem extends FileSystem {
  @override
  Future<void> createFile(String path, {bool recursive = false}) async {
    print.info("fs.createFile $path, recursive: $recursive");
  }

  @override
  Future<String> readString(String path) async {
    print.info("fs.readString $path");
    return "";
  }

  @override
  Future<void> writeString(String path, String contents) async {
    print.info("fs.writeString $path, contents: $contents");
  }

  @override
  Future<bool> existsFile(String path) {
    print.info("fs.existsFile $path");
    return Future.value(false);
  }
}
