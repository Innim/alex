import 'dart:async';

import 'package:alex/src/run/cmd.dart';
import 'package:test/test.dart';

void main() {
  group('Cmd.run()', () {
    test(
      'should close stdin for non-interactive commands',
      () async {
        // Waits for a line from the input and fails if it will never come.
        // If the input is not closed, then it waits forever.
        const script = 'if read line; '
            r'then echo "got: $line"; '
            'else echo "stdin closed" >&2; exit 3; fi';

        final result = await Cmd()
            .run('sh', arguments: ['-c', script])
            .timeout(const Duration(seconds: 30),
                onTimeout: () =>
                    throw TimeoutException('Command is waiting for an input'));

        expect(result.exitCode, 3);
        expect(result.stderr, contains('stdin closed'));
      },
      // Uses `sh`, and there is nothing platform specific in the tested code.
      testOn: 'posix',
    );
  });
}
