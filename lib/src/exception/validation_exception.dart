class ValidationException implements Exception {
  final String? message;

  const ValidationException(this.message);

  @override
  String toString() => 'ValidationException(message: $message)';
}
