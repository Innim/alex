import 'package:alex/src/fs/fs.dart';
import 'package:alex/src/git/git.dart';
import 'package:alex/internal/print.dart' as print;
import 'package:path/path.dart' as p;

/// Demo git implementation.
class DemoGit extends Git {
  @override
  String execute(List<String> args, String desc) {
    switch (args[0]) {
      case "remote":
        return "https://github.com/demo/demo.git";
    }

    return "";
  }
}

/// Demo file system implementation.
class DemoFileSystem extends FileSystem {
  final _native = const IOFileSystem();

  @override
  Future<void> createFile(String path, {bool recursive = false}) async {
    print.info("createFile $path recursive: $recursive");
  }

  @override
  Future<String> readString(String path) async {
    if (path.endsWith('html')) {
      return _native.readString(path);
    }

    if (path.contains('pubspec.yaml')) {
      return "name: demo\nversion: 0.3.27+4041";
    }

    if (path.contains('CHANGELOG.md')) {
      return "## Next release\n\n## v0.3.27+4041 - 2020-10-02\n\n## Fixed:\n\n - NPE when open settings";
    }

    return "";
  }

  @override
  Future<void> writeString(String path, String contents) async {
    print.info("writeString $path contents: $contents");
  }

  @override
  Future<bool> existsFile(String path) {
    var result = false;

    if (path.contains('changelog/default/default')) {
      final name = p.withoutExtension(p.basename(path));
      result = !['ru', 'en'].any(name.endsWith);
    }

    print.info("existsFile $path -> $result");
    return Future.value(result);
  }
}
