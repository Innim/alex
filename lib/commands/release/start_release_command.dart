import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'dart:math';

import 'package:alex/commands/release/ci_config.dart';
import 'package:alex/commands/release/demo.dart';
import 'package:alex/commands/release/fs.dart';
import 'package:alex/commands/release/git.dart';
import 'package:alex/runner/alex_command.dart';
import 'package:alex/src/pub_spec.dart';
import 'package:intl/intl.dart';
import 'package:open_url/open_url.dart';
import 'package:path/path.dart';
import 'package:version/version.dart';

/// Команда запуска релизной сборки.
class StartReleaseCommand extends AlexCommand {
  static const String flagDemo = "demo";
  FileSystem fs;
  GitCommands git;
  String _packageDir;

  StartReleaseCommand() : super("start", "Start new release") {
    argParser.addFlag(flagDemo, help: "Runs command in demonstration mode");
  }

  @override
  Future<int> run() async {
    final isDemo = argResults[flagDemo] as bool;
    if (!isDemo) {
      fs = IOFileSystem();
      git = GitCommands(GitClient());
    } else {
      print("Demonstration mode");
      fs = DemoFileSystem();
      git = GitCommands(DemoGit());
    }

    git.ensureCleanStatus();

    if (git.getCurrentBranch() != branchDevelop) {
      git.checkout(branchDevelop);
    }

    git.ensureRemoteUrl();

    git.pull();

    git.ensureCleanStatus();

    final spec = await Spec.pub(fs);
    final version = spec.version;
    final ver = "v$version";
    final vs = "${version.short}";

    print('Start new release <v$vs>');
    git.gitflowReleaseStart(vs);

    print('Upgrading CHANGELOG.md...');

    final changeLog = await upgradeChangeLog(ver);

    print("Change log: \n" + changeLog);

    print('Waiting for release notes...');

    await getReleaseNotes(version, changeLog);

    print("Finishing release...");

    // committing changes
    git.addAll();
    git.commit("Changelog and release notes");

    // finishing release
    git.gitflowReleaseFinish(vs);

    if (git.getCurrentBranch() != branchDevelop) {
      git.checkout(branchDevelop);
    }

    // increment version
    incrementVersion(spec, version);

    git.addAll();
    git.commit("Version increment");

    git.push(branchDevelop);
    git.push(branchMaster);

    print('Release successfully completed');

    return 0;
  }

  Future<String> upgradeChangeLog(String ver) async {
    final file = "CHANGELOG.md";
    var contents = await fs.readString(file);
    if (contents.startsWith("## Next release")) {
      // up to date
      if (contents.contains(ver)) {
        return getCurrentChangeLog(contents);
      }

      final now = DateFormat("yyyy-MM-dd").format(DateTime.now());
      contents = contents.replaceFirst(
          "## Next release", "## Next release\n\n## $ver - $now");

      await fs.writeString(file, contents);

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

  Future<void> getReleaseNotes(Version version, String changeLog) async {
    final port = 4024;
    final data = getRawReleaseNotes(port, changeLog);

    // ignore: unawaited_futures
    openUrl("http://localhost:$port");

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
          final path = "ci/changelog/$v/${type}_$ln.txt";
          await fs.createFile(path);
          await fs.writeString(path, content);
        }
      }
    }

    print("Release notes written successfully");
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

        // TODO: check for max length

        entries.values.forEach((entry) {
          entry.clear();
        });

        for (final kv in request.uri.queryParameters.entries) {
          final id = kv.key;
          final value = kv.value;

          entries.values.any((entry) => entry.update(id, value));
        }

        // TODO: error if default and stores values are set
        if (entries.values.every((entry) => entry.isAllValuesSet())) {
          completer.complete(entries.values);
          response
              .writeln("Succeed. Close the page and return to the console.");
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
        .replaceAll("%type%", type.id)
        .replaceAll("%maxlength%", "${type.maxChars}");
  }

  Future<String> readTemplate(String fileName) {
    return readAssetFile("commands/release/$fileName.html");
  }

  Future<String> readAssetFile(String assetPath) async {
    return readPackageFile("assets/$assetPath");
  }

  Future<String> readPackageFile(String path) async {
    final packageUri = Uri.parse('package:alex/$path');
    final resolvedUri = await Isolate.resolvePackageUri(packageUri);

    String filePath;
    if (resolvedUri == null) {
      // trying to get relative path
      final packageDir = getPackageDir();
      filePath = join(packageDir, path);
    } else {
      filePath = resolvedUri.path;
    }

    // TODO: windows fix
    if (filePath.startsWith('/')) {
      filePath = filePath.substring(1);
    }

    return File(filePath).readAsString();
  }

  String getPackageDir() {
    return _packageDir ??=
        Directory.fromUri(Platform.script).parent.parent.path;
  }

  void incrementVersion(Spec spec, Version value) {
    final version = value.incrementPatchAndBuild();
    final content = spec.getContent();
    final updated =
        content.replaceFirst("version: $value", "version: $version");
    spec.saveContent(updated);
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
          values[type] = value != null ? value.trim() : "";
          return true;
        }
      }
    }

    return false;
  }

  bool isAllValuesSet() {
    final res = values.entries
            .every((kv) => kv.value.isNotEmpty || kv.key == ItemType.Default) ||
        values[ItemType.Default].isNotEmpty;

    return res;
  }

  void clear() {
    for (final type in values.keys) {
      values[type] = "";
    }
  }

  Iterable<String> map(
      String Function(ItemType type, String id, String value) f) {
    return values.entries.map((kv) => f(kv.key, getId(kv.key, lang), kv.value));
  }
}

class ItemType {
  static const ItemType Default = ItemType._("default");
  static const ItemType AppStore = ItemType._("appstore", 255);
  static const ItemType GooglePlay = ItemType._("googleplay", 500);

  static List<ItemType> values = [Default, AppStore, GooglePlay];

  final String id;
  final int _maxChars;

  const ItemType._(this.id, [this._maxChars]) : assert(id != null);

  int get maxChars {
    if (_maxChars != null) {
      return _maxChars;
    }

    var value = -1;

    for (final item in values) {
      if (item._maxChars != null) {
        value = value != -1 ? min(value, item._maxChars) : item._maxChars;
      }
    }

    return value;
  }
}

extension VersionExtension on Version {
  String get short {
    return "$major.$minor.$patch";
  }

  Version incrementPatchAndBuild() {
    final build = int.parse(this.build) + 1;
    return Version(major, minor, patch + 1,
        preRelease: preRelease, build: "$build");
  }
}
