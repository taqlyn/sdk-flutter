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
  static ShareClient _shareClient = ShareClient();

  /// Override the native bridge (unit tests only).
  static void debugBindBridge(NativeBridge bridge) {
    _bridge = bridge;
  }

  /// Restore the production MethodChannel bridge.
  static void debugResetBridge() {
    _bridge = MethodChannelNativeBridge();
    _session = null;
  }

  /// Configure early in process lifetime (after `WidgetsFlutterBinding`).
  ///
  /// [SdkOptions.apiBaseUrl] defaults to [kDefaultApiBaseUrl]; pass it only
  /// to self-host.
  static Future<void> configure({
    required String clientId,
    required String publicKeyId,
    SdkOptions options = const SdkOptions(),
  }) {
    final apiBaseUrl = normalizeApiBaseUrl(options.apiBaseUrl);
    _session = ShareSession(
      clientId: clientId.trim(),
      publicKeyId: publicKeyId.trim(),
      apiBaseUrl: apiBaseUrl,
      env: options.env,
    );
    return _bridge.configure(
      clientId: clientId,
      publicKeyId: publicKeyId,
      options: SdkOptions(
        apiBaseUrl: apiBaseUrl,
        linkProcessingMode: options.linkProcessingMode,
        env: options.env,
      ),
    );
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

  /// Clear pending deferred when [linkId] matches.
  static Future<void> consume(String linkId) => _bridge.consume(linkId);

  /// When true, deliver any pending deferred link to [observeLinks].
  static Future<void> setReadyForNavigation(bool ready) =>
      _bridge.setReadyForNavigation(ready);
}
