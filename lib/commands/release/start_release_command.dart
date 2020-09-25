import 'dart:async';
import 'dart:io';

import 'package:alex/commands/release/ci_config.dart';
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
    ensureCleanStatus();

    if (gitGetCurrentBranch() != branchDevelop) {
      gitCheckout(branchDevelop);
    }

    ensureRemoteUrl();

    gitPull();

    ensureCleanStatus();

    final spec = Spec.pub();
    final version = spec.version;
    final ver = v(version);

    print('Start new release <$ver>');
    gitflowReleaseStart(ver);

    print('Creating release branch...');
    // await _delay();
    print('completed');

    print('Upgrading CHANGELOG.md...');

    final changeLog = await upgradeChangeLog(ver);

    print("Change log: \n" + changeLog);

    // await _delay();
    print('completed');
    print('Waiting for change log...');

    await getReleaseNotes(version, changeLog);

    // committing changes
    gitAddAll();
    gitCommit("Changelog and release notes");

    // finishing release
    gitflowReleaseFinish(ver);

    // increment version
    incrementVersion(spec, version);

    gitAddAll();
    gitCommit("Version increment");

    gitPush(branchDevelop);
    gitPush(branchMaster);

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

  Future<void> getReleaseNotes(Version version, String changeLog) async {
    final port = 4024;
    final data = getRawReleaseNotes(port, changeLog);

    runBrowser("http://localhost:$port");

    final entries = await data;

    final major = version.major;
    final minor = version.minor;
    final patch = version.patch;
    final v = ("$major.$minor.$patch");

    for (final entry in entries) {
      final ln = entry.lang;

      for (final kv in entry.values.entries) {
        final type = kv.key.id;
        final content = kv.value;

        if (content.isNotEmpty) {
          final file = await File("ci/changelog/$v/${type}_$ln.txt")
              .create(recursive: true);
          await file.writeAsString(content);
        }
      }
    }
  }

  Future<Iterable<Entry>> getRawReleaseNotes(int port, String changeLog) async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, port);
    final ciConfig = await CiConfig.getConfig("ci/config.ini");
    final langs = ciConfig.localizationLanguageList;
    final entries = {for (final ln in langs) ln: Entry(ln)};

    final completer = Completer<Iterable<Entry>>();

    await for (HttpRequest request in server) {
      try {
        final response = request.response;

        print("Request [${request.uri.toString()}]");

        var numStrings = 0;

        // TODO: check for max length

        for (final kv in request.uri.queryParameters.entries) {
          final id = kv.key;
          final value = kv.value;

          if (entries.values.any((entry) => entry.update(id, value))) {
            ++numStrings;
          }
        }

        if (entries.length == numStrings) {
          completer.complete(entries.values);
          entries.forEach((key, value) {
            print("key: $key; value: $value");
          });
          response.writeln("Succeed");
          await response.close();
          break;
        } else {
          final noteTemplate = await readTemplate("release_note");
          final entryTemplate = await readTemplate("release_note_entry");
          final formTemplate = await readTemplate("release_notes");

          final items = entries.values.map((entry) {
            return buildNote(
                noteTemplate,
                entry.map((type, id, value) =>
                    buildEntry(entryTemplate, id, value, entry.lang, type)));
          }).join("\n");

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

  String buildNote(String template, Iterable<String> entries) {
    return template.replaceAll("%entries%", entries.join("\n"));
  }

  String buildEntry(
      String template, String id, String text, String name, ItemType type) {
    if (type != ItemType.Default) {
      name = (type == ItemType.AppStore ? "[App Store] " : "[Google Play] ") +
          name;
    }

    final display = type == ItemType.Default ? "block" : "none";

    return template
        .replaceAll("%id%", id)
        .replaceAll("%name%", name)
        .replaceAll("%text%", text)
        .replaceAll("%display%", display)
        .replaceAll("%type%", type.id);
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

  void incrementVersion(Spec spec, Version value) {
    final version = value.incrementPatchAndBuild();
    final newSpec = spec.setVersion(version);
    newSpec.save();
  }

  String v(Version version) {
    return "v$version";
  }
}

class Entry {
  static String getId(ItemType type, String lang) {
    final typeId = type.id;
    return "$typeId-$lang";
  }

  final String lang;
  final Map<ItemType, String> values = {
    for (final type in ItemType.values) type: ""
  };

  Entry(this.lang);

  bool update(String id, String value) {
    if (value != null && value.isNotEmpty) {
      for (final type in values.keys) {
        if (id == getId(type, lang)) {
          values[type] = value;
          return true;
        }
      }
    }

    return false;
  }

  Iterable<String> map(
      String Function(ItemType type, String id, String value) f) {
    return values.entries.map((kv) => f(kv.key, getId(kv.key, lang), kv.value));
  }
}

class ItemType {
  static const ItemType Default = ItemType._("default");
  static const ItemType AppStore = ItemType._("appstore");
  static const ItemType GooglePlay = ItemType._("googleplay");

  static List<ItemType> values = [Default, AppStore, GooglePlay];

  final String id;

  const ItemType._(this.id) : assert(id != null);
}

extension VersionExtension on Version {
  Version incrementPatchAndBuild() {
    final build = int.parse(this.build) + 1;
    return Version(major, minor, patch + 1,
        preRelease: preRelease, build: "$build");
  }
}
