class RunException implements Exception {
  final int exitCode;
  final String message;

  const RunException({this.exitCode = 2, this.message});
  const RunException.withCode(this.exitCode, [this.message]);
  const RunException.warn([this.message]) : exitCode = 1;
  const RunException.err([this.message]) : exitCode = 2;

  factory RunException.fileNotFound(String message) =>
      RunException.withCode(2, message);

  @override
  String toString() => 'RunException(exitCode: $exitCode, message: $message)';
}
