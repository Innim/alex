import 'dart:async';
import 'dart:io';

import 'package:alex/src/run/cmd.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  group('Cmd.run()', () {
    test('should close stdin for non-interactive commands', () async {
      final tempDir = await Directory.systemTemp.createTemp('alex_cmd_test_');
      addTearDown(() => tempDir.delete(recursive: true));

      final script = File(p.join(tempDir.path, 'wait_for_stdin.dart'))
        ..writeAsStringSync('''
import 'dart:io';

void main() {
  stdout.write('prompt> ');
  final input = stdin.readLineSync();
  if (input == null) {
    stderr.write('stdin closed');
    exit(3);
  }
}
''');

      final result = await Cmd()
          .run(
            Platform.resolvedExecutable,
            arguments: [script.path],
          )
          .timeout(
            const Duration(seconds: 5),
            onTimeout: () => throw TimeoutException('Command timed out'),
          );

      expect(result.exitCode, 3);
      expect(result.stderr, contains('stdin closed'));
    });
  });
}
