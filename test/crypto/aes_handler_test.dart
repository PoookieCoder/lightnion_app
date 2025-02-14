import 'dart:convert';
import 'dart:typed_data';
import 'package:test/test.dart';
import 'package:cryptography/cryptography.dart';
import 'package:my_flutter_app/components/crypto/aes_handler.dart';

void main() {
  test('AES-128-CTR Round Trip', () async {
    final data = Uint8List.fromList(utf8.encode('CISPA Lightnion'));
    final keyBytes =
        List<int>.generate(16, (i) => i); // Sample deterministic key
    final key = SecretKey(keyBytes);
    final nonce = Uint8List(16); // All zeros nonce

    final encrypted = await AesHandler.encrypt(
      data: data,
      key: key,
      nonce: nonce,
    );

    expect(encrypted, isNotEmpty);

    final decrypted = await AesHandler.decrypt(
      encryptedData: encrypted,
      key: key,
      nonceLength: 16,
    );

    expect(decrypted, equals(data));
  });
}
