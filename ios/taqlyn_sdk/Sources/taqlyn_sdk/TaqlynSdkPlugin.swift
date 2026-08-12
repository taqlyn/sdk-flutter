import Flutter
import UIKit

#if canImport(TaqlynSDK)
import TaqlynSDK
#endif

/// Flutter embedding → TaqlynSDK.SdkCore. App Dart never sees UIPasteboard types.
///
/// When CocoaPods compiles sibling `sdk-ios` sources into this pod (monorepo
/// prepare_command), SdkCore types live in the same module and need no import.
public class TaqlynSdkPlugin: NSObject, FlutterPlugin, FlutterStreamHandler {
  private var eventSink: FlutterEventSink?
  private var observeTask: Task<Void, Never>?

  public static func register(with registrar: FlutterPluginRegistrar) {
    let instance = TaqlynSdkPlugin()
    let method = FlutterMethodChannel(name: "taqlyn_sdk", binaryMessenger: registrar.messenger())
    registrar.addMethodCallDelegate(instance, channel: method)

    let links = FlutterEventChannel(name: "taqlyn_sdk/links", binaryMessenger: registrar.messenger())
    links.setStreamHandler(instance)
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "configure":
      guard let args = call.arguments as? [String: Any],
            let clientId = args["clientId"] as? String,
            let publicKeyId = args["publicKeyId"] as? String,
            let optionsMap = args["options"] as? [String: Any],
            let apiBaseUrl = optionsMap["apiBaseUrl"] as? String
      else {
        result(
          FlutterError(
            code: "bad_args",
            message: "configure requires clientId, publicKeyId, options",
            details: nil
          )
        )
        return
      }
      let modeWire = optionsMap["linkProcessingMode"] as? String
      let env = optionsMap["env"] as? String
      SdkCore.configure(
        clientId: clientId,
        publicKeyId: publicKeyId,
        options: SdkOptions(
          apiBaseUrl: apiBaseUrl,
          linkProcessingMode: Self.modeFromWire(modeWire),
          env: env
        )
      )
      result(nil)

    case "resolveDeferred":
      Task {
        let link = await SdkCore.resolveDeferred()
        result(link.map { Self.linkToMap($0) })
      }

    case "consume":
      let linkId = (call.arguments as? [String: Any])?["linkId"] as? String ?? ""
      SdkCore.consume(linkId)
      result(nil)

    case "setReadyForNavigation":
      let ready = (call.arguments as? [String: Any])?["ready"] as? Bool ?? false
      SdkCore.setReadyForNavigation(ready)
      result(nil)

    default:
      result(FlutterMethodNotImplemented)
    }
  }

  public func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink)
    -> FlutterError?
  {
    eventSink = events
    observeTask?.cancel()
    observeTask = Task {
      for await link in SdkCore.observeLinks() {
        if Task.isCancelled { break }
        events(Self.linkToMap(link))
      }
    }
    return nil
  }

  public func onCancel(withArguments arguments: Any?) -> FlutterError? {
    observeTask?.cancel()
    observeTask = nil
    eventSink = nil
    return nil
  }

  /// Forward Universal Links / custom URLs into native SdkCore (call from AppDelegate).
  public static func handleOpenURL(_ url: URL) {
    SdkCore.onOpenURL(url)
  }

  private static func modeFromWire(_ value: String?) -> LinkProcessingMode {
    switch value {
    case "webOnly", "web-only", "WEB_ONLY":
      return .webOnly
    case "deferredOnly", "deferred-only", "DEFERRED_ONLY":
      return .deferredOnly
    default:
      return .all
    }
  }

  private static func linkToMap(_ link: DeferredLink) -> [String: Any?] {
    [
      "url": link.url,
      "path": link.path,
      "params": link.params,
      "linkId": link.linkId,
      "matchType": link.matchType.wireValue,
      "isDeferred": link.isDeferred,
      "campaign": link.campaign?.values,
    ]
  }
}
