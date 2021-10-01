import 'package:alex/src/fs/fs.dart';
import 'package:alex/src/git/git.dart';
import 'package:alex/internal/print.dart' as print;

/// Demo git implementation.
class DemoGit extends Git {
  @override
  String execute(List<String> args, String desc) {
    print.info("[demo] git ${args.join(" ")}");

    switch (args[0]) {
      case "remote":
        return "https://github.com/demo/demo.git";
      case "branch":
        if (args[1] == '-a') {
          return '''
  feature/612.subscriptions
  feature/615.up-version-fb
  feature/615.up-version-fb-clone
  remotes/other/feature/612.subscriptions
  remotes/origin/feature/612.subscriptions
  remotes/origin/feature/614.redmi-update-fix
  remotes/origin/feature/615.up-version-fb
''';
        }
    }

    return "";
  }
}

/// Demo file system implementation.
class DemoFileSystem extends FileSystem {
  @override
  Future<void> createFile(String path, {bool recursive = false}) async {
    print.info("createFile $path recursive: $recursive");
  }

  @override
  Future<bool> existsFile(String path) {
    final result = ['CHANGELOG.md'].contains(path);

    print.info("existsFile $path -> $result");
    return Future.value(result);
  }

  @override
  Future<String> readString(String path) async {
    print.info("readString $path");

    if (path.contains('CHANGELOG.md')) {
      return '''
## Next release

### Added

- Some new feature

## v0.3.27+4041 - 2020-10-02

## Added
- Cool feature

## Fixed
- NPE when open settings
''';
    }

    return '';
  }

  @override
  Future<void> writeString(String path, String contents) async {
    print.info("writeString $path contents: $contents");
  }
}
