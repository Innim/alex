const bool isProduction = bool.fromEnvironment('dart.vm.product');
const bool isDebug = !isProduction;

const packageName = 'alex';

const kVerbose = 'verbose';

/// Name of the flag to forbid a command to ask questions in the standard input.
const kNonInteractive = 'non-interactive';

/// Name of the option to define an output format of a command.
const kFormat = 'format';

/// Value of the [kFormat] option for a human readable output.
const kFormatText = 'text';

/// Value of the [kFormat] option for a machine readable output.
const kFormatJson = 'json';
