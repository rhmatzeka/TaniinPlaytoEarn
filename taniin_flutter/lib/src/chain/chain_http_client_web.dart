import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

Future<String> postJson(
  String url,
  String payload, {
  required Duration timeout,
}) async {
  return _sendJsonRequest('POST', url, payload, timeout: timeout);
}

Future<String> getJson(String url, {required Duration timeout}) async {
  return _sendJsonRequest('GET', url, null, timeout: timeout);
}

Future<String> _sendJsonRequest(
  String method,
  String url,
  String? payload, {
  required Duration timeout,
}) {
  final completer = Completer<String>();
  final request = web.XMLHttpRequest();

  void completeWithError(Object error) {
    if (!completer.isCompleted) {
      completer.completeError(error);
    }
  }

  request.onload = ((web.Event _) {
    if (completer.isCompleted) {
      return;
    }
    try {
      completer.complete(_readHttpResponse(request));
    } on Object catch (error, stackTrace) {
      completer.completeError(error, stackTrace);
    }
  }).toJS;
  request.onerror = ((web.Event _) {
    completeWithError(StateError('Network error'));
  }).toJS;
  request.ontimeout = ((web.Event _) {
    completeWithError(StateError('Request timeout'));
  }).toJS;

  request.open(method, url, true);
  request.timeout = timeout.inMilliseconds;
  request.setRequestHeader('Accept', 'application/json');
  if (payload == null) {
    request.send();
  } else {
    request.setRequestHeader('Content-Type', 'application/json');
    request.send(payload.toJS);
  }

  return completer.future;
}

String _readHttpResponse(web.XMLHttpRequest request) {
  final body = request.responseText;
  final statusCode = request.status;
  if (statusCode < 200 || statusCode >= 300) {
    final apiError = _extractApiError(body);
    throw StateError(
      'HTTP $statusCode${apiError.isEmpty ? ' $body' : ' $apiError'}',
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
