import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:taqlyn_sdk/taqlyn_sdk.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('configure + resolveDeferred soft-complete on device', (tester) async {
    await TaqlynSdk.configure(
      clientId: 'app_test_demo',
      publicKeyId: 'pk_test_demo',
      options: const SdkOptions(apiBaseUrl: 'https://api.example.com'),
    );
    final link = await TaqlynSdk.resolveDeferred();
    // Organic / no referrer on simulators → null is success for smoke.
    expect(link == null || link.linkId.isNotEmpty, isTrue);
    await TaqlynSdk.setReadyForNavigation(true);
  });
}
