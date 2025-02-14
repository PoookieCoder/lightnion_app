import 'dart:convert';
import 'dart:typed_data';
import 'package:cryptography/cryptography.dart';

class NtorHandshake {
  static const _PROTOCOL_NAME = 'ntor-curve25519-sha256-1';
  final X25519 _x25519 = X25519();
  final Hkdf _hkdf = Hkdf(hmac: Hmac.sha256(), outputLength: 64);

  Future<KeyMaterial> performHandshake({
    required KeyPair ourKeyPair,
    required Uint8List theirPublicKey,
    required Uint8List nodeId,
  }) async {
    // Extract our public key
    final PublicKey ourPublicKey = await ourKeyPair.extractPublicKey();
    final Uint8List ourPublicKeyBytes =
        Uint8List.fromList((ourPublicKey as SimplePublicKey).bytes);

    // Convert their public key into a SimplePublicKey
    final SimplePublicKey theirKey = SimplePublicKey(
      Uint8List.fromList(theirPublicKey),
      type: KeyPairType.x25519,
    );

    // ✅ 1. Compute shared secret
    final SecretKey sharedSecret = await _x25519.sharedSecretKey(
      keyPair: ourKeyPair,
      remotePublicKey: theirKey,
    );

    final List<int> sharedSecretBytes = await sharedSecret.extractBytes();

    // Debugging: Print shared secret
    print('Shared Secret: ${sharedSecretBytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join()}');

    if (sharedSecretBytes.isEmpty) {
      throw ArgumentError("Derived shared secret is empty. Key exchange failed.");
    }

    // ✅ 2. Key expansion using HKDF
    final SecretKey derivedKey = await _hkdf.deriveKey(
      secretKey: sharedSecret,
      nonce: Uint8List(0),
      info: Uint8List.fromList([
        ...utf8.encode(_PROTOCOL_NAME),
        ...nodeId,
        ...ourPublicKeyBytes,
        ...theirPublicKey,
      ]),
    );

    final List<int> keyMaterial = await derivedKey.extractBytes();
    
    // Debugging: Print derived key material
    print('Derived Key Material: ${keyMaterial.map((b) => b.toRadixString(16).padLeft(2, '0')).join()}');

    if (keyMaterial.length < 64) {
      throw ArgumentError("Derived key material is too short. Expected 64 bytes.");
    }

    // ✅ 3. Key separation
    return KeyMaterial(
      forwardKey: SecretKey(Uint8List.fromList(keyMaterial.sublist(0, 16))),
      backwardKey: SecretKey(Uint8List.fromList(keyMaterial.sublist(16, 32))),
      forwardNonce: Uint8List.fromList(keyMaterial.sublist(32, 48)),
      backwardNonce: Uint8List.fromList(keyMaterial.sublist(48, 64)),
    );
  }
}

class KeyMaterial {
  final SecretKey forwardKey;
  final SecretKey backwardKey;
  final Uint8List forwardNonce;
  final Uint8List backwardNonce;

  KeyMaterial({
    required this.forwardKey,
    required this.backwardKey,
    required this.forwardNonce,
    required this.backwardNonce,
  });
}
