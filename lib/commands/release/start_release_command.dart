import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:alex/alex.dart';
import 'package:alex/commands/l10n/src/l10n_command_base.dart';
import 'package:alex/commands/l10n/src/mixins/intl_mixin.dart';
import 'package:alex/src/changelog/changelog.dart';
import 'package:alex/src/exception/run_exception.dart';
import 'package:alex/src/fs/path_utils.dart';
import 'package:alex/src/l10n/comparers/arb_comparer.dart';
import 'package:alex/src/l10n/locale/locales.dart';
import 'package:dart_openai/openai.dart';
import 'package:list_ext/list_ext.dart';
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
  static const _argEntryPoint = 'entry-point';
  static const _argBuildPlatforms = 'platforms';
  static const _argSkipL10n = 'skip_l10n';
  static const _argDemo = 'demo';

  late FileSystem fs;
  late GitCommands git;

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
        help: 'Skip translations check during release.',
      )
      ..addFlag(
        _argLocal,
        abbr: 'b',
        help: 'Runs local release build '
            '(Android and iOS, see parameter --$_argBuildPlatforms)',
      )
      ..addOption(
        _argEntryPoint,
        abbr: 'e',
        help: 'Entry point of the app, e.g. lib/main_test.dart. '
            'If not defined than default will be used. '
            'Only for local release builds.',
        valueHelp: 'lib/entry_point.dart',
      )
      ..addOption(
        _argBuildPlatforms,
        abbr: 'p',
        help: 'Target build platforms: ${_BuildPlatform.values.asDesc()}. '
            'You can pass multiple platforms separated by commas. '
            'Only for local release builds.',
        defaultsTo: [_BuildPlatform.android, _BuildPlatform.ios].asArgs(),
        valueHelp: 'PLATFORMS',
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

    if (!isDemo) {
      fs = const IOFileSystem();
    } else {
      printInfo("Demonstration mode");
      fs = DemoFileSystem();
    }

    git = getGit(config, isDemo: isDemo);

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
      final baseLocale =
          args.getLocale(_argLocale) ?? _defaultLocale.asXmlLocale();

      final processLocResult = await _processLocalization(baseLocale);
      if (processLocResult != 0) {
        return processLocResult;
      }

      // Commit translations.
      _commit("Generated translations.");
    }

    final scriptPaths = config.scripts?.preReleaseScriptsPaths;

    if (scriptPaths != null && scriptPaths.isNotEmpty) {
      printInfo('Running pre release scripts.');
      for (final path in scriptPaths) {
        final res = await flutter.runPubOrFail(
          '${config.rootPath}/$path',
          const [],
          title: null,
        );
        if (res.exitCode == 0) {
          printInfo('Pre release script $path run - OK');
        } else {
          // TODO: Clean current changes for git.
          return error(res.exitCode, message: '${res.stderr}');
        }
        _commit('Pre release scripts run.');
      }
    } else {
      printInfo('There are no pre release scripts to run.');
    }

    printInfo('Start new release <v$vs>');

    git.gitflowReleaseStart(vs);

    printInfo('Upgrading CHANGELOG.md...');

    final changeLog = await upgradeChangeLog(version) ?? '';

    printInfo("Change log: \n$changeLog");

    final summary = StringBuffer();
    if (ciConfig.enabled) {
      final Map<String, String> prompt;
      final chatGptApiKey = await settings.openAIApiKey;
      if (chatGptApiKey != null && chatGptApiKey.isNotEmpty) {
        printInfo('Trying to generate release notes prompt...');
        prompt = await _getReleaseNotesPrompt(chatGptApiKey, changeLog);
      } else {
        prompt = {};
      }

      printInfo('Waiting for release notes...');
      final releaseNotes = await getReleaseNotes(version, changeLog, prompt);
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
      final entryPoint = args[_argEntryPoint] as String?;
      final platforms =
          _BuildPlatform.parseArgs(args[_argBuildPlatforms] as String);

      printVerbose('Platforms: ${platforms.asDesc()}');

      for (final platform in platforms) {
        final localBuildResult = await _localBuild(entryPoint, platform);
        if (localBuildResult != 0) return localBuildResult;
      }
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

  Future<Map<String, String>> _getReleaseNotesPrompt(
    String apiKey,
    String changeLog,
  ) async {
    // TODO: make adapter for openAI API
    OpenAI.apiKey = apiKey;
    OpenAI.showLogs = isVerbose;
    final chat = OpenAI.instance.chat;

    final res = <String, String>{};

    const basicGptRequest =
        'Below is changelog for the mobile application update release. '
        'Please, provide the release notes for the application page in the store. '
        'No greetings nor signature. '
        'Not include version number in the text. '
        'Do not add some sort of header at the start, like "App updates:". '
        'Keep it short and to the point. '
        'You can skip not important changes.\n'
        'Make it in %LANG%\n'
        'Here the changelog:\n%CHANGELOG%';
    final chatGptRequests = {
      'en': basicGptRequest.replaceAll('%LANG%', 'English'),
      'ru': basicGptRequest.replaceAll('%LANG%', 'Russian'),
    };

    for (final lang in chatGptRequests.keys) {
      final requestContext = chatGptRequests[lang]!;
      final message = OpenAIChatCompletionChoiceMessageModel(
        content: requestContext.replaceAll('%CHANGELOG%', changeLog),
        role: OpenAIChatMessageRole.user,
      );

      printInfo('Request to ChatGPT for $lang Release Notes prompt');
      final response = await chat.create(
        // https://platform.openai.com/docs/models/gpt-3-5
        model: 'gpt-3.5-turbo',
        maxTokens: 500, // TODO: get limit from settings
        messages: [message],
      );
      final data = response.choices.firstOrNull;
      if (data != null) {
        final text = data.message.content;
        if (text.isNotEmpty) {
          printInfo('Request succeed');
          printVerbose('Text: $text');
          res[lang] = text;
        } else {
          printInfo('Response text is empty');
        }
      } else {
        printInfo('Empty response');
      }
    }

    return res;
  }

  Future<String?> getReleaseNotes(
    Version version,
    String changeLog,
    Map<String, String> prompt,
  ) async {
    const port = 4024;
    final data = getRawReleaseNotes(port, changeLog, prompt);

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

  Future<Iterable<Entry>> getRawReleaseNotes(
    int port,
    String changeLog,
    Map<String, String> promptByLang,
  ) async {
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

        final data = request.uri.queryParameters;
        final formSubmitted = data.containsKey('submit');
        for (final kv in data.entries) {
          final id = kv.key;
          final value = kv.value;

          entries.values.any((entry) => entry.update(id, value));
        }

        entries.values.forEach((entry) {
          final lang = entry.lang;
          final prompt = promptByLang[lang];
          if (prompt != null) {
            entry.values
                .updateAll((key, value) => value.isEmpty ? prompt : value);
          }
        });

        // TODO: error if default and stores values are set
        if (formSubmitted &&
            entries.values.every((entry) => entry.isAllRequiredValuesSet())) {
          completer.complete(entries.values);
          response
              .writeln("Succeed. Close the page and return to the console.");
          await response.close();
          break;
        } else {
          final noteTemplate = await _readTemplate("release_note");
          final entryTemplate = await _readTemplate("release_note_entry");
          final formTemplate = await _readTemplate("release_notes");

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

  Future<String> _readTemplate(String fileName) {
    return _readAssetFile("commands/release/$fileName.html");
  }

  Future<String> _readAssetFile(String assetPath) async {
    return File(await PathUtils.getAssetsPath(assetPath)).readAsString();
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

  Future<void> _checkTranslations(
    L10nConfig l10nConfig,
    XmlLocale locale,
  ) async {
    final comparer = ArbComparer(l10nConfig, locale.toArbLocale());
    final notTranslatedKeys = await comparer.extractAndCompare(
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

  Future<int> _processLocalization(XmlLocale locale) async {
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

  Future<int> _localBuild(String? entryPoint, _BuildPlatform platform) async {
    printInfo('Run local build for ${platform.name}');

    final String subcommand;

    switch (platform) {
      case _BuildPlatform.ios:
        subcommand = 'ipa';
        break;
      case _BuildPlatform.android:
        subcommand = 'appbundle';
        break;
    }

    final res = await flutter.runCmdOrFail(
      'build',
      arguments: [
        subcommand,
        if (entryPoint != null) entryPoint,
      ],
      printStdOut: false,
      immediatePrint: false,
    );

    if (res.exitCode == 0) {
      // TODO: copy release file to someplace and save for finale summary
      // Android: we have string in the output
      // ✓ Built build/app/outputs/bundle/release/app-release.aab (27.1MB).
      // iOS:
      // Run flutter build ipa to produce an Xcode build archive (.xcarchive file)
      // in your project’s build/ios/archive/ directory and
      // an App Store app bundle (.ipa file) in build/ios/ipa.

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

enum _BuildPlatform {
  ios,
  android;

  static Iterable<_BuildPlatform> parseArgs(String str) {
    if (str.trim().isEmpty) {
      throw const RunException.err('Empty platforms argument');
    }

    return str.split(',').map((e) {
      final needle = e.trim();
      final val =
          _BuildPlatform.values.firstWhereOrNull((p) => p.name == needle);
      if (val == null) throw RunException.err('Unknown platform <$needle>');
      return val;
    });
  }
}

extension _BuildPlatformsExt on Iterable<_BuildPlatform> {
  String asArgs() => joinOf((e) => e.name, ',');

  String asDesc() => joinOf((e) => e.name, ', ');
}
