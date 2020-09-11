import 'dart:async';
import 'dart:io';

import 'package:alex/commands/release/git.dart';
import 'package:alex/runner/alex_command.dart';
import 'package:alex/src/pub_spec.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart';
import 'package:version/version.dart';

/// Команда запуска релизной сборки.
class StartReleaseCommand extends AlexCommand {
  String _packageDir;

  StartReleaseCommand() : super("start", "Start new release");

  @override
  Future<int> run() async {
    // ensureCleanStatus();
    //
    // if (gitGetCurrentBranch() != branchDevelop) {
    //   gitCheckout(branchDevelop);
    // }
    //
    // ensureRemoteUrl();
    //
    // gitPull();
    //
    // ensureCleanStatus();
    //
    final version = Spec.pub().version;
    final ver = v(version);

    //
    // print('Start new release <$ver>');
    // gitflowReleaseStart(ver);

    print('Creating release branch...');
    // await _delay();
    print('completed');

    print('Upgrading CHANGELOG.md...');

    await upgradeChangeLog(ver);
    return 0;

    // await _delay();
    print('completed');
    print('Waiting for change log...');

    final changeLog = await getChangeLog();

    print('Change log: ' + changeLog);

    await _delay(15);
    print('completed');
    print('Finishing release branch...');
    await _delay();
    print('completed');
    print('Upgrading version...');
    await _delay();
    print('completed');

    return 0;
  }

  Future<void> upgradeChangeLog(String ver) async {
    final file = File("CHANGELOG.md");
    var contents = await file.readAsString();
    if (contents.startsWith("## Next release")) {
      // up to date
      if (contents.contains(ver)) {
        return;
      }

      final now = DateFormat("yyyy-MM-dd").format(DateTime.now());
      contents = contents.replaceFirst(
          "## Next release", "## Next release\n\n## $ver - $now");

      await file.writeAsString(contents);
    } else {
      return fail(
          "Unable to upgrade CHANGELOG.md file due to unknown structure");
    }
  }

  Future<void> _delay([int timeout = 1]) {
    return Future<void>.delayed(Duration(seconds: timeout));
  }

  void runBrowser(String url) {
    var fail = false;
    switch (Platform.operatingSystem) {
      case 'linux':
        Process.run('x-www-browser', [url]);
        break;
      case 'macos':
        Process.run('open', [url]);
        break;
      case 'windows':
        Process.run('explorer', [url]);
        break;
      default:
        fail = true;
        break;
    }
  }

  Future<String> getChangeLog() async {
    final port = 4024;
    final host = 'http://localhost:$port';

    final data = getRawChangeLog(host, port);

    runBrowser(host);

    return await data;
  }

  Future<String> getRawChangeLog(String host, int port) async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, port);
    print('Listening on $host');

    final completer = Completer<String>();
    final changeLogTemplate =
        await readPackageFile("lib/assets/commands/release/change_log.html");

    var text = changeLogTemplate.replaceAll('%action%', host);

    await for (HttpRequest request in server) {
      try {
        final response = request.response;

        print("Request [${request.uri.toString()}]");

        var changeLog = request.uri.queryParameters['changelog'];

        if (changeLog != null && changeLog.isNotEmpty) {
          completer.complete(changeLog);
          response.writeln("Succeed");
          await response.close();
          break;
        } else {
          response.headers.contentType = ContentType.html;
          response.statusCode = HttpStatus.ok;
          response.writeln(text);
          await response.close();
        }
      } catch (e) {
        print('Handle request error: $e');
      }
    }

    return completer.future;
  }

  Future<String> readPackageFile(String fileName) async {
    final packageDir = getPackageDir();
    final filePath = join(packageDir, fileName);
    return File(filePath).readAsString();
  }

  String getPackageDir() {
    return _packageDir ??=
        Directory.fromUri(Platform.script).parent.parent.path;
  }

  String v(Version version) {
    return "v$version";
  }
}
