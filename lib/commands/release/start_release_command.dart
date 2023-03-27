import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'dart:math';

import 'package:alex/alex.dart';
import 'package:alex/commands/l10n/src/mixins/intl_mixin.dart';
import 'package:alex/src/changelog/changelog.dart';
import 'package:alex/src/exception/run_exception.dart';
import 'package:alex/src/l10n/comparers/arb_comparer.dart';
import 'package:open_url/open_url.dart';
import 'package:path/path.dart' as p;
import 'package:version/version.dart';

import 'package:alex/commands/release/ci_config.dart';
import 'package:alex/commands/release/demo.dart';
import 'package:alex/src/fs/fs.dart';
import 'package:alex/src/git/git.dart';
import 'package:alex/runner/alex_command.dart';
import 'package:alex/src/pub_spec.dart';

/// Команда запуска релизной сборки.
class StartReleaseCommand extends AlexCommand with IntlMixin {
  static const _argLocale = 'check_locale';
  static const _defaultLocale = 'en';
  static const _argLocal = 'local';
  static const _argSkipL10n = 'skip_l10n';
  static const _argDemo = 'demo';

  late FileSystem fs;
  late GitCommands git;
  String? _packageDir;

  StartReleaseCommand() : super("start", "Start new release") {
    argParser
      ..addOption(
        _argLocale,
        abbr: 'l',
        help:
            'Locale to check before release if translations exist for all strings. '
            'If not specified - "en" locale will be check.',
        valueHelp: 'LOCALE',
      )
      ..addFlag(
        _argSkipL10n,
        abbr: 's',
        help: 'Skip process localization',
      )
      ..addFlag(
        _argLocal,
        abbr: 'b',
        help: "Runs local release build (only for Android right now)",
      )
      ..addFlag(
        _argDemo,
        help: "Runs command in demonstration mode",
      );
  }

  @override
  Future<int> doRun() async {
    final args = argResults!;
    final isDemo = args[_argDemo] as bool;

    final gitConfig = config.git;
    if (!isDemo) {
      fs = const IOFileSystem();
      git = GitCommands(GitClient(), gitConfig);
    } else {
      printInfo("Demonstration mode");
      fs = DemoFileSystem();
      git = GitCommands(DemoGit(verbose: isVerbose), gitConfig);
    }

    final skipL10n = args[_argSkipL10n] as bool? ?? false;
    final isLocalRelease = args[_argLocal] as bool? ?? false;

    final ciConfig = config.ci;
    if (!ciConfig.enabled && !isLocalRelease) {
      return error(1,
          message: 'You can only use local release if CI is disabled. '
              'See --$_argLocal and section ci in alex config section.');
    }

    git.ensureCleanAndCheckoutDevelop();

    final spec = await Spec.pub(fs);
    final version = spec.version;
    final vs = version.short;

    if (int.tryParse(version.build) == null) {
      return error(1,
          message: 'Invalid version "$vs": '
              'you should define build number (after +).');
    }

    if (skipL10n) {
      if (args.wasParsed(_argLocale)) {
        return error(1,
            message:
                "You can't pass --$_argSkipL10n and --$_argLocale at the same time");
      }
    } else {
      final baseLocale = args[_argLocale] as String? ?? _defaultLocale;
      final processLocResult = await _processLocalization(baseLocale);
      if (processLocResult != 0) {
        return processLocResult;
      }

      // Commit translations.
      _commit("Generated translations.");
    }

    printInfo('Start new release <v$vs>');

    git.gitflowReleaseStart(vs);

    printInfo('Upgrading CHANGELOG.md...');

    final changeLog = await upgradeChangeLog(version) ?? '';

    printInfo("Change log: \n$changeLog");

    final summary = StringBuffer();
    if (ciConfig.enabled) {
      printInfo('Waiting for release notes...');
      final releaseNotes = await getReleaseNotes(version, changeLog);
      summary
        ..writeln()
        ..writeln('# Release Notes')
        ..writeln()
        ..writeln(releaseNotes);
    }

    summary
      ..writeln()
      ..writeln('# Changelog')
      ..writeln()
      ..writeln(changeLog);

    if (isLocalRelease) {
      final localBuildResult = await _localBuild();
      if (localBuildResult != 0) return localBuildResult;
    }

    printInfo("Finishing release...");

    // committing changes
    _commit("Changelog and release notes");

    // finishing release
    git.gitflowReleaseFinish(vs);

    final branchDevelop = git.branchDevelop;
    if (git.getCurrentBranch() != branchDevelop) {
      git.checkout(branchDevelop);
    }

    // increment version
    incrementVersion(spec, version);

    _commit("Version increment");

    git.push(branchDevelop);
    git.push(git.branchMaster);

    printInfo('Release successfully completed');
    printInfo('');
    printInfo(
        'Release summary, copypaste it in the comment for release issue:');
    printInfo('');
    printInfo(summary.toString());

    return 0;
  }

  Future<String?> upgradeChangeLog(Version version) async {
    final changelog = Changelog(fs);

    // nothing to do if up to date
    // TODO: check that this is exactly a last version
    if (!(await changelog.hasVersion(version))) {
      await changelog.releaseVersion(version);
      await changelog.save();
    }

    return changelog.getLastVersionChangelog();
  }

  Future<String?> getReleaseNotes(Version version, String changeLog) async {
    const port = 4024;
    final data = getRawReleaseNotes(port, changeLog);

    // ignore: unawaited_futures
    openUrl("http://localhost:$port");

    final entries = await data;

    final major = version.major;
    final minor = version.minor;
    final patch = version.patch;
    final v = "$major.$minor.$patch";

    String? result;

    for (final entry in entries) {
      final ln = entry.lang;

      for (final kv in entry.values.entries) {
        final type = kv.key.id;
        final content = kv.value;

        if (content.isNotEmpty) {
          result ??= content;

          final path = _CIPath.getChangelogPath(v, type, ln);
          await fs.createFile(path, recursive: true);
          await fs.writeString(path, content);
        }
      }
    }

    printInfo("Release notes written successfully");
    return result;
  }

  Future<Iterable<Entry>> getRawReleaseNotes(int port, String changeLog) async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, port);
    final ciConfig = await CiConfig.getConfig(_CIPath.configPath);
    final langs = ciConfig.localizationLanguageList;

    final entries = {for (final ln in langs) ln: await _createEntry(ln)};

    final completer = Completer<Iterable<Entry>>();

    await for (final HttpRequest request in server) {
      // handle only requests to the root
      if (request.uri.path != '/') continue;

      try {
        final response = request.response;

        printInfo("Request [${request.uri.toString()}]");

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
        if (entries.values.every((entry) => entry.isAllRequiredValuesSet())) {
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
                entry.map((type, id, value) => buildEntry(
                      entryTemplate,
                      id,
                      value,
                      entry.lang,
                      type,
                      isRequired: entry.isRequired,
                    )));
          }).join("\n");

          final text = formTemplate
              .replaceAll("%change-log%", changeLog)
              .replaceAll("%items%", items);

          response.headers.contentType = ContentType.html;
          response.statusCode = HttpStatus.ok;
          response.writeln(text);
          await response.close();
        }
      } catch (e, s) {
        printError('Handle request error: $e\n$s');
      }
    }

    return completer.future;
  }

  String buildNote(String template, Iterable<String> entries) {
    return template.replaceAll("%entries%", entries.join("\n"));
  }

  String buildEntry(
      String template, String id, String text, String name, ItemType type,
      {required bool isRequired}) {
    final String prefix;
    switch (type) {
      case ItemType.appStore:
        prefix = '[App Store] ';
        break;
      case ItemType.googlePlay:
        prefix = '[Google Play] ';
        break;
      case ItemType.byDefault:
      // ignore: no_default_cases
      default:
        prefix = '';
        break;
    }

    final display = type == ItemType.byDefault ? "block" : "none";
    final itemNameSb = StringBuffer()
      ..write(prefix)
      ..write(name);
    if (isRequired) itemNameSb.write('*');

    return template
        .replaceAll("%id%", id)
        .replaceAll("%name%", itemNameSb.toString())
        .replaceAll("%text%", text)
        .replaceAll("%display%", display)
        .replaceAll("%type%", type.id)
        .replaceAll("%maxlength%", "${type.maxChars}")
        .replaceAll("%required%", isRequired ? 'required' : '');
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
      filePath = p.join(packageDir, path);
    } else {
      filePath = resolvedUri.path;
    }

    // TODO: windows fix
    if (Platform.isWindows && filePath.startsWith('/')) {
      filePath = filePath.substring(1);
    }

    return File(filePath).readAsString();
  }

  String getPackageDir() {
    return _packageDir ??=
        Directory.fromUri(Platform.script).parent.parent.path;
  }

  void incrementVersion(Spec spec, Version value) {
    printVerbose('Increment version');

    final version = value.incrementPatchAndBuild();
    final content = spec.getContent();
    final updated =
        content.replaceFirst("version: $value", "version: $version");
    spec.saveContent(updated);
  }

  void _commit(String commitMessage) {
    // committing changes
    git.addAll();
    git.commit(commitMessage);
  }

  Future<void> _checkTranslations(L10nConfig l10nConfig, String locale) async {
    final comparer = ArbComparer(l10nConfig, locale);
    final notTranslatedKeys = await comparer.compare(
      () async {
        printInfo('Running extract to arb...');
        await extractLocalization(l10nConfig);
      },
    );
    if (notTranslatedKeys.isNotEmpty) {
      throw RunException.err(
          'No translations for strings: ${notTranslatedKeys.join(',')} in locale: $locale');
    }
  }

  Future<Entry> _createEntry(String locale) async {
    final isDefaultChangelogExists =
        await fs.existsFile(_CIPath.getDefaultChangelogPath(locale));
    return Entry(locale, isRequired: !isDefaultChangelogExists);
  }

  Future<int> _processLocalization(String locale) async {
    final currentPath = p.current;
    final config = findConfigAndSetWorkingDir();
    final l10nConfig = config.l10n;
    try {
      await _checkTranslations(l10nConfig, locale);
      printInfo('Running generate localization dart files...');
      await generateLocalization(l10nConfig);
    } on RunException catch (e) {
      return errorBy(e);
    } finally {
      setCurrentDir(currentPath);
    }
    return 0;
  }

  Future<int> _localBuild() async {
    printInfo('Run local build');
    final res = await flutter.runCmdOrFail(
      'build',
      arguments: [
        'appbundle',
      ],
      printStdOut: false,
      immediatePrint: false,
    );

    if (res.exitCode == 0) {
      // TODO: copy release file to someplace
      // ✓ Built build/app/outputs/bundle/release/app-release.aab (27.1MB).
      printInfo('Local build succeed.');
      final message = res.stdout?.toString();
      final buildLine = message
          ?.split('\n')
          .firstWhere((line) => line.contains('✓ Built '), orElse: () => '');
      if (buildLine != null && buildLine.isNotEmpty) printInfo(buildLine);
      return 0;
    } else {
      return error(
        res.exitCode,
        message: res.stderr?.toString() ??
            res.stdout?.toString() ??
            'Local build failed',
      );
    }
  }
}

class Entry {
  static String getId(ItemType type, String lang) {
    final typeId = type.id;
    return "$typeId-$lang";
  }

  final String lang;
  final bool isRequired;
  final Map<ItemType, String> values = {
    for (final type in ItemType.values) type: ""
  };

  Entry(this.lang, {required this.isRequired});

  bool update(String id, String? value) {
    if (value != null && value.isNotEmpty) {
      for (final type in values.keys) {
        if (id == getId(type, lang)) {
          values[type] = value.trim();
          return true;
        }
      }
    }

    return false;
  }

  bool isAllRequiredValuesSet() {
    if (isRequired) {
      final res = values.entries.every(
              (kv) => kv.value.isNotEmpty || kv.key == ItemType.byDefault) ||
          values[ItemType.byDefault]!.isNotEmpty;

      return res;
    } else {
      return true;
    }
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
  static const ItemType byDefault = ItemType._("default");
  static const ItemType appStore = ItemType._("appstore", 4000);
  static const ItemType googlePlay = ItemType._("googleplay", 500);

  static List<ItemType> values = [byDefault, appStore, googlePlay];

  final String id;
  final int? _maxChars;

  const ItemType._(this.id, [this._maxChars]);

  int get maxChars {
    if (_maxChars != null) {
      return _maxChars!;
    }

    var value = -1;

    for (final item in values) {
      if (item._maxChars != null) {
        value = value != -1 ? min(value, item._maxChars!) : item._maxChars!;
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

class _CIPath {
  static const root = 'ci/';
  static const changelogDir = 'changelog/';
  static const defaultChangelogDir = 'default/';

  static String get rootPath => root;

  static String get configPath => p.join(rootPath, 'config.ini');

  static String get changelogRootPath => p.join(rootPath, changelogDir);

  static String get defaultChangelogRootPath =>
      p.join(changelogRootPath, defaultChangelogDir);

  static String getChangelogPath(String version, String type, String locale) =>
      p.join(changelogRootPath, version, '${type}_$locale.txt');

  static String getDefaultChangelogPath(String locale) =>
      p.join(defaultChangelogRootPath, 'default_$locale.txt');

  _CIPath._();
}
