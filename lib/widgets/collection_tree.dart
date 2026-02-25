import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/firestore_admin_service.dart';

class CollectionTree extends StatefulWidget {
  final FirestoreAdminService service;
  final Function(String) onDocumentSelected;
  final Function(String) onCollectionSelected;
  final String? selectedPath;

  const CollectionTree({
    super.key,
    required this.service,
    required this.onDocumentSelected,
    required this.onCollectionSelected,
    this.selectedPath,
  });

  @override
  State<CollectionTree> createState() => _CollectionTreeState();
}

class _CollectionTreeState extends State<CollectionTree> {
  final Set<String> _expandedCollections = {};
  final Set<String> _expandedDocuments = {};

  @override
  Widget build(BuildContext context) {
    final collections = widget.service.getRootCollections();

    return ListView.builder(
      itemCount: collections.length,
      itemBuilder: (context, index) {
        final collection = collections[index];
        return _buildCollectionNode(collection, collection, indent: 0);
      },
    );
  }

  Widget _buildCollectionNode(
    String name,
    String path, {
    required double indent,
  }) {
    final isExpanded = _expandedCollections.contains(path);
    final isSelected = widget.selectedPath == path;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.only(left: indent),
          child: InkWell(
            onTap: () {
              widget.onCollectionSelected(path);
            },
            child: Container(
              color: isSelected
                  ? Theme.of(context).colorScheme.primaryContainer
                  : null,
              child: Row(
                children: [
                  IconButton(
                    icon: Icon(
                      isExpanded ? Icons.expand_more : Icons.chevron_right,
                      size: 20,
                    ),
                    onPressed: () {
                      setState(() {
                        if (isExpanded) {
                          _expandedCollections.remove(path);
                        } else {
                          _expandedCollections.add(path);
                        }
                      });
                    },
                  ),
                  Icon(
                    isExpanded ? Icons.folder_open : Icons.folder,
                    size: 18,
                    color: Colors.amber[700],
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      name,
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (isExpanded) _buildDocumentsList(path),
      ],
    );
  }

  Widget _buildDocumentsList(String collectionPath) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: widget.service.streamCollection(collectionPath),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Padding(
            padding: const EdgeInsets.only(left: 40),
            child: Text(
              'Error loading documents',
              style: TextStyle(
                color: Theme.of(context).colorScheme.error,
                fontSize: 12,
              ),
            ),
          );
        }

        if (!snapshot.hasData) {
          return const Padding(
            padding: EdgeInsets.only(left: 40),
            child: SizedBox(
              height: 20,
              width: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          );
        }

        final docs = snapshot.data!.docs;
        if (docs.isEmpty) {
          return Padding(
            padding: const EdgeInsets.only(left: 40),
            child: Text(
              'No documents',
              style: TextStyle(
                color: Theme.of(context).colorScheme.outline,
                fontSize: 12,
                fontStyle: FontStyle.italic,
              ),
            ),
          );
        }

        return Column(
          children: docs.map((doc) {
            final docPath = doc.reference.path;
            final isSelected = widget.selectedPath == docPath;

            final subcollections = widget.service
                .getKnownSubcollectionsForDocument(docPath);
            final hasSubcollections = subcollections.isNotEmpty;
            final isDocExpanded = _expandedDocuments.contains(docPath);

            return Column(
              children: [
                InkWell(
                  onTap: () => widget.onDocumentSelected(docPath),
                  child: Container(
                    color: isSelected
                        ? Theme.of(context).colorScheme.primaryContainer
                        : null,
                    padding: const EdgeInsets.only(left: 40, top: 4, bottom: 4),
                    child: Row(
                      children: [
                        if (hasSubcollections)
                          IconButton(
                            icon: Icon(
                              isDocExpanded
                                  ? Icons.expand_more
                                  : Icons.chevron_right,
                              size: 18,
                            ),
                            onPressed: () {
                              setState(() {
                                if (isDocExpanded) {
                                  _expandedDocuments.remove(docPath);
                                } else {
                                  _expandedDocuments.add(docPath);
                                }
                              });
                            },
                          )
                        else
                          const SizedBox(width: 40),
                        Icon(
                          Icons.description,
                          size: 16,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            doc.id,
                            style: const TextStyle(fontSize: 13),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (hasSubcollections && isDocExpanded)
                  ...subcollections.map(
                    (subcollection) => _buildCollectionNode(
                      subcollection,
                      '$docPath/$subcollection',
                      indent: 72,
                    ),
                  ),
              ],
            );
          }).toList(),
        );
      },
    );
  }
}
