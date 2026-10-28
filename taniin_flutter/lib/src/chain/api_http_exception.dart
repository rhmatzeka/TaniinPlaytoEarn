/// A non-2xx response from the Taniin API, keeping the status for callers.
class ApiHttpException implements Exception {
  const ApiHttpException(this.statusCode, this.message);

  final int statusCode;
  final String message;

  bool get unauthorized => statusCode == 401;

  @override
  String toString() => 'HTTP $statusCode $message';
}
