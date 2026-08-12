import 'package:flutter_test/flutter_test.dart';
import 'package:taqlyn_sdk/taqlyn_sdk.dart';
import 'package:taqlyn_sdk_example/main.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    final bridge = FakeNativeBridge();
    TaqlynSdk.debugBindBridge(bridge);
  });

  tearDown(() {
    TaqlynSdk.debugResetBridge();
  });

  testWidgets('example app builds', (tester) async {
    await tester.pumpWidget(const TaqlynExampleApp());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.textContaining('Taqlyn'), findsWidgets);
  });
}
