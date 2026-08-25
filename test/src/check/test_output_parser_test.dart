import 'package:alex/src/check/test_output_parser.dart';
import 'package:test/test.dart';

void main() {
  group('parse()', () {
    test('should count passed tests', () {
      final output = _events([
        '{"type":"suite","suite":{"id":0,"path":"test/a_test.dart"}}',
        '{"type":"testStart","test":{"id":1,"name":"loading test/a_test.dart","suiteID":0}}',
        '{"type":"testDone","testID":1,"result":"success","hidden":true}',
        '{"type":"testStart","test":{"id":2,"name":"should work","suiteID":0}}',
        '{"type":"testDone","testID":2,"result":"success","hidden":false}',
        '{"type":"testStart","test":{"id":3,"name":"should work too","suiteID":0}}',
        '{"type":"testDone","testID":3,"result":"success","hidden":false}',
        '{"type":"done","success":true}',
      ]);

      final res = TestOutputParser.parse(output);

      expect(res.passed, 2);
      expect(res.failed, 0);
      expect(res.skipped, 0);
      expect(res.total, 2);
      expect(res.completed, true);
      expect(res.isSuccess, true);
      expect(res.failures, isEmpty);
    });

    test('should collect failed tests with a message and a suite', () {
      final output = _events([
        '{"type":"suite","suite":{"id":0,"path":"test/a_test.dart"}}',
        '{"type":"testStart","test":{"id":2,"name":"should fail","suiteID":0}}',
        r'{"type":"error","testID":2,"error":"Expected: 1\n  Actual: 2","stackTrace":"..."}',
        '{"type":"testDone","testID":2,"result":"failure","hidden":false}',
        '{"type":"done","success":false}',
      ]);

      final res = TestOutputParser.parse(output);

      expect(res.passed, 0);
      expect(res.failed, 1);
      expect(res.isSuccess, false);

      final failure = res.failures.single;
      expect(failure.name, 'should fail');
      expect(failure.suite, 'test/a_test.dart');
      expect(failure.message, 'Expected: 1\n  Actual: 2');
      expect(failure.isLoadFailure, false);
    });

    test('should treat a hidden failed test as a load failure', () {
      final output = _events([
        '{"type":"suite","suite":{"id":0,"path":"test/a_test.dart"}}',
        '{"type":"testStart","test":{"id":1,"name":"loading test/a_test.dart","suiteID":0}}',
        '{"type":"error","testID":1,"error":"Compilation failed","stackTrace":""}',
        '{"type":"testDone","testID":1,"result":"error","hidden":true}',
        '{"type":"done","success":false}',
      ]);

      final res = TestOutputParser.parse(output);

      expect(res.failed, 1);
      expect(res.failures.single.isLoadFailure, true);
      expect(res.failures.single.message, 'Compilation failed');
    });

    test('should count skipped tests', () {
      final output = _events([
        '{"type":"testStart","test":{"id":2,"name":"skipped one","suiteID":0}}',
        '{"type":"testDone","testID":2,"result":"success","hidden":false,"skipped":true}',
        '{"type":"done","success":true}',
      ]);

      final res = TestOutputParser.parse(output);

      expect(res.passed, 0);
      expect(res.skipped, 1);
      expect(res.isSuccess, true);
    });

    test('should mark a run without the done event as not completed', () {
      final output = _events([
        '{"type":"testStart","test":{"id":2,"name":"should work","suiteID":0}}',
        '{"type":"testDone","testID":2,"result":"success","hidden":false}',
      ]);

      final res = TestOutputParser.parse(output);

      expect(res.passed, 1);
      expect(res.completed, false);
      expect(res.isSuccess, false);
    });

    test('should return unknown result for an output without events', () {
      final res = TestOutputParser.parse('Some plain text output\n');

      expect(res.completed, false);
      expect(res.total, 0);
      expect(res.isSuccess, false);
    });

    test('should trim a too long failure message', () {
      final longMessage = List.generate(50, (i) => 'line $i').join(r'\n');
      final output = _events([
        '{"type":"testStart","test":{"id":2,"name":"should fail","suiteID":0}}',
        '{"type":"error","testID":2,"error":"$longMessage","stackTrace":"..."}',
        '{"type":"testDone","testID":2,"result":"failure","hidden":false}',
        '{"type":"done","success":false}',
      ]);

      final res = TestOutputParser.parse(output);

      final lines = res.failures.single.message!.split('\n');
      expect(lines.length, TestOutputParser.maxMessageLines + 1);
      expect(lines.last, contains('line(s) more'));
    });

    test('should ignore non json lines', () {
      final output = _events([
        'Some warning from the tool',
        '{"type":"testStart","test":{"id":2,"name":"should work","suiteID":0}}',
        '{"type":"testDone","testID":2,"result":"success","hidden":false}',
        '{"type":"done","success":true}',
      ]);

      final res = TestOutputParser.parse(output);

      expect(res.passed, 1);
      expect(res.isSuccess, true);
    });
  });
}

String _events(List<String> lines) => '${lines.join('\n')}\n';
