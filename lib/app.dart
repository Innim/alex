import 'package:alex/runner/alex_command_runner.dart';
import 'package:args/command_runner.dart';

Future<int> run(List<String> args) async {
  //args = ['release'];

  try {
    return await AlexCommandRunner().run(args);
  } on UsageException catch (e) {
    print(e);
    return 64;
  } catch (e) {
    print(e);
    return -1;
  }
}
