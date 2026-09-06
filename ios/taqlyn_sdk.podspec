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
  s.dependency 'TaqlynSDK', '~> 0.1'
  s.platform = :ios, '16.0'
  s.swift_version = '5.9'
  s.pod_target_xcconfig = {
    'DEFINES_MODULE' => 'YES',
    'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386'
  }

  s.source_files = 'taqlyn_sdk/Sources/taqlyn_sdk/**/*.{swift}'
  s.resource_bundles = {
    'taqlyn_sdk_privacy' => ['taqlyn_sdk/Sources/taqlyn_sdk/PrivacyInfo.xcprivacy']
  }
end
