import 'dart:typed_data';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter/services.dart';

class TorProxyInterface {
  static const _proxyRotationDelay = Duration(seconds: 2);
  final List<Uri> _proxies;
  final _certificateCache = <String, String>{};
  final _storage = FlutterSecureStorage();
  
  final FlutterSecureStorage secureStorage;
  TorProxyInterface({
    List<Uri>? initialProxies,
    required this.secureStorage,
  }) : _proxies = initialProxies ?? _defaultCispaProxies;

  static List<Uri> get _defaultCispaProxies => [
    Uri.parse('wss://proxy1.cispa.de/tor/ws'),
    Uri.parse('wss://proxy2.cispa.de/tor/ws'),
  ];

  Future<ProxyConnection> connectToGuard(String guardFingerprint) async {
    for (var attempt = 0; attempt < _proxies.length; attempt++) {
      final proxy = _proxies[attempt % _proxies.length];
      try {
        await _verifyProxyCertificate(proxy);
        final channel = WebSocketChannel.connect(_buildConnectionUri(
          proxy: proxy,
          guardFingerprint: guardFingerprint,
        ));

        await channel.ready.timeout(const Duration(seconds: 10));
        return ProxyConnection(
          channel: channel,
          proxyUri: proxy,
          guardFingerprint: guardFingerprint,
        );
      } catch (e) {
        _rotateProxies();
        await Future.delayed(_proxyRotationDelay);
      }
    }
    throw Exception('All proxy connections failed');
  }
  Future<void> initialize() async {
    // Pre-connect to first proxy
    await _warmupProxyConnections();
  }

  Future<void> _warmupProxyConnections() async {
    // Implementation for pre-connecting
  }

  Future<void> _verifyProxyCertificate(Uri proxy) async {
    final host = proxy.host;
    final cachedCert = await _storage.read(key: 'pinned_cert:$host');
    final currentCert = await _fetchServerCertificate(proxy);
    
    if (cachedCert == null) {
      await _storage.write(key: 'pinned_cert:$host', value: currentCert);
    } else if (cachedCert != currentCert) {
      throw ProxySecurityException('Certificate mismatch for $host');
    }
  }

  Future<String> _fetchServerCertificate(Uri proxy) async {
    if (_certificateCache.containsKey(proxy.host)) {
      return _certificateCache[proxy.host]!;
    }

    // Platform-specific certificate fetching
    final cert = await _platformChannel.invokeMethod<String>(
      'getServerCertificate',
      {'host': proxy.host, 'port': proxy.port},
    );

    final hash = (await Sha256().hash(cert!.codeUnits)).bytes.toHex();
    _certificateCache[proxy.host] = hash;
    return hash;
  }

  Uri _buildConnectionUri({
    required Uri proxy,
    required String guardFingerprint,
  }) {
    return Uri(
      scheme: proxy.scheme,
      host: proxy.host,
      port: proxy.port,
      path: proxy.path,
      queryParameters: {
        'guard': guardFingerprint,
        'protocol': 'v3',
      },
    );
  }

  void _rotateProxies() {
    // Move first proxy to end of list
    _proxies.add(_proxies.removeAt(0));
  }

  static final MethodChannel _platformChannel =
      MethodChannel('network.security');
}

// ✅ Defined ProxySecurityException
class ProxySecurityException implements Exception {
  final String message;
  ProxySecurityException(this.message);

  @override
  String toString() => 'ProxySecurityException: $message';
}

class ProxyConnection {
  final WebSocketChannel channel;
  final Uri proxyUri;
  final String guardFingerprint;
  
  ProxyConnection({
    required this.channel,
    required this.proxyUri,
    required this.guardFingerprint,
  });

  Future<void> sendTorCell(Uint8List cell) async {
    channel.sink.add(cell);
  }

  Stream<Uint8List> get stream => channel.stream.map((data) {
    if (data is List<int>) return Uint8List.fromList(data);
    if (data is String) return Uint8List.fromList(data.codeUnits);
    throw FormatException('Invalid proxy response type');
  });

  Future<void> close() async {
    await channel.sink.close();
  }
}

extension _HexConversion on List<int> {
  String toHex() => map((byte) => byte.toRadixString(16).padLeft(2, '0')).join(':');
}
