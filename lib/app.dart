import 'package:alex/runner/alex_command_runner.dart';
import 'package:args/command_runner.dart';
import 'package:alex/internal/print.dart' as print;

Future<int> run(List<String> args) async {
  try {
    return await AlexCommandRunner().run(args) ?? 2;
  } on UsageException catch (e, st) {
    print.exception(e, st);
    return 64;
  } catch (e, st) {
    print.exception(e, st);
    return -1;
  }
}
