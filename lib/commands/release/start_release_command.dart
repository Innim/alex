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
import 'package:alex/src/release/build_artifact_name.dart';
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
  static const _argTargetPath = 'target-path';
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
      ..addOption(
        _argTargetPath,
        abbr: 't',
        help: 'Target directory path to copy build artifacts to. '
            'Artifacts are renamed by the pattern '
            '<name>_v<major>.<minor>.<patch>_<build>.<aab|ipa>, '
            'where <name> is a project name from pubspec.yaml '
            'or the build.name value from the alex config. '
            'Only for local release builds.',
        valueHelp: 'DIR_PATH',
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

    final targetPath = (args[_argTargetPath] as String?)?.trim();
    if (targetPath != null) {
      if (!isLocalRelease) {
        return error(1,
            message: 'Option --$_argTargetPath can be used '
                'only for local release builds. See --$_argLocal.');
      }

      if (targetPath.isEmpty) {
        return error(1, message: "Option --$_argTargetPath can't be empty.");
      }

      // Fail before the release is started if the target can't be used.
      final targetDir = await _ensureTargetDir(targetPath);
      _checkTargetDirIsNotInRepo(targetDir);
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

    // Prepare parameters of a local build before the release is started,
    // so an invalid value will not break the process in the middle.
    final _LocalBuildOptions? localBuildOptions;
    final List<_BuildPlatform> buildPlatforms;
    if (isLocalRelease) {
      localBuildOptions = _LocalBuildOptions(
        entryPoint: args[_argEntryPoint] as String?,
        targetPath: targetPath,
        artifactName:
            BuildArtifactName.sanitizeName(config.build.name ?? spec.name),
        version: version,
      );
      buildPlatforms =
          _BuildPlatform.parseArgs(args[_argBuildPlatforms] as String);
      printVerbose('Platforms: ${buildPlatforms.asDesc()}');
    } else {
      localBuildOptions = null;
      buildPlatforms = const [];
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

    if (localBuildOptions != null) {
      for (final platform in buildPlatforms) {
        await _localBuild(platform, localBuildOptions);
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

  /// Runs a local release build for the [platform].
  Future<void> _localBuild(
      _BuildPlatform platform, _LocalBuildOptions options) async {
    printInfo('Run local build for ${platform.name}');

    // Output directory is cleaned before the build,
    // so an artifact of some previous build can't be treated
    // as a result of the current one.
    final outputDir = Directory(platform.outputDirPath);
    await _cleanBuildOutputDir(outputDir);

    // Fails with a RunException if the build failed.
    final res = await flutter.runCmdOrFail(
      'build',
      arguments: [
        platform.buildSubcommand,
        if (options.entryPoint != null) options.entryPoint!,
      ],
      printStdOut: false,
      immediatePrint: false,
    );

    printInfo('Local build succeed.');

    // Android: ✓ Built build/app/outputs/bundle/release/app-release.aab (27.1MB).
    // iOS: ✓ Built IPA to build/ios/ipa (20.0MB).
    final buildLine = res.stdout
        ?.toString()
        .split('\n')
        .firstWhereOrNull((line) => line.contains('✓ Built '))
        ?.trim();
    if (buildLine != null && buildLine.isNotEmpty) printInfo(buildLine);

    _checkReportedPathInOutputDir(buildLine, outputDir, platform);

    final artifact = await _getBuildArtifact(outputDir, platform);
    printInfo('Build artifact: ${artifact.path}');

    // Artifact is copied before any commit is made,
    // so the release will not be published if the copy failed.
    // The target directory is checked to be out of the git index,
    // so the artifact can't get in the release commit.
    if (options.targetPath != null) {
      await _copyBuildArtifact(artifact, platform, options);
    }
  }

  Future<void> _cleanBuildOutputDir(Directory dir) async {
    if (!await dir.exists()) return;

    printVerbose('Clean build output directory <${dir.path}>');
    try {
      await dir.delete(recursive: true);
    } catch (e) {
      throw RunException.err(
          "Can't clean build output directory <${dir.path}>: $e. "
          'Remove it manually and run the command again.');
    }
  }

  /// Checks that the build has placed the artifact in the directory
  /// which was cleaned before the build.
  ///
  /// Otherwise there is no guarantee that a found artifact
  /// is a result of the current build.
  void _checkReportedPathInOutputDir(
      String? buildLine, Directory outputDir, _BuildPlatform platform) {
    if (buildLine == null || buildLine.isEmpty) {
      printVerbose("Build output doesn't contain a line with an artifact path");
      return;
    }

    // `✓ Built <path> (<size>)` for Android
    // and `✓ Built IPA to <path> (<size>)` for iOS.
    final match = RegExp(r'✓ Built (?:.*? to )?(.+?) \(').firstMatch(buildLine);
    if (match == null) {
      printVerbose("Can't parse an artifact path from the line <$buildLine>");
      return;
    }

    final reportedPath = p.absolute(match.group(1)!.trim());
    final expectedPath = p.absolute(outputDir.path);
    if (!p.equals(reportedPath, expectedPath) &&
        !p.isWithin(expectedPath, reportedPath)) {
      throw RunException.err(
          'Build for ${platform.name} has placed the artifact in '
          '<$reportedPath>, but <$expectedPath> was expected. '
          "Alex cleans the expected directory before the build, so it can't "
          'guarantee that the artifact in <$reportedPath> is a result of '
          'this build. Copy the artifact manually '
          'or report the issue to the alex repository.');
    }
  }

  /// Returns a build artifact from the [outputDir].
  ///
  /// Fails if there is no artifact or if there is more than one,
  /// because the build can succeed even if the distribution file
  /// was not created (for example, if only an Xcode archive was built).
  Future<File> _getBuildArtifact(
      Directory outputDir, _BuildPlatform platform) async {
    final extension = '.${platform.artifactExtension}';
    final artifacts = <File>[];

    if (await outputDir.exists()) {
      await for (final entity
          in outputDir.list(recursive: true, followLinks: false)) {
        if (entity is File &&
            p.extension(entity.path).toLowerCase() == extension) {
          artifacts.add(entity);
        }
      }
    }

    if (artifacts.isEmpty) {
      throw RunException.err(
          'Build for ${platform.name} finished successfully, but no '
          '*$extension file was found in <${outputDir.path}>.\n'
          '${platform.noArtifactHint}');
    }

    if (artifacts.length > 1) {
      artifacts.sort((a, b) => a.path.compareTo(b.path));
      throw RunException.err(
          'Build for ${platform.name} has produced more than one '
          '*$extension file in <${outputDir.path}>:\n'
          '${artifacts.map((e) => ' - ${e.path}').join('\n')}\n'
          "Alex can't detect which one should be used, "
          'so copy the required artifact manually.');
    }

    return artifacts.first;
  }

  Future<void> _copyBuildArtifact(File artifact, _BuildPlatform platform,
      _LocalBuildOptions options) async {
    final targetDir = await _ensureTargetDir(options.targetPath!);
    final fileName = BuildArtifactName.forVersion(
        options.artifactName, options.version, platform.artifactExtension);
    final targetFile = File(p.join(targetDir.path, fileName));

    if (await targetFile.exists()) {
      printWarning('File <${targetFile.path}> already exists '
          'and will be overwritten.');
    }

    try {
      await artifact.copy(targetFile.path);
    } catch (e) {
      throw RunException.err("Can't copy build artifact <${artifact.path}> "
          'to <${targetFile.path}>: $e.');
    }

    printInfo('Copied ${platform.name} build artifact '
        'to <${targetFile.path}>.');
  }

  /// Returns a directory to copy build artifacts to.
  ///
  /// Creates the directory if it doesn't exist and checks
  /// that artifacts can be written in it.
  Future<Directory> _ensureTargetDir(String targetPath) async {
    final dir = Directory(targetPath);
    final type = await FileSystemEntity.type(targetPath);

    if (type == FileSystemEntityType.notFound) {
      try {
        await dir.create(recursive: true);
      } catch (e) {
        throw RunException.err(
            "Can't create target directory <$targetPath>: $e.");
      }
      printInfo('Created target directory <$targetPath>.');
    } else if (type != FileSystemEntityType.directory) {
      throw RunException.err('Target path <$targetPath> is not a directory. '
          'Pass a path to a directory in --$_argTargetPath.');
    }

    await _checkDirIsWritable(dir);

    return dir;
  }

  /// Checks that build artifacts copied in the [dir]
  /// will not be added in a release commit by `git add -A`.
  void _checkTargetDirIsNotInRepo(Directory dir) {
    final path = dir.absolute.path;
    if (git.isPathOutOfIndex(path)) return;

    throw RunException.err('Target directory <$path> is inside the repository '
        'and is not ignored by git, so build artifacts would be added '
        'in the release commit. Pass a path outside of the repository '
        'in --$_argTargetPath or add the directory in .gitignore.');
  }

  Future<void> _checkDirIsWritable(Directory dir) async {
    // There is no API to check permissions,
    // so just try to write a file in the directory.
    final probe = File(p.join(dir.path, '.alex_write_check_$pid'));

    try {
      await probe.writeAsString('');
    } catch (e) {
      throw RunException.err("Can't write in the target directory "
          '<${dir.path}>: $e. Check the access permissions.');
    } finally {
      try {
        if (await probe.exists()) await probe.delete();
      } catch (e) {
        printVerbose("Can't remove temporary file <${probe.path}>: $e");
      }
    }
  }
}

/// Parameters of a local release build.
class _LocalBuildOptions {
  /// Entry point of the app, e.g. `lib/main_test.dart`.
  final String? entryPoint;

  /// Directory to copy build artifacts to.
  final String? targetPath;

  /// Application name to use in artifact file names.
  final String artifactName;

  /// Version of the release.
  final Version version;

  const _LocalBuildOptions({
    required this.entryPoint,
    required this.targetPath,
    required this.artifactName,
    required this.version,
  });
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

  /// Subcommand of the `flutter build` for the platform.
  String get buildSubcommand => switch (this) {
        _BuildPlatform.ios => 'ipa',
        _BuildPlatform.android => 'appbundle',
      };

  /// Extension of a distribution file for the platform.
  String get artifactExtension => switch (this) {
        _BuildPlatform.ios => 'ipa',
        _BuildPlatform.android => 'aab',
      };

  /// Directory where the `flutter build` places artifacts for the platform.
  String get outputDirPath => switch (this) {
        _BuildPlatform.ios => p.join('build', 'ios', 'ipa'),
        _BuildPlatform.android => p.join('build', 'app', 'outputs', 'bundle'),
      };

  /// Hint to show if the build succeed, but no artifact was found.
  String get noArtifactHint => switch (this) {
        _BuildPlatform.ios =>
          'Most likely only an Xcode archive was created, but the export of '
              'an .ipa failed (usually because of signing or export options). '
              'Check the build output above and the '
              '<build/ios/archive> directory, then run `flutter build ipa` '
              'manually or export the archive with Xcode Organizer.',
        _BuildPlatform.android =>
          'Check the Gradle output above and run `flutter build appbundle` '
              'manually to see the reason.',
      };

  static List<_BuildPlatform> parseArgs(String str) {
    if (str.trim().isEmpty) {
      throw const RunException.err('Empty platforms argument');
    }

    return str.split(',').map((e) {
      final needle = e.trim();
      final val =
          _BuildPlatform.values.firstWhereOrNull((p) => p.name == needle);
      if (val == null) throw RunException.err('Unknown platform <$needle>');
      return val;
    }).toList(growable: false);
  }
}

extension _BuildPlatformsExt on Iterable<_BuildPlatform> {
  String asArgs() => joinOf((e) => e.name, ',');

  String asDesc() => joinOf((e) => e.name, ', ');
}
