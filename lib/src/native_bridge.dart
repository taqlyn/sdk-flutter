import 'dart:async';

import 'package:flutter/services.dart';

import 'models.dart';

/// Flutter `adapters/native-bridge` — MethodChannel facade → native SdkCore.
///
/// App / sample Dart code must depend on [TaqlynSdk] only — never Play
/// Install Referrer / UIPasteboard types.
abstract class NativeBridge {
  Future<void> configure({
    required String clientId,
    required String publicKeyId,
    required SdkOptions options,
  });

  Future<DeferredLink?> resolveDeferred();

  Stream<DeferredLink> observeLinks();

  Future<void> consume(String linkId);

  Future<void> setReadyForNavigation(bool ready);
}

/// Production bridge: MethodChannel + EventChannel → Android/iOS SdkCore.
class MethodChannelNativeBridge implements NativeBridge {
  MethodChannelNativeBridge({
    MethodChannel? methodChannel,
    EventChannel? eventChannel,
  })  : _methods = methodChannel ?? const MethodChannel('taqlyn_sdk'),
        _events = eventChannel ?? const EventChannel('taqlyn_sdk/links');

  final MethodChannel _methods;
  final EventChannel _events;

  @override
  Future<void> configure({
    required String clientId,
    required String publicKeyId,
    required SdkOptions options,
  }) {
    return _methods.invokeMethod<void>('configure', {
      'clientId': clientId,
      'publicKeyId': publicKeyId,
      'options': options.toMap(),
    });
  }

  @override
  Future<DeferredLink?> resolveDeferred() async {
    final raw = await _methods.invokeMethod<dynamic>('resolveDeferred');
    if (raw == null) return null;
    if (raw is Map) {
      return DeferredLink.fromMap(Map<Object?, Object?>.from(raw));
    }
    return null;
  }

  @override
  Stream<DeferredLink> observeLinks() {
    return _events.receiveBroadcastStream().where((event) => event != null).map(
      (event) {
        final map = Map<Object?, Object?>.from(event as Map);
        return DeferredLink.fromMap(map);
      },
    );
  }

  @override
  Future<void> consume(String linkId) {
    return _methods.invokeMethod<void>('consume', {'linkId': linkId});
  }

  @override
  Future<void> setReadyForNavigation(bool ready) {
    return _methods.invokeMethod<void>('setReadyForNavigation', {
      'ready': ready,
    });
  }
}

/// In-memory fake for Dart unit tests (ready-gate + payload mapping).
///
/// Mirrors native SdkCore semantics: deferred links stay pending until
/// [setReadyForNavigation](true); warm links flow immediately.
class FakeNativeBridge implements NativeBridge {
  bool configured = false;
  bool readyForNavigation = false;
  DeferredLink? pendingDeferred;
  DeferredLink? nextResolveResult;
  String? clipboardToken;
  LinkProcessingMode mode = LinkProcessingMode.all;

  final _controller = StreamController<DeferredLink>.broadcast();
  final List<DeferredLink> delivered = [];

  @override
  Future<void> configure({
    required String clientId,
    required String publicKeyId,
    required SdkOptions options,
  }) async {
    assert(clientId.isNotEmpty);
    assert(publicKeyId.isNotEmpty);
    assert(options.apiBaseUrl.isNotEmpty);
    configured = true;
    mode = options.linkProcessingMode;
    readyForNavigation = false;
    pendingDeferred = null;
  }

  @override
  Future<DeferredLink?> resolveDeferred() async {
    if (!configured) return null;
    if (mode == LinkProcessingMode.webOnly) return null;
    var link = nextResolveResult;
    nextResolveResult = null;
    final token = clipboardToken;
    if (link == null && token != null && token.trim().isNotEmpty) {
      clipboardToken = null;
      link = DeferredLink(
        url: 'https://links.example.com/open?click_id=${Uri.encodeComponent(token)}',
        path: '/home',
        linkId: 'clip_$token',
        matchType: MatchType.clipboard,
        isDeferred: true,
        params: {'click_id': token},
      );
    }
    if (link == null) return null;
    pendingDeferred = link;
    if (readyForNavigation) {
      _emit(link);
    }
    return link;
  }

  @override
  Stream<DeferredLink> observeLinks() {
    // Multi-stream so listeners attach to [_controller] synchronously on listen
    // (async* + yield* can miss events emitted in the same turn).
    return Stream<DeferredLink>.multi((listener) {
      if (readyForNavigation &&
          pendingDeferred != null &&
          mode != LinkProcessingMode.webOnly) {
        listener.add(pendingDeferred!);
      }
      final sub = _controller.stream.listen(
        listener.add,
        onError: listener.addError,
        onDone: listener.close,
      );
      listener.onCancel = () {
        sub.cancel();
      };
    });
  }

  /// Test helper: push a warm (non-deferred) link, honoring [mode].
  void emitWarm(DeferredLink link) {
    if (mode == LinkProcessingMode.deferredOnly) return;
    _emit(link);
  }

  @override
  Future<void> consume(String linkId) async {
    if (pendingDeferred?.linkId == linkId) {
      pendingDeferred = null;
    }
  }

  @override
  Future<void> setReadyForNavigation(bool ready) async {
    readyForNavigation = ready;
    if (!ready) return;
    final pending = pendingDeferred;
    if (pending != null && mode != LinkProcessingMode.webOnly) {
      _emit(pending);
    }
  }

  void _emit(DeferredLink link) {
    delivered.add(link);
    if (!_controller.isClosed) {
      _controller.add(link);
    }
  }

  Future<void> dispose() => _controller.close();
}
