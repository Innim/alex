import 'dart:io';

import 'package:alex/src/exception/run_exception.dart';
import 'package:alex/src/fs/fs.dart';
import 'package:alex/src/pub_spec.dart';
import 'package:alex/src/run/flutter_cmd.dart';
import 'package:list_ext/list_ext.dart';
import 'package:meta/meta.dart';

/// Mixin for work with intl generation.
mixin IntlMixim {
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
