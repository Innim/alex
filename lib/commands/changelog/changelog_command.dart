import 'package:alex/runner/alex_command.dart';

import 'update_issue_links_command.dart';

class ChangelogCommand extends AlexCommand {
  ChangelogCommand()
      : super('changelog', 'Work with CHANGELOG.md', const ['cl']) {
    addSubcommand(UpdateIssueLinksCommand());
  }

  @override
  Future<int> doRun() async {
    printUsage();
    return 0;
  }
}
