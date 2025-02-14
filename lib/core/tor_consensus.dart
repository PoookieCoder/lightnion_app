import 'dart:convert';
import 'dart:typed_data';

import 'package:my_flutter_app/core/tor_node.dart';
class TorConsensus {
  final List<TorNode> nodes;
  final Uint8List authorityDigest;
  final DateTime validAfter;
  final DateTime validUntil;
  final String version;
  final Uint8List signature;

  TorConsensus({
    required this.nodes,
    required this.authorityDigest,
    required this.validAfter,
    required this.validUntil,
    required this.version,
    required this.signature,
  });

  List<TorNode> get guards => nodes.where((n) => n.isGuard).toList();
  List<TorNode> get exits => nodes.where((n) => n.isExit).toList();
  Uint8List serialize() {
    Uint8List _intToBytes(int value) {
      final byteData = ByteData(8);
      byteData.setInt64(0, value, Endian.big);
      return byteData.buffer.asUint8List();
    }

    final buffer = BytesBuilder()
      ..add(utf8.encode(version))
      ..add(_intToBytes(validAfter.millisecondsSinceEpoch))
      ..add(_intToBytes(validUntil.millisecondsSinceEpoch))
      ..add(authorityDigest)
      ..add(signature);
    

    for (final node in nodes) {
      buffer.add(node.serialize());
    }
    
    return buffer.toBytes();
  }
}