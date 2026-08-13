# Taqlyn Flutter SDK (`taqlyn_sdk`)

Thin Flutter plugin that delegates to canonical native **SdkCore**
(`packages/sdk-android`, `packages/sdk-ios`). Pub name: **`taqlyn_sdk`**.

App / sample Dart imports this package only — **never** Play Install Referrer
or `UIPasteboard` types. Deferred Match stays in Kotlin/Swift.

## Public API (sdk-contract)

```dart
await TaqlynSdk.configure(
  clientId: 'app_…',
  publicKeyId: 'pk_…',
  options: SdkOptions(
    // apiBaseUrl optional — defaults to kDefaultApiBaseUrl (self-host: pass yours)
    linkProcessingMode: LinkProcessingMode.all, // all | webOnly | deferredOnly
    env: 'sandbox',
  ),
);

final share = await TaqlynSdk.createShareLink(destinationPath: '/offer');

final deferred = await TaqlynSdk.resolveDeferred(); // DeferredLink?
TaqlynSdk.observePlatformLinks().listen((link) async {
  // iOS: clipboard / UL. Android: referrer / App Links.
  await TaqlynSdk.consume(link.linkId);
});
// Or `package:taqlyn_sdk/ios.dart` / `package:taqlyn_sdk/android.dart`.
await TaqlynSdk.setReadyForNavigation(true);
```

`DeferredLink` mirrors `packages/sdk-contract`: `url`, `path`, `params`,
`linkId`, `matchType`, `isDeferred`, `campaign`.

## Architecture

```text
Dart TaqlynSdk  →  MethodChannelNativeBridge (real plugin channel)
                      ├─ Android FlutterPlugin → com.taqlyn.sdk.SdkCore
                      └─ iOS FlutterPlugin     → TaqlynSDK.SdkCore
```

App / example code must use the MethodChannel bridge only. Unit tests may import `package:taqlyn_sdk/testing.dart`.

Optional soft helper: monorepo `packages/nav-go-router` (`PendingDeepLink`) for
go_router redirect races — no Match logic.

## Platform setup checklist

### iOS

- [ ] Host **AASA** at `https://<host>/.well-known/apple-app-site-association`
- [ ] Enable **Associated Domains** (`applinks:<host>`) on the Runner target
- [ ] Call after `WidgetsFlutterBinding.ensureInitialized()` before `configure`
- [ ] Forward Universal Links: `TaqlynSdkPlugin.handleOpenURL(url)` from AppDelegate / scene
- [ ] Native SdkCore linked via plugin podspec (monorepo copies `../sdk-ios` Sources) or SPM path `ios/taqlyn_sdk/Package.swift` → `../../../sdk-ios`
- [ ] Deployment target **iOS 16+** (matches sdk-ios)

### Android

- [ ] Host **assetlinks.json** with Play App Signing SHA-256
- [ ] App Links intent filter + `android:autoVerify="true"` on the Activity
- [ ] Plugin Gradle depends on sibling `:taqlyn-sdk` (`packages/sdk-android/taqlyn-sdk`)
- [ ] In the **host app** `android/settings.gradle(.kts)`, include the native module:

```kotlin
include(":taqlyn-sdk")
project(":taqlyn-sdk").projectDir =
    file("../../sdk-android/taqlyn-sdk") // adjust relative path
```

Composite-build alternative:

```kotlin
includeBuild("../sdk-android") {
    dependencySubstitution {
        substitute(module("com.taqlyn.sdk:taqlyn-sdk")).using(project(":taqlyn-sdk"))
    }
}
```

(Requires publishing coordinates on the Android library when using Maven substitution.)

- [ ] Emulators often **cannot** exercise Play Install Referrer — use a real device

## Example

See [`example/`](example/) — flow:

`configure` → `resolveDeferred` → `setReadyForNavigation` → `observeLinks` → `consume`

Soft-uses `taqlyn_nav_go_router` for a pending-link holder.

```bash
cd example && flutter run
# Optional dart-defines (defaults → https://api.rutvik.qzz.io):
# --dart-define=TAQLYN_API_BASE=https://api.rutvik.qzz.io
# --dart-define=TAQLYN_CLIENT_ID=app_test_…
# --dart-define=TAQLYN_PUBLIC_KEY_ID=pk_test_…
```

Public tunnel: [docs/guides/public-demo.md](../../docs/guides/public-demo.md), seed with `./scripts/demo-seed.sh`.

## Tests

```bash
# from packages/sdk-flutter
flutter test
```

- Fake `NativeBridge` proves ready-gate + `DeferredLink` mapping
- Mock `MethodChannel` proves channel argument mapping
- Source-guard: `example/lib` must not contain `installreferrer` / `UIPasteboard`

### Native bridge host + example assemble (closes deferred / host risks)

```bash
# Android bridge → SdkCore (fake Install Referrer + sandbox ResolveClient)
cd android-host
./gradlew :bridge:testDebugUnitTest :bridge:assembleRelease

# Full Flutter host APK (plugin + example + sibling :taqlyn-sdk)
cd example && flutter build apk --debug
```


## License

See [LICENSE](LICENSE).
