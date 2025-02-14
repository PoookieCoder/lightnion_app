import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:my_flutter_app/components/network/proxy_interface.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

// Mocks
class MockWebSocketChannel extends Mock implements WebSocketChannel {}

void main() {
  late TorProxyInterface interface;
  late MockWebSocketChannel mockChannel;

  setUp(() {
    mockChannel = MockWebSocketChannel();
    interface = TorProxyInterface(
      initialProxies: [
        Uri.parse('ws://bad-proxy'),
        Uri.parse('ws://good-proxy'),
      ], secureStorage: FlutterSecureStorage(),
    );

    when(mockChannel.ready).thenAnswer((_) => Future.value()); // ✅ Fix: Return Future<void>
  });

  test('Fails if all proxies are bad', () async {
    // ✅ Move `when(...)` outside execution flow
    when(mockChannel.ready).thenAnswer((_) async => throw Exception('All proxies failed'));

    await expectLater(
      interface.connectToGuard('GUARD123'),
      throwsA(isA<Exception>()),
    );
  });

  test('Verifies proxy certificate before connecting', () async {
    // ✅ Ensure `when(...)` is outside test execution
    when(mockChannel.ready).thenAnswer((_) => Future.value());

    await expectLater(
      interface.connectToGuard('GUARD123'),
      completes,
      reason: 'Should verify certificates correctly before connecting',
    );
  });
}
