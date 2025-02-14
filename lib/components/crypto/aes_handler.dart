import 'dart:typed_data';
import 'package:cryptography/cryptography.dart';

class AesHandler {
  static final algorithm = AesCtr.with128bits(macAlgorithm: Hmac.sha256());

  static Future<Uint8List> encrypt({
    required Uint8List data,
    required SecretKey key,
    required Uint8List nonce,
  }) async {
    final secretBox = await algorithm.encrypt(
      data,
      secretKey: key,
      nonce: nonce,
    );

    return Uint8List.fromList([
      ...secretBox.nonce,
      ...secretBox.cipherText,
      ...secretBox.mac.bytes
    ]);
  }

  static Future<Uint8List> decrypt({
    required Uint8List encryptedData,
    required SecretKey key,
    required int nonceLength,
  }) async {
    final nonce = encryptedData.sublist(0, nonceLength);
    final cipherText = encryptedData.sublist(
      nonceLength,
      encryptedData.length - 32,
    );
    final macBytes = encryptedData.sublist(encryptedData.length - 32);

    final secretBox = SecretBox(
      cipherText,
      nonce: nonce,
      mac: Mac(macBytes),
    );

    final decryptedData = await algorithm.decrypt(
      secretBox,
      secretKey: key,
    );

    return Uint8List.fromList(decryptedData); // Ensure Uint8List return type
  }
}
