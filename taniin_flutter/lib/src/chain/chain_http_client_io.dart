import 'dart:convert';
import 'dart:io';

Future<String> postJson(
  String url,
  String payload, {
  required Duration timeout,
}) async {
  final client = HttpClient()..connectionTimeout = timeout;
  try {
    final request = await client.postUrl(Uri.parse(url)).timeout(timeout);
    request.headers.contentType = ContentType.json;
    final body = utf8.encode(payload);
    request.contentLength = body.length;
    request.add(body);
    final response = await request.close().timeout(timeout);
    return await _readHttpResponse(response, timeout: timeout);
  } finally {
    client.close(force: true);
  }
}

Future<String> getJson(String url, {required Duration timeout}) async {
  final client = HttpClient()..connectionTimeout = timeout;
  try {
    final request = await client.getUrl(Uri.parse(url)).timeout(timeout);
    request.headers.set(HttpHeaders.acceptHeader, 'application/json');
    final response = await request.close().timeout(timeout);
    return await _readHttpResponse(response, timeout: timeout);
  } finally {
    client.close(force: true);
  }
}

Future<String> _readHttpResponse(
  HttpClientResponse response, {
  required Duration timeout,
}) async {
  final body = await response.transform(utf8.decoder).join().timeout(timeout);
  if (response.statusCode < 200 || response.statusCode >= 300) {
    final apiError = _extractApiError(body);
    throw StateError(
      'HTTP ${response.statusCode}${apiError.isEmpty ? ' $body' : ' $apiError'}',
    );
  }
  return body;
}

String _extractApiError(String response) {
  final cleaned = response.trim();
  if (cleaned.isEmpty) {
    return '';
  }
  try {
    final object = jsonDecode(cleaned);
    if (object is! Map<String, dynamic>) {
      return '';
    }
    final error = object['error']?.toString().trim() ?? '';
    return error.isNotEmpty
        ? error
        : object['message']?.toString().trim() ?? '';
  } on Object {
    return '';
  }
}
