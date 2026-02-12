enum NodeType { collection, document }

class FirestoreNode {
  final String id;
  final String name;
  final String path;
  final NodeType type;
  final List<FirestoreNode> children;
  bool isExpanded;
  bool isLoading;

  FirestoreNode({
    required this.id,
    required this.name,
    required this.path,
    required this.type,
    List<FirestoreNode>? children,
    this.isExpanded = false,
    this.isLoading = false,
  }) : children = children ?? [];

  FirestoreNode copyWith({
    String? id,
    String? name,
    String? path,
    NodeType? type,
    List<FirestoreNode>? children,
    bool? isExpanded,
    bool? isLoading,
  }) {
    return FirestoreNode(
      id: id ?? this.id,
      name: name ?? this.name,
      path: path ?? this.path,
      type: type ?? this.type,
      children: children ?? this.children,
      isExpanded: isExpanded ?? this.isExpanded,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}
