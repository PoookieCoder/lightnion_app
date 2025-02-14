
import 'dart:convert';
import 'dart:typed_data';

class TorNode {
  final Uint8List identityKey; // RSA1024 identity key
  final Uint8List onionKey;    // Ed25519 onion key
  final List<String> flags;
  final int bandwidth;
  final String fingerprint;
  final DateTime published;
  final String ip;
  final int port;

  TorNode({
    required this.identityKey,
    required this.onionKey,
    required this.flags,
    required this.bandwidth,
    required this.fingerprint,
    required this.published,
    required this.ip,
    required this.port,
  });

  bool get isGuard => flags.contains('Guard');
  bool get isExit => flags.contains('Exit');
  bool get isStable => flags.contains('Stable');

  Uint8List serialize() {
    // Node serialization logic
    final builder = BytesBuilder();
  
    // Serialize identityKey (RSA1024 public key)
    builder.addByte(identityKey.length);
    builder.add(identityKey);

    // Serialize onionKey (Ed25519 public key)
    builder.addByte(onionKey.length);
    builder.add(onionKey);

    // Serialize flags list
    builder.addByte(flags.length);
    for (final flag in flags) {
      final flagBytes = utf8.encode(flag);
      builder.addByte(flagBytes.length);
      builder.add(flagBytes);
    }

    // Serialize bandwidth (4-byte integer)
    builder.addByte(4);
    builder.add(Uint8List(4)..buffer.asByteData().setUint32(0, bandwidth, Endian.big));

    // Serialize fingerprint (ASCII string)
    final fingerprintBytes = utf8.encode(fingerprint);
    builder.addByte(fingerprintBytes.length);
    builder.add(fingerprintBytes);

    // Serialize published timestamp (8-byte milliseconds since epoch)
    builder.add(Uint8List(8)..buffer.asByteData().setInt64(0, published.millisecondsSinceEpoch, Endian.big));

    // Serialize IP address (UTF-8)
    final ipBytes = utf8.encode(ip);
    builder.addByte(ipBytes.length);
    builder.add(ipBytes);

    // Serialize port (2-byte integer)
    builder.add(Uint8List(2)..buffer.asByteData().setUint16(0, port, Endian.big));

    return builder.toBytes();
  }
}
