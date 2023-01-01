import 'dart:io';

import 'package:alex/alex.dart';
import 'package:alex/src/exception/run_exception.dart';
import 'package:alex/src/fs/fs.dart';
import 'package:alex/src/pub_spec.dart';
import 'package:alex/src/run/flutter_cmd.dart';
import 'package:list_ext/list_ext.dart';
import 'package:meta/meta.dart';
import 'package:path/path.dart' as path;

/// Mixin for work with intl generation.
mixin IntlMixin {
  @protected
  FlutterCmd get flutter;

  String? _intlGeneratorPackage;

  @protected
  Future<ProcessResult> runIntl(String cmd, List<String> arguments,
      {String? workingDir, bool prependWithPubGet = false}) async {
    final packageName = await _getIntlGeneratorPackageName();
    return flutter.runPub('$packageName:$cmd', arguments,
        workingDir: workingDir, prependWithPubGet: prependWithPubGet);
  }

  @protected
  Future<ProcessResult> runIntlOrFail(String cmd, List<String> arguments,
      {bool printStdOut = true,
      String? workingDir,
      bool prependWithPubGet = false}) async {
    return flutter.runOrFail(
        () => runIntl(cmd, arguments,
            workingDir: workingDir, prependWithPubGet: prependWithPubGet),
        printStdOut: printStdOut);
  }

  Future<void> extractLocalization(L10nConfig l10nConfig) async {
    final outputDir = l10nConfig.outputDir;
    final sourcePath = l10nConfig.sourceFile;
    await runIntlOrFail(
      'extract_to_arb',
      [
        '--output-dir=$outputDir',
        sourcePath,
      ],
      prependWithPubGet: true,
    );
  }

  Future<void> generateLocalization(L10nConfig l10nConfig) async {
    final arbFiles = await _getArbFiles(l10nConfig);
    await runIntlOrFail(
      'generate_from_arb',
      [
        '--output-dir=${l10nConfig.outputDir}',
        '--codegen_mode=release',
        '--use-deferred-loading',
        '--no-suppress-warnings',
        l10nConfig.sourceFile,
        ...arbFiles,
      ],
      prependWithPubGet: true,
    );
  }

  Future<List<String>> _getArbFiles(L10nConfig config) async {
    final dir = config.outputDir;
    final l10nDir = Directory(dir);
    final arbMessagesFile = L10nUtils.getArbMessagesFile(config);
    final arbParts = L10nUtils.getArbFileParts(config);
    final arbStart = arbParts[0];
    final arbEnd = arbParts[1];

    final res = <String>[];
    await for (final file in l10nDir.list()) {
      final filename = path.basename(file.path);
      if (filename != arbMessagesFile &&
          filename.startsWith(arbStart) &&
          filename.endsWith(arbEnd)) {
        res.add(path.join(dir, filename));
      }
    }
    return res;
  }

  Future<String> _getIntlGeneratorPackageName() async {
    if (_intlGeneratorPackage != null) return _intlGeneratorPackage!;

    final needle = ['intl_translation', 'intl_generator'];

    // TODO: may be better to check pubspec.lock?
    final spec = await Spec.pub(const IOFileSystem());

    final res = needle.firstWhereOrNull(spec.hasDevDependency);
    if (res == null) {
      throw RunException.err(
          "Can't found any of generation packages: ${needle.join(', ')}. "
          "Did you forget to add a dependency?");
    }

    return res;
  }
}
