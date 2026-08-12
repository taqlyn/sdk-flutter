import 'models.dart';
import 'native_bridge.dart';

export 'models.dart';
export 'native_bridge.dart';

/// Public Dart facade matching [sdk-contract] / native SdkCore.
///
/// Feature and sample code import this API only — never OS referrer /
/// pasteboard kits.
class TaqlynSdk {
  TaqlynSdk._();

  static NativeBridge _bridge = MethodChannelNativeBridge();

  /// Override the native bridge (tests / custom embeddings).
  static void debugBindBridge(NativeBridge bridge) {
    _bridge = bridge;
  }

  /// Restore the production MethodChannel bridge.
  static void debugResetBridge() {
    _bridge = MethodChannelNativeBridge();
  }

  /// Configure early in process lifetime (after `WidgetsFlutterBinding`).
  static Future<void> configure({
    required String clientId,
    required String publicKeyId,
    required SdkOptions options,
  }) {
    return _bridge.configure(
      clientId: clientId,
      publicKeyId: publicKeyId,
      options: options,
    );
  }

  /// Resolve deferred link once after install (native Match cascade).
  static Future<DeferredLink?> resolveDeferred() => _bridge.resolveDeferred();

  /// Warm UL/AL + deferred links (deferred gated by ready flag natively).
  static Stream<DeferredLink> observeLinks() => _bridge.observeLinks();

  /// Clear pending deferred when [linkId] matches.
  static Future<void> consume(String linkId) => _bridge.consume(linkId);

  /// When true, deliver any pending deferred link to [observeLinks].
  static Future<void> setReadyForNavigation(bool ready) =>
      _bridge.setReadyForNavigation(ready);
}
