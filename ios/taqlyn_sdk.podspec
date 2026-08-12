#
# Taqlyn Flutter plugin — MethodChannel bridge → native SdkCore.
#
Pod::Spec.new do |s|
  s.name             = 'taqlyn_sdk'
  s.version          = '0.1.0'
  s.summary          = 'Taqlyn deferred deep links Flutter plugin'
  s.description      = <<-DESC
Thin Flutter wrapper over native Android/iOS SdkCore. App Dart never imports
Play Install Referrer / UIPasteboard.
                       DESC
  s.homepage         = 'https://github.com/taqlyn/sdk-flutter'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Taqlyn' => 'dev@taqlyn.com' }
  s.source           = { :path => '.' }
  s.dependency 'Flutter'
  s.platform = :ios, '16.0'
  s.swift_version = '5.9'
  s.pod_target_xcconfig = {
    'DEFINES_MODULE' => 'YES',
    'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386'
  }

  # Monorepo layout: packages/sdk-flutter next to packages/sdk-ios.
  # Copy sibling SdkCore sources into this pod so `import TaqlynSDK` is unnecessary
  # (types compile into the plugin module). Prefer SPM path for Xcode SPM consumers
  # — see ios/taqlyn_sdk/Package.swift → path: ../../../sdk-ios
  s.prepare_command = <<-CMD
    set -e
    VENDOR="taqlyn_sdk/Sources/TaqlynSDKCore"
    mkdir -p "$VENDOR"
    rm -rf "$VENDOR"/*
    SDK_IOS="../../sdk-ios/Sources/TaqlynSDK"
    if [ -d "$SDK_IOS" ]; then
      cp -R "$SDK_IOS"/. "$VENDOR"/
    else
      echo "warning: sdk-ios not found at $SDK_IOS — open monorepo packages/ layout" >&2
    fi
  CMD

  s.source_files = 'taqlyn_sdk/Sources/taqlyn_sdk/**/*.{swift}', 'taqlyn_sdk/Sources/TaqlynSDKCore/**/*.{swift}'
  s.resource_bundles = {
    'taqlyn_sdk_privacy' => ['taqlyn_sdk/Sources/taqlyn_sdk/PrivacyInfo.xcprivacy']
  }
end
