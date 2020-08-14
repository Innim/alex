class RunException implements Exception {
  final int exitCode;
  final String message;

  const RunException([this.exitCode = 1, this.message]);

  @override
  String toString() => 'RunException(exitCode: $exitCode, message: $message)';
}
