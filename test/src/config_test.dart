import 'dart:io';

import 'package:alex/src/config.dart';
import 'package:alex/src/const.dart';
import 'package:alex/src/exception/run_exception.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  late Directory dir;
  late String prevDir;

  setUp(() {
    prevDir = Directory.current.path;
    dir = Directory.systemTemp.createTempSync('alex_config_test');
    Directory.current = dir;
    AlexConfig.reset();
  });

  tearDown(() {
    Directory.current = prevDir;
    AlexConfig.reset();
    dir.deleteSync(recursive: true);
  });

  void writeFile(String name, String contents) =>
      File(p.join(dir.path, name)).writeAsStringSync(contents);

  RunException loadError() {
    try {
      AlexConfig.load(recursive: true);
    } on RunException catch (e) {
      return e;
    }

    fail('Config was loaded, but an exception was expected');
  }

  group('load()', () {
    test('should fail with an explanation if there is no config at all', () {
      final e = loadError();

      expect(e.exitCode, kExitCodeNoConfig);
      expect(e.message, contains('not configured for alex'));
      // The message should say what to do, not just what is wrong.
      expect(e.message, contains('create alex.yaml'));
    });

    test('should fail if pubspec.yaml has no alex section', () {
      writeFile('pubspec.yaml', 'name: demo\nversion: 1.0.0\n');

      final e = loadError();

      expect(e.exitCode, kExitCodeNoConfig);
      expect(e.message, contains('not configured for alex'));
      // A pubspec without the section is a project that doesn't use alex,
      // not a broken config.
      expect(e.message, isNot(contains('can not be loaded')));
    });

    test('should report a broken config instead of a missing one', () {
      writeFile('pubspec.yaml', 'name: demo\n');
      writeFile('alex.yaml', 'l10n:\n  output_dir: [\n');

      final e = loadError();

      expect(e.exitCode, kExitCodeNoConfig);
      expect(e.message, contains('alex.yaml'));
      expect(e.message, contains('can not be loaded'));
      expect(e.message, contains('Fix the config'));
    });

    test('should not fall back to pubspec.yaml if alex.yaml is broken', () {
      // A silent fallback would run alex with settings the user
      // does not expect - the broken file is the one being edited.
      writeFile(
          'pubspec.yaml',
          'name: demo\nalex:\n  l10n:\n'
              '    output_dir: lib/from_pubspec\n');
      writeFile('alex.yaml', 'l10n:\n  output_dir: [\n');

      final e = loadError();

      expect(e.message, contains('alex.yaml'));
      expect(e.message, contains('can not be loaded'));
    });

    test('should report a broken alex section of pubspec.yaml', () {
      writeFile('pubspec.yaml', 'name: demo\nalex:\n');

      final e = loadError();

      expect(e.message, contains('pubspec.yaml'));
      expect(e.message, contains('can not be loaded'));
    });

    test('should load alex.yaml', () {
      writeFile('pubspec.yaml', 'name: demo\n');
      writeFile('alex.yaml', 'l10n:\n  output_dir: lib/l10n\n');

      AlexConfig.load(recursive: true);

      expect(AlexConfig.instance.l10n.outputDir, 'lib/l10n');
    });

    test('should load the alex section of pubspec.yaml', () {
      writeFile(
          'pubspec.yaml',
          'name: demo\nalex:\n  l10n:\n'
              '    output_dir: lib/from_pubspec\n');

      AlexConfig.load(recursive: true);

      expect(AlexConfig.instance.l10n.outputDir, 'lib/from_pubspec');
    });
  });
}
