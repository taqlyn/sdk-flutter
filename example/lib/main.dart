import 'dart:async';

import 'package:flutter/material.dart';
import 'package:taqlyn_nav_go_router/taqlyn_nav_go_router.dart';
import 'package:taqlyn_sdk/taqlyn_sdk.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const TaqlynExampleApp());
}

class TaqlynExampleApp extends StatefulWidget {
  const TaqlynExampleApp({super.key});

  @override
  State<TaqlynExampleApp> createState() => _TaqlynExampleAppState();
}

class _TaqlynExampleAppState extends State<TaqlynExampleApp> {
  final _pending = PendingDeepLink();
  StreamSubscription<DeferredLink>? _sub;
  String _status = 'starting';
  DeferredLink? _lastLink;

  @override
  void initState() {
    super.initState();
    unawaited(_bootstrap());
  }

  Future<void> _bootstrap() async {
    // 1) configure
    await TaqlynSdk.configure(
      clientId: const String.fromEnvironment(
        'TAQLYN_CLIENT_ID',
        defaultValue: 'app_test_demo',
      ),
      publicKeyId: const String.fromEnvironment(
        'TAQLYN_PUBLIC_KEY_ID',
        defaultValue: 'pk_test_demo',
      ),
      options: const SdkOptions(
        apiBaseUrl: String.fromEnvironment(
          'TAQLYN_API_BASE',
          defaultValue: 'https://api.example.com',
        ),
        linkProcessingMode: LinkProcessingMode.all,
        env: 'sandbox',
      ),
    );

    // 2) listen observeLinks (deferred gated natively until ready)
    _sub = TaqlynSdk.observeLinks().listen((link) async {
      _pending.set(link);
      setState(() {
        _lastLink = link;
        _status = 'observed ${link.path} (${link.linkId})';
      });
      // 5) consume after handoff
      await TaqlynSdk.consume(link.linkId);
      _pending.clear(linkId: link.linkId, idOf: (o) => (o as DeferredLink).linkId);
    });

    // 3) resolveDeferred
    setState(() => _status = 'resolving deferred…');
    final deferred = await TaqlynSdk.resolveDeferred();
    setState(() {
      _status = deferred == null
          ? 'no deferred match (organic / already resolved / soft-fail)'
          : 'resolved deferred ${deferred.linkId} — waiting for ready gate';
      _lastLink = deferred ?? _lastLink;
    });

    // 4) setReadyForNavigation after splash / auth
    await TaqlynSdk.setReadyForNavigation(true);
    _pending.setReady(true);
    setState(() => _status = '$_status → readyForNavigation=true');
  }

  @override
  void dispose() {
    unawaited(_sub?.cancel() ?? Future<void>.value());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Taqlyn SDK Example',
      home: Scaffold(
        appBar: AppBar(title: const Text('Taqlyn Flutter SDK')),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_status),
              const SizedBox(height: 12),
              Text('Pending gate: ${_pending.link == null ? '(none)' : 'held'}'),
              const SizedBox(height: 12),
              if (_lastLink != null) ...[
                Text('Last link path: ${_lastLink!.path}'),
                Text('matchType: ${_lastLink!.matchType.wireValue}'),
                Text('isDeferred: ${_lastLink!.isDeferred}'),
              ],
              const Spacer(),
              const Text(
                'Demo: configure → resolveDeferred → setReadyForNavigation → '
                'observeLinks → consume.\n'
                'Imports taqlyn_sdk (+ soft nav-go-router) only — '
                'never OS referrer or clipboard kits.',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
