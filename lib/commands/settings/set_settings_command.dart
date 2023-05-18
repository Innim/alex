import 'package:alex/commands/settings/src/settings_command_base.dart';
import 'package:alex/runner/alex_command.dart';
import 'package:alex/src/settings.dart';
import 'package:tuple/tuple.dart';

typedef _Getter = Future<String?> Function(AlexSettings);
typedef _Setter = Future<void> Function(AlexSettings, String);
typedef _T = Tuple2<_Getter, _Setter>;

class SetSettingsCommand extends SettingsCommandBase {
  static const _argReset = CmdArg('reset', abbr: 'r');
  static final _supportedSettings = <String, _T>{
    'open_ai_api_key': _T(
      (a) => a.openAIApiKey,
      (a, v) => a.setOpenAIApiKey(v),
    ),
  };

  static String _getSupportedSettings([String prefix = '']) =>
      _supportedSettings.keys.map((e) => '$prefix$e').join('\n');

  SetSettingsCommand()
      : super(
          'set',
          'Set global alex setting value.\n'
              'You should pass the name of setting and the value to set as arguments.\n'
              'For example: alex settings set open_ai_api_key abc123\n'
              '\n'
              'Supported settings:\n'
              '${_getSupportedSettings(' ')}',
        ) {
    argParser
      ..addFlagArg(
        _argReset,
        help: 'Reset (clears) setting value. '
            'You should not pass a value with this flag, only setting name.',
      );
  }

  @override
  Future<int> doRun() async {
    final ar = argResults!;
    final isReset = ar.getBool(_argReset);

    final args = ar.rest;

    final expectedArgsCount = isReset ? 1 : 2;
    if (args.length != expectedArgsCount) {
      if (args.length > expectedArgsCount) {
        printError(isReset
            ? 'You should pass only setting name with reset flag'
            : 'You should pass only setting name and value');
      } else {
        printError(isReset
            ? 'You should pass setting name'
            : 'You should pass setting name and value');
      }

      printInfo('See description below:');
      printInfo('');
      printUsage();
      return error(1);
    }

    final alexSettings = settings;

    final name = args[0];
    final processor = _supportedSettings[name];

    if (processor == null) {
      return error(
        1,
        message: 'Setting "$name" is not supported.\n'
            'List of supported settings:\n${_getSupportedSettings(' - ')}',
      );
    }

    final value = isReset ? '' : args[1];

    printVerbose('Set <$name> to "$value"');

    await processor.item2.call(alexSettings, value);

    return success(message: 'Saved ⚙️');
  }
}
