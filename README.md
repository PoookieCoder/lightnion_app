# Lightnion Mobile - A Tor-Based Privacy Solution

## Overview
Lightnion Mobile 
- Tor client optimized for mobile environments.
- Lightnion's core functionalities to enhance privacy, security, and network resilience on mobile devices.

## IDEAS: 
### Feature Ideas
- **Tor Circuit Management**: Lean TCP connections, Port from JavaScript to Dart, Managing TCP connections..
- **Proxy Interface**: WebSocket-based proxy communication with auto-reconnection. Handling NAT traversal and IP address changes.
- **Cryptographic Implementation**: `AES-128-CTR encryption`, `SHA-3` digest calculations, and secure enclave integration using `FlutterSecureStorage`. platform specific optimizations.
- **Network Handling**: NAT traversal, and proxy failover mechanisms. Handling network transitions (WiFi ↔ Cellular).
- **Enhanced Security Model**: Runtime integrity checks, certificate pinning, and cold-boot attack mitigation.
- **Background Service**: Maintaining active circuits while the app is in the background. (Using WorkManager on Android and BackgroundTasks on iOS.)

### Implementation idea: Directory Structure
```
lightnion_app/
├── android/                  # Platform-specific configuration
│   ├── jniLibs/              # Native crypto libraries
│   └── res/xml/              # Network security configuration
│
├── ios/
│   ├── AppDelegate.swift     # Background mode config
│   ├── Info.plist            # Privacy permissions
│
├── lib/
│   ├── core/
│   │   ├── tor_client.dart   # Main Tor client implementation
│   │   ├── circuit_manager.dart   # Circuit lifecycle management
│   │   └── consensus_handler.dart # Tor network consensus handling
│   │
│   ├── components/
│   │   ├── crypto/
│   │   │   ├── aes_handler.dart   # AES-128-CTR implementation
│   │   │   └── ntor_handshake.dart  # Tor handshake protocol
│   │   │
│   │   ├── network/
│   │   │   ├── proxy_interface.dart  # WebSocket proxy communication
│   │   │   └── cell_parser.dart  # Tor cell format handling
│   │
│   ├── services/
│   │   ├── background_service.dart   # Persistent connections
│   │   └── integrity_checker.dart   # Runtime validation
│   │
│   ├── utils/
│   │   ├── isolation_pool.dart   # Crypto worker isolates
│   │   └── network_monitor.dart  # Connectivity handling
│   │
│   ├── screens/ # UI components
│   │   ├── connection_screen.dart
│   │   └── circuit_status.dart
│
├── assets/
│   ├── certs/       # Pinned certificates
│   └── tor_consensus/   # Initial network consensus
│
├── test/ # Tests
│   ├── tor_client_test.dart
│   └── crypto_test.dart
│
└── pubspec.yaml   # Dependencies
```

### Performance Optimization Ideas
- **Circuit Setup Time** Goal: Reduce to <1.8s via preemptive guard selection and parallelized handshakes.
- **Data Throughput** Aim: Achieve 85% of native Tor performance with zero-copy buffer management and SIMD-optimized crypto.
- **Battery Efficiency** Using adaptive circuit expiry and connection throttling for power conservation.
- **Security Considerations** Verifying authenticity of proxy connections. Preventing runtime modification of Dart code.
- **Fallback Mechanisms**: Ensuring continued connectivity even if proxies fail.

## Current Implementations
#### **1. WebSocket Proxy Interface**
```dart
abstract class TorProxyInterface {
  Future<WebSocket> connectToGuard(String guardIP);
  Stream<Uint8List> observeTraffic();
  Future<void> circuitTeardown();
}
```
- Implements mobile-friendly WebSocket communication.
- Optimized for NAT traversal, background persistence, and adaptive reconnections.

#### **2. Circuit Management**
```dart
class CircuitManager {
  Future<void> establishCircuit();
  Future<void> teardownCircuit();
  Stream<TorCell> observeTraffic();
}
```
- Manages Tor circuits efficiently. Supports dynamic guard node selection and circuit expiry heuristics.

#### **3. Cryptographic Security**
```dart
class AesHandler {
  Uint8List encrypt(Uint8List data, Uint8List key);
  Uint8List decrypt(Uint8List data, Uint8List key);
}
```
- Implements AES-128-CTR encryption.

#### **4. Secure Memory Management**
```dart
class KeyVault {
  static Future<void> storeKey({required String alias, required Key key}) async {
    await _channel.invokeMethod('secureStoreKey', {
      'alias': alias,
      'key': _serializeKey(key)
    });
  }
}
```
- Uses platform-specific secure storage for cryptographic keys.

#### **5. Tor Client**
```dart
class TorClient {
  Future<void> initialize();
  Future<Uint8List> anonymousRequest(Uri target);
  Future<void> _performHandshake(Circuit circuit, TorNode node);
  Future<void> _extendCircuit(Circuit circuit, TorNode nextNode);
}
```
- Implements anonymous web requests through Tor circuits. (Dynamically establishing and maintaining circuits with guard, middle, and exit nodes.) 
- Uses X25519-based handshake and AES-128-CTR encryption for secure communication.

## Getting Started
### **Installation**
1. Clone the repository:
   ```sh
   git clone https://github.com/PoookieCoder/lightnion_app.git
   ```
2. Install dependencies:
   ```sh
   flutter pub get
   ```
3. Run the app:
   ```sh
   flutter run
   ```


