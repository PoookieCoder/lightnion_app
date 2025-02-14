class TorClientException implements Exception {
  final String message;
  TorClientException(this.message);

  @override
  String toString() => 'TorClientException: $message';
}

class TorConsensusException implements Exception {
  final String message;
  TorConsensusException(this.message);

  @override
  String toString() => 'TorConsensusException: $message';
}
