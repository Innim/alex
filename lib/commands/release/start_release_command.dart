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

    final changeLog = await upgradeChangeLog(ver);

    print("Change log: \n" + changeLog);

    // await _delay();
    print('completed');
    print('Waiting for change log...');

    await getReleaseNotes(changeLog);

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

  Future<String> upgradeChangeLog(String ver) async {
    final file = File("CHANGELOG.md");
    var contents = await file.readAsString();
    if (contents.startsWith("## Next release")) {
      // up to date
      if (contents.contains(ver)) {
        return getCurrentChangeLog(contents);
      }

      final now = DateFormat("yyyy-MM-dd").format(DateTime.now());
      contents = contents.replaceFirst(
          "## Next release", "## Next release\n\n## $ver - $now");

      await file.writeAsString(contents);

      return getCurrentChangeLog(contents);
    } else {
      return fail(
          "Unable to upgrade CHANGELOG.md file due to unknown structure");
    }
  }

  String getCurrentChangeLog(String contents) {
    final marker = "## v";
    final curIndex = contents.indexOf(marker);
    final lastIndex = contents.indexOf(marker, curIndex + 1);

    if (lastIndex != -1) {
      return contents.substring(curIndex, lastIndex);
    }

    return contents.substring(curIndex);
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

  Future<void> getReleaseNotes(String changeLog) async {
    final port = 4024;
    final data = getRawReleaseNotes(port, changeLog);

    runBrowser("http://localhost:$port");

    return await data;
  }

  Future<void> getRawReleaseNotes(int port, String changeLog) async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, port);
    final langs = ["ru", "en", "ge"];
    final map = {for (final ln in langs) ln: ""};

    final completer = Completer<String>();

    await for (HttpRequest request in server) {
      try {
        final response = request.response;

        print("Request [${request.uri.toString()}]");

        var numStrings = 0;

        for (final kv in request.uri.queryParameters.entries) {
          if (map.containsKey(kv.key) &&
              kv.value != null &&
              kv.value.isNotEmpty) {
            map[kv.key] = kv.value;
            ++numStrings;
          }
        }

        if (map.length == numStrings) {
          completer.complete(changeLog);
          map.forEach((key, value) {
            print("key: $key; value: $value");
          });
          response.writeln("Succeed");
          await response.close();
          break;
        } else {
          final itemTemplate = await readTemplate("release_note");
          final formTemplate = await readTemplate("release_notes");

          final items = map.entries
              .map((kv) => itemTemplate
                  .replaceAll("%name%", kv.key)
                  .replaceAll("%text%", kv.value))
              .join("\n");

          var text = formTemplate
              .replaceAll("%change-log%", changeLog)
              .replaceAll("%items%", items);

          response.headers.contentType = ContentType.html;
          response.statusCode = HttpStatus.ok;
          response.writeln(text);
          await response.close();
        }
      } catch (e, s) {
        print('Handle request error: $e\n$s');
      }
    }

    return completer.future;
  }

  Future<String> readTemplate(String fileName) {
    return readPackageFile("lib/assets/commands/release/$fileName.html");
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
