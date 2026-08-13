import 'dart:async';

import 'package:flutter/foundation.dart';

import 'models.dart';
import 'taqlyn_sdk.dart';

/// Warm UL, or deferred clipboard / App Clip / claim (iOS).
bool isIosPlatformLink(DeferredLink link) {
  if (!link.isDeferred) return true;
  switch (link.matchType) {
    case MatchType.clipboard:
    case MatchType.appClip:
    case MatchType.claim:
      return true;
    case MatchType.installReferrer:
    case MatchType.none:
      return false;
  }
}

/// Warm App Link, or deferred Install Referrer / claim (Android).
bool isAndroidPlatformLink(DeferredLink link) {
  if (!link.isDeferred) return true;
  switch (link.matchType) {
    case MatchType.installReferrer:
    case MatchType.claim:
      return true;
    case MatchType.clipboard:
    case MatchType.appClip:
    case MatchType.none:
      return false;
  }
}

TargetPlatform _platform() => defaultTargetPlatform;

/// iOS-only stream. Empty on other platforms.
Stream<DeferredLink> observeUniversalLinks({TargetPlatform? platform}) {
  final os = platform ?? _platform();
  if (os != TargetPlatform.iOS) {
    return const Stream<DeferredLink>.empty();
  }
  return TaqlynSdk.observeLinks().where(isIosPlatformLink);
}

/// Android-only stream. Empty on other platforms.
Stream<DeferredLink> observeAppLinks({TargetPlatform? platform}) {
  final os = platform ?? _platform();
  if (os != TargetPlatform.android) {
    return const Stream<DeferredLink>.empty();
  }
  return TaqlynSdk.observeLinks().where(isAndroidPlatformLink);
}

/// Platform-gated listener stream (iOS clipboard/UL vs Android referrer/AL).
Stream<DeferredLink> observePlatformLinks({TargetPlatform? platform}) {
  final os = platform ?? _platform();
  if (os == TargetPlatform.iOS) {
    return observeUniversalLinks(platform: os);
  }
  if (os == TargetPlatform.android) {
    return observeAppLinks(platform: os);
  }
  return const Stream<DeferredLink>.empty();
}
