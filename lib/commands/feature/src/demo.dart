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
  remotes/origin/feature/612.subscriptions
  remotes/origin/feature/614.redmi-update-fix
  remotes/origin/feature/615.up-version-fb
''';
        }
    }

    return "";
  }
}
