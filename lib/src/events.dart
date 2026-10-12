import 'dart:convert';
import 'dart:io';

import 'share.dart';

const String _kApiOrigin = 'https://api.taqlyn.com';

/// Thin HTTP wrapper for SDK analytics (`POST /v1/events/open`, `/v1/events/sdk`).
class EventsClient {
  EventsClient({HttpClient? httpClient}) : _http = httpClient ?? HttpClient();

  final HttpClient _http;

  String _anonymousId = '';

  String _deviceAnonymousId() {
    if (_anonymousId.isNotEmpty) return _anonymousId;
    _anonymousId = 'anon_${DateTime.now().millisecondsSinceEpoch}';
    return _anonymousId;
  }

  Future<void> trackOpen({
    required ShareSession session,
    required String linkId,
  }) async {
    final id = linkId.trim();
    if (id.isEmpty) return;
    try {
      final uri = Uri.parse('$_kApiOrigin/v1/events/open');
      final request = await _http.postUrl(uri);
      request.headers.set(HttpHeaders.acceptHeader, 'application/json');
      request.headers.set(HttpHeaders.contentTypeHeader, 'application/json');
      request.headers.set('X-Taqlyn-Client-Id', session.clientId);
      request.headers.set('X-Taqlyn-Public-Key-Id', session.publicKeyId);
      request.write(
        jsonEncode({
          'clientId': session.clientId,
          'publicKeyId': session.publicKeyId,
          'linkId': id,
          'anonymousId': _deviceAnonymousId(),
          'env': ?session.env,
        }),
      );
      final response = await request.close();
      await response.drain<void>();
    } catch (_) {
      /* fire-and-forget */
    }
  }

  Future<void> logEvent({
    required ShareSession session,
    required String name,
    Map<String, Object?>? data,
  }) async {
    final eventName = name.trim();
    if (eventName.isEmpty) return;
    try {
      final uri = Uri.parse('$_kApiOrigin/v1/events/sdk');
      final request = await _http.postUrl(uri);
      request.headers.set(HttpHeaders.acceptHeader, 'application/json');
      request.headers.set(HttpHeaders.contentTypeHeader, 'application/json');
      request.headers.set('X-Taqlyn-Client-Id', session.clientId);
      request.headers.set('X-Taqlyn-Public-Key-Id', session.publicKeyId);
      request.write(
        jsonEncode({
          'clientId': session.clientId,
          'publicKeyId': session.publicKeyId,
          'name': eventName,
          'data': ?data,
          'env': ?session.env,
        }),
      );
      final response = await request.close();
      await response.drain<void>();
    } catch (_) {
      /* fire-and-forget */
    }
  }
}
