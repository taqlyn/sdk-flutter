import 'events.dart';
import 'expand.dart';
import 'models.dart';
import 'native_bridge.dart';
import 'share.dart';

export 'models.dart';
export 'share.dart' show ShareLink;

/// Public Dart facade matching [sdk-contract] / native SdkCore.
///
/// Feature and sample code import this API only — never OS referrer /
/// pasteboard kits. The production bridge is MethodChannel → native SdkCore.
class TaqlynSdk {
  TaqlynSdk._();

  static NativeBridge _bridge = MethodChannelNativeBridge();
  static ShareSession? _session;
  static SdkOptions _options = const SdkOptions();
  static final ShareClient _shareClient = ShareClient();
  static final ExpandClient _expandClient = ExpandClient();
  static final EventsClient _eventsClient = EventsClient();

  /// Override the native bridge (unit tests only).
  static void debugBindBridge(NativeBridge bridge) {
    _bridge = bridge;
  }

  /// Restore the production MethodChannel bridge.
  static void debugResetBridge() {
    _bridge = MethodChannelNativeBridge();
    _session = null;
    _options = const SdkOptions();
  }

  /// Configure early in process lifetime (after `WidgetsFlutterBinding`).
  static Future<void> configure({
    required String clientId,
    required String publicKeyId,
    SdkOptions options = const SdkOptions(),
  }) {
    _session = ShareSession(
      clientId: clientId.trim(),
      publicKeyId: publicKeyId.trim(),
      env: options.env,
    );
    _options = options;
    return _bridge.configure(
      clientId: clientId,
      publicKeyId: publicKeyId,
      options: options,
    );
  }

  /// Expand a short URL via POST /v1/links/expand.
  static Future<ExpandResult?> resolveShortLink(String url) async {
    final session = _session;
    if (session == null) return null;
    return _expandClient.expand(session: session, url: url);
  }

  /// Map an incoming URL using hosts + short-code heuristic and resolveMode.
  static Future<ResolvedNavTarget?> resolveIncomingUrl(String url) async {
    final session = _session;
    if (session == null) return pathMapOnly(url);
    if (!shouldExpand(url, _options.hosts)) return pathMapOnly(url);
    final fallback =
        (_options.fallbackPath == null || _options.fallbackPath!.isEmpty)
            ? '/'
            : _options.fallbackPath!;
    final clientMode = _options.resolveMode ?? ResolveMode.awaitMode;
    if (clientMode == ResolveMode.optimistic) {
      return ResolvedNavTarget(href: fallback, pendingExpand: true);
    }
    final timeoutMs = _options.timeoutMs < 100 ? 100 : _options.timeoutMs;
    final result = await withTimeoutMs(timeoutMs, () => resolveShortLink(url));
    if (result != null) {
      return ResolvedNavTarget(
        href: hrefFromExpand(result),
        linkId: result.linkId,
      );
    }
    return ResolvedNavTarget(href: fallback);
  }

  /// Mint a unified short link for in-app sharing (public key id only).
  static Future<ShareLink> createShareLink({
    String? destinationPath,
    String? destinationWeb,
    Map<String, String>? params,
    String? ogTitle,
    String? ogDescription,
    String? ogImage,
  }) {
    final session = _session;
    if (session == null) {
      throw StateError('configure before createShareLink');
    }
    return _shareClient.create(
      session: session,
      destinationPath: destinationPath,
      destinationWeb: destinationWeb,
      params: params,
      ogTitle: ogTitle,
      ogDescription: ogDescription,
      ogImage: ogImage,
    );
  }

  /// Resolve deferred link once after install (native Match cascade).
  static Future<DeferredLink?> resolveDeferred() => _bridge.resolveDeferred();

  /// Warm UL/AL + deferred links (deferred gated by ready flag natively).
  ///
  /// Prefer [observePlatformLinks] / `package:taqlyn_sdk/ios.dart` /
  /// `package:taqlyn_sdk/android.dart` so clipboard matches stay on iOS and
  /// Install Referrer stays on Android.
  static Stream<DeferredLink> observeLinks() => _bridge.observeLinks();

  /// Report that the SDK opened/consumed a link (fire-and-forget).
  static Future<void> trackOpen(String linkId) async {
    final session = _session;
    if (session == null) return;
    await _eventsClient.trackOpen(session: session, linkId: linkId);
  }

  /// Custom SDK analytics event (fire-and-forget).
  static Future<void> logEvent(
    String name, {
    Map<String, Object?>? data,
  }) async {
    final session = _session;
    if (session == null) return;
    await _eventsClient.logEvent(session: session, name: name, data: data);
  }

  /// Clear pending deferred when [linkId] matches.
  static Future<void> consume(String linkId) async {
    await _bridge.consume(linkId);
    await trackOpen(linkId);
  }

  /// When true, deliver any pending deferred link to [observeLinks].
  static Future<void> setReadyForNavigation(bool ready) =>
      _bridge.setReadyForNavigation(ready);
}
