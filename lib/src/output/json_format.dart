import 'package:alex/src/const.dart';

/// Returns `true` if the machine readable output is requested
/// in the raw command line [args].
///
/// Used when the arguments are not parsed yet or can't be parsed at all,
/// but the result still should be printed as JSON.
bool isJsonFormatRequested(List<String> args) {
  for (var i = 0; i < args.length; i++) {
    final arg = args[i];

    if (arg == '--$kFormat=$kFormatJson') return true;
    if (arg == '--$kFormat' && i + 1 < args.length) {
      return args[i + 1] == kFormatJson;
    }
  }

  return false;
}

/// Returns the name of the command from the raw command line [args],
/// for example `code check`.
///
/// Everything before the first option is treated as a command path,
/// so it works even if the arguments were not parsed.
String commandNameFromArgs(List<String> args) {
  final parts = <String>[];

  for (final arg in args) {
    if (arg.startsWith('-')) break;
    parts.add(arg);
  }

  return parts.join(' ');
}
