import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'models.dart';
import 'share.dart';

const String _kApiOrigin = 'https://api.taqlyn.com';

/// Thin HTTP wrapper for `POST /v1/links/expand`.
class ExpandClient {
  ExpandClient({HttpClient? httpClient}) : _http = httpClient ?? HttpClient();

  final HttpClient _http;

  Future<ExpandResult?> expand({
    required ShareSession session,
    required String url,
  }) async {
    final uri = Uri.parse('$_kApiOrigin/v1/links/expand');
    final req = await _http.postUrl(uri);
    req.headers.set(HttpHeaders.acceptHeader, 'application/json');
    req.headers.set(HttpHeaders.contentTypeHeader, 'application/json');
    req.headers.set('X-Taqlyn-Client-Id', session.clientId);
    req.headers.set('X-Taqlyn-Public-Key-Id', session.publicKeyId);
    req.add(
      utf8.encode(
        jsonEncode({
          'clientId': session.clientId,
          'publicKeyId': session.publicKeyId,
          'url': url,
          if (session.env != null) 'env': session.env,
        }),
      ),
    );
    final res = await req.close();
    if (res.statusCode == 404) return null;
    if (res.statusCode < 200 || res.statusCode >= 300) return null;
    final body = await res.transform(utf8.decoder).join();
    final map = jsonDecode(body) as Map<String, Object?>;
    final rawParams = map['params'];
    final params = <String, String>{};
    if (rawParams is Map) {
      rawParams.forEach((key, value) {
        if (key != null && value != null) {
          params[key.toString()] = value.toString();
        }
      });
    }
    final linkId = map['linkId']?.toString() ?? '';
    if (linkId.isEmpty) return null;
    return ExpandResult(
      linkId: linkId,
      code: map['code']?.toString() ?? '',
      host: map['host']?.toString() ?? '',
      destinationPath: map['destinationPath']?.toString() ?? '/',
      params: params,
      url: map['url']?.toString() ?? '',
      linkResolveMode: ResolveMode.fromWire(map['linkResolveMode']?.toString()),
      appResolveMode: ResolveMode.fromWire(map['appResolveMode']?.toString()),
      appExpandTimeoutMs: map['appExpandTimeoutMs'] is int
          ? map['appExpandTimeoutMs'] as int
          : int.tryParse(map['appExpandTimeoutMs']?.toString() ?? ''),
    );
  }
}

ResolvedNavTarget? pathMapOnly(String url) {
  final uri = Uri.tryParse(url);
  if (uri == null) return null;
  final path = uri.path.isEmpty ? '/' : uri.path;
  final qs = uri.query;
  return ResolvedNavTarget(href: qs.isEmpty ? path : '$path?$qs');
}

bool shouldExpand(String url, List<String> hosts) {
  final uri = Uri.tryParse(url);
  if (uri == null || uri.host.isEmpty) return false;
  final host = uri.host.toLowerCase();
  final hostOk = hosts.isEmpty
      ? true
      : hosts.any((prefix) {
          var p = prefix.trim().toLowerCase();
          p = p.replaceFirst(RegExp(r'^https?://'), '');
          if (p.endsWith('/')) p = p.substring(0, p.length - 1);
          return host == p || host.endsWith('.$p') || url.startsWith(prefix);
        });
  if (!hostOk) return false;
  final path = uri.path.replaceAll(RegExp(r'^/+|/+$'), '');
  if (path.isEmpty || path.contains('/')) return false;
  return RegExp(r'^[A-Za-z0-9_-]{4,32}$').hasMatch(path);
}

String hrefFromExpand(ExpandResult result) {
  var path = result.destinationPath;
  if (!path.startsWith('/')) path = '/$path';
  if (result.params.isEmpty) return path;
  final qs = result.params.entries
      .map((e) =>
          '${Uri.encodeQueryComponent(e.key)}=${Uri.encodeQueryComponent(e.value)}')
      .join('&');
  return '$path?$qs';
}

Future<T?> withTimeoutMs<T>(int ms, Future<T?> Function() body) async {
  try {
    return await body().timeout(Duration(milliseconds: ms));
  } on TimeoutException {
    return null;
  }
}
