import 'dart:convert';
import 'dart:io';

import 'models.dart';

/// Session remembered from [TaqlynSdk.configure] for in-app share create.
class ShareSession {
  const ShareSession({
    required this.clientId,
    required this.publicKeyId,
    required this.apiBaseUrl,
    this.env,
  });

  final String clientId;
  final String publicKeyId;
  final String apiBaseUrl;
  final String? env;
}

/// Unified short link minted from the mobile SDK (public key id only).
class ShareLink {
  const ShareLink({
    required this.id,
    required this.code,
    required this.shortUrl,
    required this.host,
    required this.env,
  });

  final String id;
  final String code;
  final String shortUrl;
  final String host;
  final String env;

  factory ShareLink.fromMap(Map<String, Object?> map) {
    return ShareLink(
      id: map['id']?.toString() ?? '',
      code: map['code']?.toString() ?? '',
      shortUrl: map['shortUrl']?.toString() ?? '',
      host: map['host']?.toString() ?? '',
      env: map['env']?.toString() ?? '',
    );
  }
}

String normalizeApiBaseUrl(String? value) {
  final trimmed = (value ?? kDefaultApiBaseUrl).trim();
  final base = trimmed.isEmpty ? kDefaultApiBaseUrl : trimmed;
  return base.replaceFirst(RegExp(r'/+$'), '');
}

/// Thin HTTP wrapper for `POST /v1/sdk/short-links` (stdlib [HttpClient]).
class ShareClient {
  ShareClient({HttpClient? httpClient}) : _http = httpClient ?? HttpClient();

  final HttpClient _http;

  Future<ShareLink> create({
    required ShareSession session,
    String? destinationPath,
    String? destinationWeb,
    Map<String, String>? params,
    String? ogTitle,
    String? ogDescription,
    String? ogImage,
  }) async {
    final path = destinationPath?.trim() ?? '';
    final web = destinationWeb?.trim() ?? '';
    if (path.isEmpty && web.isEmpty) {
      throw ArgumentError('destinationPath or destinationWeb required');
    }

    final uri = Uri.parse('${session.apiBaseUrl}/v1/sdk/short-links');
    final request = await _http.postUrl(uri);
    request.headers.set(HttpHeaders.acceptHeader, 'application/json');
    request.headers.set(HttpHeaders.contentTypeHeader, 'application/json');
    request.headers.set('X-Taqlyn-Client-Id', session.clientId);
    request.headers.set('X-Taqlyn-Public-Key-Id', session.publicKeyId);
    request.write(
      jsonEncode({
        'clientId': session.clientId,
        'publicKeyId': session.publicKeyId,
        if (path.isNotEmpty) 'destinationPath': path,
        if (web.isNotEmpty) 'destinationWeb': web,
        if (params != null) 'params': params,
        if (ogTitle != null) 'ogTitle': ogTitle,
        if (ogDescription != null) 'ogDescription': ogDescription,
        if (ogImage != null) 'ogImage': ogImage,
        if (session.env != null) 'env': session.env,
      }),
    );
    final response = await request.close();
    final text = await response.transform(utf8.decoder).join();
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw HttpException(
        'createShareLink failed: ${response.statusCode}',
        uri: uri,
      );
    }
    final decoded = jsonDecode(text);
    if (decoded is! Map) {
      throw const FormatException('createShareLink: unexpected body');
    }
    return ShareLink.fromMap(Map<String, Object?>.from(decoded));
  }
}
