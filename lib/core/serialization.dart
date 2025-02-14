import 'dart:io';
import 'dart:typed_data';
import '../core/tor_consensus.dart';

class TorConsensusSerializer {
  TorConsensus deserialize(Uint8List data) {
    return TorConsensus(
      nodes: [],
      authorityDigest: Uint8List(32),
      validAfter: DateTime.now(),
      validUntil: DateTime.now().add(Duration(days: 7)),
      version: '3',
      signature: Uint8List(128),
    );
  }

  Uint8List serialize(TorConsensus consensus) {
    return Uint8List(0);
  }
}

class ConsensusParser {
  TorConsensus parse(HttpClientResponse response) {
    return TorConsensus(
      nodes: [],
      authorityDigest: Uint8List(32),
      validAfter: DateTime.now(),
      validUntil: DateTime.now().add(Duration(days: 7)),
      version: '3',
      signature: Uint8List(128),
    );
  }
}
