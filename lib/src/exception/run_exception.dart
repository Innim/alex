class RunException implements Exception {
  final int exitCode;
  final String message;

  const RunException([this.exitCode = 2, this.message]);

  factory RunException.fileNotFound(String message) => RunException(2, message);

  @override
  String toString() => 'RunException(exitCode: $exitCode, message: $message)';
}
