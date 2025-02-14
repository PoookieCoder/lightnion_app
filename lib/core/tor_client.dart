import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../components/network/proxy_interface.dart';
import '../components/crypto/ntor_handshake.dart';
import '../components/crypto/aes_handler.dart';
import 'tor_consensus.dart';
import 'tor_node.dart';
import 'tor_exceptions.dart';
import 'serialization.dart';
import 'node_selector.dart';

class TorClient {
  final TorProxyInterface _proxyInterface;
  final NtorHandshake _handshake;
  final AesHandler _aes;
  final FlutterSecureStorage _storage;
  
  List<Circuit> _activeCircuits = [];
  TorConsensus? _currentConsensus;
  bool _isInitialized = false;
  final _nodeSelector = NodeSelector();

  // Tor configuration parameters from search results
  static const _torSocksPort = 9050;
  static const _torControlPort = 9051;
  bool _useV3OnionServices = true;
  bool _streamIsolation = true;

  TorClient({
    required TorProxyInterface proxyInterface,
    required FlutterSecureStorage storage,
  })  : _proxyInterface = proxyInterface,
        _storage = storage,
        _handshake = NtorHandshake(),
        _aes = AesHandler();

  Future<void> initialize() async {
    if (_isInitialized) return;
    
    // Initialize proxy interface first
    await _proxyInterface.initialize();
    _currentConsensus = await _loadCachedConsensus() ?? await _fetchNewConsensus(); // Load or fetch consensus
    if (_currentConsensus!.validUntil.isBefore(DateTime.now())) { // Validate consensus
      throw TorClientException('Consensus expired');
    }
    // Create initial circuits
    _activeCircuits.add(await _createCircuit());
    _isInitialized = true;
  }

  Future<TorConsensus?> _loadCachedConsensus() async {
    final stored = await _storage.read(key: 'tor_consensus');
    if (stored == null) return null;
    try {
      final data = Uint8List.fromList(stored.codeUnits);
      return TorConsensusSerializer().deserialize(data);
    } catch (e) {
      await _storage.delete(key: 'tor_consensus');
      return null;
    }
  
  }

  Future<TorConsensus> _fetchNewConsensus() async {
    // Download from directory authorities
    final response = await HttpClient()
      .getUrl(Uri.parse('https://consensus.torproject.org/tor/status-vote/current/consensus'));
    
    final consensus = ConsensusParser().parse(await response.close());
    await _storage.write(
      key: 'tor_consensus',
      value: String.fromCharCodes(consensus.serialize())
    );
    
    return consensus;
  }
  Uint8List _buildRequest(Uri target) {
    final request = StringBuffer()
      ..write('GET ${target.path} HTTP/1.1\r\n')
      ..write('Host: ${target.host}\r\n')
      ..write('Accept: */*\r\n')
      ..write('Connection: close\r\n')
      ..write('User-Agent: TorClient/${DateTime.now().millisecondsSinceEpoch}\r\n')
      ..write('\r\n');

    return Uint8List.fromList(utf8.encode(request.toString()));
  }

  Future<Uint8List> anonymousRequest(Uri target) async {
    if (!_isInitialized) throw TorClientException('Client not initialized');
    
    final circuit = await _getAvailableCircuit();
    final encryptedRequest = await AesHandler.encrypt(
      data: _buildRequest(target),
      key: circuit.forwardKey,
      nonce: circuit.forwardNonce,
    );

    try {
      await circuit.connection.sendTorCell(encryptedRequest);
      final response = await circuit.connection.stream.first;
      return await AesHandler.decrypt(
        encryptedData: response,
        key: circuit.backwardKey,
        nonceLength: circuit.backwardNonce.length,
      );
    } catch (e) {
      _closeCircuit(circuit);
      rethrow;
    }
  }

  Future<Circuit> _createCircuit() async {
    final path = NodeSelector.selectPath(_currentConsensus!.nodes);
    final proxyConn = await _proxyInterface.connectToGuard(path.guard.fingerprint);
    
    final circuit = Circuit(
      guard: path.guard,
      middle: path.middle,
      exit: path.exit,
      connection: proxyConn,
    );

    try {
      await _performHandshake(circuit, path.guard);
      await _extendCircuit(circuit, path.middle);
      await _extendCircuit(circuit, path.exit);
      
      circuit.status = CircuitStatus.ready;
      return circuit;
    } catch (e) {
      await _retryCircuit(circuit);
      rethrow;
    }
  }

  Future<void> _performHandshake(Circuit circuit, TorNode node) async {
    final keyMaterial = await _handshake.performHandshake(
      ourKeyPair: await X25519().newKeyPair(),
      theirPublicKey: node.onionKey,
      nodeId: node.identityKey,
    );

    circuit.updateKeys(
      forwardKey: keyMaterial.forwardKey,
      backwardKey: keyMaterial.backwardKey,
      forwardNonce: keyMaterial.forwardNonce,
      backwardNonce: keyMaterial.backwardNonce,
    );
  }

  Future<void> _extendCircuit(Circuit circuit, TorNode nextNode) async {
    final keyMaterial = await _handshake.performHandshake(
      ourKeyPair: await X25519().newKeyPair(),
      theirPublicKey: nextNode.onionKey,
      nodeId: nextNode.identityKey,
    );

    circuit.updateKeys(
      forwardKey: keyMaterial.forwardKey,
      backwardKey: keyMaterial.backwardKey,
      forwardNonce: keyMaterial.forwardNonce,
      backwardNonce: keyMaterial.backwardNonce,
    );
  }

  Future<Circuit> _getAvailableCircuit() async {
    try {
      return _activeCircuits.firstWhere(
        (c) => c.status == CircuitStatus.ready,
      );
    } catch (_) {
      return _createCircuit();
    }
  }

  Future<void> _retryCircuit(Circuit failedCircuit) async {
    _closeCircuit(failedCircuit);
    _activeCircuits.add(await _createCircuit());
  }

  Future<void> _closeCircuit(Circuit circuit) async {
    await circuit.connection.close();
    _activeCircuits.remove(circuit);
  }

  // Mobile-specific optimizations from search results
  void _enableStreamIsolation() {
    _streamIsolation = true;
  }

  void _useV3OnionServicesOnly() {
    _useV3OnionServices = true;
  }
}

// Supporting classes
class Circuit {
  final TorNode guard;
  final TorNode middle;
  final TorNode exit;
  final ProxyConnection connection;
  CircuitStatus status;
  
  SecretKey forwardKey;
  SecretKey backwardKey;
  Uint8List forwardNonce;
  Uint8List backwardNonce;

  Circuit({
    required this.guard,
    required this.middle,
    required this.exit,
    required this.connection,
    this.status = CircuitStatus.creating,
  }) : forwardKey = SecretKey(Uint8List(16)), // 128-bit key
         backwardKey = SecretKey(Uint8List(16)),
         forwardNonce = Uint8List(16),
         backwardNonce = Uint8List(16);

  void updateKeys({
    required SecretKey forwardKey,
    required SecretKey backwardKey,
    required Uint8List forwardNonce,
    required Uint8List backwardNonce,
  }) {
    this.forwardKey = forwardKey;
    this.backwardKey = backwardKey;
    this.forwardNonce = forwardNonce;
    this.backwardNonce = backwardNonce;
  }
}

enum CircuitStatus { creating, ready, closed, failed }
