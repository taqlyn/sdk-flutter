import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taqlyn_sdk/taqlyn_sdk.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() {
    TaqlynSdk.debugResetBridge();
  });

  group('DeferredLink mapping', () {
    test('fromMap maps sdk-contract wire shape', () {
      final link = DeferredLink.fromMap({
        'url': 'https://app.example/product/1?x=1',
        'path': '/product/1',
        'params': {'x': '1'},
        'linkId': 'lnk_abc',
        'matchType': 'install_referrer',
        'isDeferred': true,
        'campaign': {'utm_source': 'sms', 'utm_campaign': 'spring'},
      });

      expect(link.linkId, 'lnk_abc');
      expect(link.path, '/product/1');
      expect(link.matchType, MatchType.installReferrer);
      expect(link.isDeferred, isTrue);
      expect(link.campaign?.utmSource, 'sms');
      expect(link.toMap()['matchType'], 'install_referrer');
    });
  });

  group('FakeNativeBridge ready-gate', () {
    test('deferred link held until setReadyForNavigation(true)', () async {
      final bridge = FakeNativeBridge();
      TaqlynSdk.debugBindBridge(bridge);

      await TaqlynSdk.configure(
        clientId: 'app_test',
        publicKeyId: 'pk_test',
        options: const SdkOptions(apiBaseUrl: 'https://api.example.com'),
      );

      bridge.nextResolveResult = const DeferredLink(
        url: 'https://app.example/offer',
        path: '/offer',
        linkId: 'lnk_1',
        matchType: MatchType.installReferrer,
        isDeferred: true,
        params: {'sku': '42'},
      );

      final seen = <DeferredLink>[];
      final sub = TaqlynSdk.observeLinks().listen(seen.add);

      final resolved = await TaqlynSdk.resolveDeferred();
      expect(resolved?.linkId, 'lnk_1');
      expect(seen, isEmpty);
      expect(bridge.pendingDeferred?.linkId, 'lnk_1');

      await TaqlynSdk.setReadyForNavigation(true);
      await Future<void>.delayed(Duration.zero);

      expect(seen, hasLength(1));
      expect(seen.single.path, '/offer');
      expect(seen.single.params['sku'], '42');

      await TaqlynSdk.consume('lnk_1');
      expect(bridge.pendingDeferred, isNull);

      await sub.cancel();
      await bridge.dispose();
    });

    test('webOnly mode skips deferred resolve delivery', () async {
      final bridge = FakeNativeBridge();
      TaqlynSdk.debugBindBridge(bridge);

      await TaqlynSdk.configure(
        clientId: 'app_test',
        publicKeyId: 'pk_test',
        options: const SdkOptions(
          apiBaseUrl: 'https://api.example.com',
          linkProcessingMode: LinkProcessingMode.webOnly,
        ),
      );

      bridge.nextResolveResult = const DeferredLink(
        url: 'https://app.example/x',
        path: '/x',
        linkId: 'lnk_x',
        matchType: MatchType.clipboard,
        isDeferred: true,
      );

      expect(await TaqlynSdk.resolveDeferred(), isNull);
      await bridge.dispose();
    });

    test('warm UL/AL delivered via observe without ready gate', () async {
      final bridge = FakeNativeBridge();
      TaqlynSdk.debugBindBridge(bridge);

      await TaqlynSdk.configure(
        clientId: 'app_test',
        publicKeyId: 'pk_test',
        options: const SdkOptions(apiBaseUrl: 'https://api.example.com'),
      );

      final seen = <DeferredLink>[];
      final sub = TaqlynSdk.observeLinks().listen(seen.add);

      bridge.emitWarm(
        const DeferredLink(
          url: 'https://links.example.com/product/9',
          path: '/product/9',
          linkId: 'warm_1',
          matchType: MatchType.none,
          isDeferred: false,
        ),
      );
      await Future<void>.delayed(Duration.zero);

      expect(seen, hasLength(1));
      expect(seen.single.isDeferred, isFalse);
      expect(seen.single.path, '/product/9');

      await sub.cancel();
      await bridge.dispose();
    });
  });

  group('MethodChannelNativeBridge', () {
    const channel = MethodChannel('taqlyn_sdk');
    final log = <MethodCall>[];

    setUp(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
        log.add(call);
        if (call.method == 'resolveDeferred') {
          return {
            'url': 'https://app.example/p',
            'path': '/p',
            'params': <String, String>{},
            'linkId': 'lnk_ch',
            'matchType': 'clipboard',
            'isDeferred': true,
          };
        }
        return null;
      });
      TaqlynSdk.debugBindBridge(MethodChannelNativeBridge());
    });

    tearDown(() {
      log.clear();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    test('configure / ready / consume / resolve map through channel', () async {
      await TaqlynSdk.configure(
        clientId: 'app_test',
        publicKeyId: 'pk_test',
        options: const SdkOptions(
          apiBaseUrl: 'https://api.example.com',
          linkProcessingMode: LinkProcessingMode.deferredOnly,
          env: 'sandbox',
        ),
      );
      await TaqlynSdk.setReadyForNavigation(true);
      await TaqlynSdk.consume('lnk_ch');
      final link = await TaqlynSdk.resolveDeferred();

      expect(log.map((c) => c.method), [
        'configure',
        'setReadyForNavigation',
        'consume',
        'resolveDeferred',
      ]);
      expect(link?.linkId, 'lnk_ch');
      expect(link?.matchType, MatchType.clipboard);

      final configureArgs = log.first.arguments as Map;
      final options = configureArgs['options'] as Map;
      expect(options['linkProcessingMode'], 'deferredOnly');
      expect(options['env'], 'sandbox');
    });
  });
}
