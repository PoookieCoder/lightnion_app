import './tor_node.dart';

class CircuitPath {
  final TorNode guard;
  final TorNode middle;
  final TorNode exit;

  CircuitPath({
    required this.guard,
    required this.middle,
    required this.exit,
  });
}

class NodeSelector {
  static CircuitPath selectPath(List<TorNode> nodes) {
    return CircuitPath(
      guard: selectGuard(nodes),
      middle: selectMiddle(nodes),
      exit: selectExit(nodes),
    );
  }
  static TorNode selectGuard(List<TorNode> nodes) {
    return nodes
        .where((n) => n.isStable && n.bandwidth > 102400) // 100KB/s threshold
        .toList()
        .first;
  }

  static TorNode selectMiddle(List<TorNode> nodes) {
    return nodes
        .where((n) => !n.isGuard && !n.isExit)
        .toList()
        .first;
  }

  static TorNode selectExit(List<TorNode> nodes, {List<String>? allowedPorts}) {
    return nodes
        .where((n) => n.isExit && _supportsRequiredPorts(n, allowedPorts))
        .toList()
        .first;
  }

  static bool _supportsRequiredPorts(TorNode node, List<String>? ports) {
    if (ports == null) return true;
    // Implementation for port checking
    return true;
  }
}
