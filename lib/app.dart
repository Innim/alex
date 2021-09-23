import 'package:alex/runner/alex_command_runner.dart';
import 'package:args/command_runner.dart';
import 'package:alex/internal/print.dart' as print;

Future<int> run(List<String> args) async {
  try {
    return await AlexCommandRunner().run(args);
  } on UsageException catch (e) {
    print.exception(e);
    return 64;
  } catch (e) {
    print.exception(e);
    return -1;
  }
}
