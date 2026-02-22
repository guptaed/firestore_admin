import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/firestore_admin_service.dart';
import '../widgets/collection_tree.dart';
import '../widgets/document_viewer.dart';
import '../widgets/search_results_panel.dart';
import '../widgets/query_builder.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final FirestoreAdminService _service = FirestoreAdminService();
  final TextEditingController _searchController = TextEditingController();

  String? _selectedDocumentPath;
  String? _selectedCollectionPath;

  // Search state
  bool _isSearching = false;
  bool _isSearchLoading = false;
  String _searchTerm = '';
  List<SearchResult> _searchResults = [];

  // Query builder state
  bool _showQueryBuilder = false;
  List<QueryCondition> _queryConditions = [];
  String? _orderByField;
  bool _descending = false;
  int? _queryLimit;

  // Collections loading state
  bool _collectionsLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCollections();
  }

  Future<void> _loadCollections() async {
    setState(() => _collectionsLoading = true);
    try {
      await _service.loadCollections();
    } finally {
      if (mounted) {
        setState(() => _collectionsLoading = false);
      }
    }
  }

  Future<void> _refreshCollections() async {
    setState(() => _collectionsLoading = true);
    try {
      await _service.refreshCollections();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Collections refreshed')));
      }
    } finally {
      if (mounted) {
        setState(() => _collectionsLoading = false);
      }
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // Track if we came from search to enable back navigation
  bool _cameFromSearch = false;

  // Track if we came from query results to enable back navigation
  bool _cameFromQueryResults = false;
  String? _queryResultsCollectionPath;

  void _onDocumentSelected(String documentPath) {
    setState(() {
      // Check if we're coming from query results (collection view with active query)
      if (_selectedCollectionPath != null && _hasActiveQuery) {
        _cameFromQueryResults = true;
        _queryResultsCollectionPath = _selectedCollectionPath;
      }

      _selectedDocumentPath = documentPath;
      _selectedCollectionPath = null;

      // Preserve search state when navigating from search results
      if (_isSearching && _searchResults.isNotEmpty) {
        _cameFromSearch = true;
      }
      _isSearching = false;
    });
  }

  void _backToSearchResults() {
    setState(() {
      _isSearching = true;
      _selectedDocumentPath = null;
      _cameFromSearch = false;
    });
  }

  void _backToQueryResults() {
    setState(() {
      _selectedCollectionPath = _queryResultsCollectionPath;
      _selectedDocumentPath = null;
      _cameFromQueryResults = false;
      _queryResultsCollectionPath = null;
    });
  }

  void _onCollectionSelected(String collectionPath) {
    setState(() {
      _selectedCollectionPath = collectionPath;
      _selectedDocumentPath = null;
      // Reset query when changing collections
      _queryConditions = [];
      _orderByField = null;
      _descending = false;
      _queryLimit = null;
      _showQueryBuilder = false;
    });
  }

  Future<void> _performSearch(String term) async {
    if (term.isEmpty) {
      setState(() {
        _isSearching = false;
        _searchTerm = '';
        _searchResults = [];
      });
      return;
    }

    setState(() {
      _isSearching = true;
      _isSearchLoading = true;
      _searchTerm = term;
    });

    try {
      final results = await _service.searchAllCollections(term);
      setState(() {
        _searchResults = results;
        _isSearchLoading = false;
      });
    } catch (e) {
      setState(() {
        _searchResults = [];
        _isSearchLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Search error: $e')));
      }
    }
  }

  void _closeSearch() {
    setState(() {
      _isSearching = false;
      _searchController.clear();
      _searchTerm = '';
      _searchResults = [];
      _cameFromSearch = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.storage),
            SizedBox(width: 8),
            Text('Firestore Admin'),
            SizedBox(width: 8),
            Text(
              '- vietfuelprocapp',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.normal),
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Center(
              child: Text(
                FirebaseAuth.instance.currentUser?.email ?? '',
                style: const TextStyle(fontSize: 12),
              ),
            ),
          ),
          // Search bar
          SizedBox(
            width: 300,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search (e.g., SUP001)',
                  prefixIcon: const Icon(Icons.search, size: 20),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 18),
                          onPressed: _closeSearch,
                        )
                      : null,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: Theme.of(
                    context,
                  ).colorScheme.surfaceContainerHighest,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                  isDense: true,
                ),
                style: const TextStyle(fontSize: 14),
                onChanged: (value) {
                  setState(() {}); // Update clear button visibility
                },
                onSubmitted: _performSearch,
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.search),
            tooltip: 'Search',
            onPressed: () => _performSearch(_searchController.text),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh Collections',
            onPressed: _refreshCollections,
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Sign out',
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
            },
          ),
        ],
      ),
      body: Row(
        children: [
          // Left panel - Collection Tree
          SizedBox(
            width: 300,
            child: Card(
              margin: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Theme.of(
                        context,
                      ).colorScheme.surfaceContainerHighest,
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(12),
                        topRight: Radius.circular(12),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.folder,
                          size: 20,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            'Collections',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ),
                        if (_collectionsLoading)
                          const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        else
                          PopupMenuButton<String>(
                            icon: const Icon(Icons.more_vert, size: 20),
                            tooltip: 'Manage Collections',
                            onSelected: (value) {
                              if (value == 'add') {
                                _showAddCollectionDialog();
                              } else if (value == 'manage') {
                                _showManageCollectionsDialog();
                              }
                            },
                            itemBuilder: (context) => [
                              const PopupMenuItem(
                                value: 'add',
                                child: Row(
                                  children: [
                                    Icon(Icons.add, size: 20),
                                    SizedBox(width: 8),
                                    Text('Add Collection'),
                                  ],
                                ),
                              ),
                              const PopupMenuItem(
                                value: 'manage',
                                child: Row(
                                  children: [
                                    Icon(Icons.settings, size: 20),
                                    SizedBox(width: 8),
                                    Text('Manage Collections'),
                                  ],
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child: CollectionTree(
                      service: _service,
                      onDocumentSelected: _onDocumentSelected,
                      onCollectionSelected: _onCollectionSelected,
                      selectedPath:
                          _selectedDocumentPath ?? _selectedCollectionPath,
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Divider
          const VerticalDivider(width: 1),
          // Right panel - Document Viewer or Search Results
          Expanded(
            child: Card(
              margin: const EdgeInsets.all(8),
              child: _buildRightPanel(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRightPanel() {
    // Show search results if searching
    if (_isSearching) {
      return SearchResultsPanel(
        searchTerm: _searchTerm,
        results: _searchResults,
        isLoading: _isSearchLoading,
        onResultTap: _onDocumentSelected,
        onClose: _closeSearch,
      );
    }

    if (_selectedDocumentPath != null) {
      // Determine which back action to show
      VoidCallback? backAction;
      String? backLabel;

      if (_cameFromSearch) {
        backAction = _backToSearchResults;
        backLabel = _searchTerm;
      } else if (_cameFromQueryResults) {
        backAction = _backToQueryResults;
        backLabel = _queryConditions.isNotEmpty
            ? _queryConditions.map((c) => c.toString()).join(' AND ')
            : 'Query Results';
      }

      return DocumentViewer(
        documentPath: _selectedDocumentPath!,
        service: _service,
        onDocumentDeleted: () {
          setState(() {
            _selectedDocumentPath = null;
            _cameFromSearch = false;
            _cameFromQueryResults = false;
          });
        },
        // Show back button if we came from search or query results
        onBackToSearch: backAction,
        searchTerm: backLabel,
      );
    }

    if (_selectedCollectionPath != null) {
      return _buildCollectionView();
    }

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.touch_app,
            size: 64,
            color: Theme.of(context).colorScheme.outline,
          ),
          const SizedBox(height: 16),
          Text(
            'Select a document to view',
            style: TextStyle(
              fontSize: 18,
              color: Theme.of(context).colorScheme.outline,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Click on a document in the tree to view its contents',
            style: TextStyle(color: Theme.of(context).colorScheme.outline),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.lightbulb_outline,
                size: 16,
                color: Theme.of(context).colorScheme.outline,
              ),
              const SizedBox(width: 8),
              Text(
                'Tip: Use the search bar to find documents across all collections',
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.outline,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _onQueryChanged(
    List<QueryCondition> conditions,
    String? orderBy,
    bool descending,
    int? limit,
  ) {
    setState(() {
      _queryConditions = conditions;
      _orderByField = orderBy;
      _descending = descending;
      _queryLimit = limit;
    });
  }

  void _clearQuery() {
    setState(() {
      _queryConditions = [];
      _orderByField = null;
      _descending = false;
      _queryLimit = null;
      _showQueryBuilder = false;
    });
  }

  bool get _hasActiveQuery =>
      _queryConditions.isNotEmpty ||
      (_orderByField != null && _orderByField!.isNotEmpty) ||
      _queryLimit != null;

  Widget _buildCollectionView() {
    // Determine which stream to use
    final Stream<QuerySnapshot<Map<String, dynamic>>> stream;
    if (_hasActiveQuery) {
      stream = _service.streamQueryCollection(
        collectionPath: _selectedCollectionPath!,
        conditions: _queryConditions,
        orderByField: _orderByField,
        descending: _descending,
        limit: _queryLimit,
      );
    } else {
      stream = _service.streamCollection(_selectedCollectionPath!);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(12),
              topRight: Radius.circular(12),
            ),
          ),
          child: Row(
            children: [
              Icon(
                Icons.folder_open,
                size: 20,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Collection: $_selectedCollectionPath',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
              // Query button
              IconButton(
                icon: Icon(
                  Icons.filter_list,
                  color: _hasActiveQuery
                      ? Theme.of(context).colorScheme.primary
                      : null,
                ),
                tooltip: _showQueryBuilder
                    ? 'Hide Query Builder'
                    : 'Show Query Builder',
                onPressed: () {
                  setState(() => _showQueryBuilder = !_showQueryBuilder);
                },
              ),
              // Active query indicator
              if (_hasActiveQuery && !_showQueryBuilder)
                Container(
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Query Active',
                        style: TextStyle(
                          fontSize: 11,
                          color: Theme.of(
                            context,
                          ).colorScheme.onPrimaryContainer,
                        ),
                      ),
                      const SizedBox(width: 4),
                      InkWell(
                        onTap: _clearQuery,
                        child: Icon(
                          Icons.close,
                          size: 14,
                          color: Theme.of(
                            context,
                          ).colorScheme.onPrimaryContainer,
                        ),
                      ),
                    ],
                  ),
                ),
              IconButton(
                icon: const Icon(Icons.add),
                tooltip: 'Add Document',
                onPressed: () => _showAddDocumentDialog(),
              ),
            ],
          ),
        ),
        // Query Builder
        if (_showQueryBuilder)
          QueryBuilder(
            conditions: _queryConditions,
            orderByField: _orderByField,
            descending: _descending,
            limit: _queryLimit,
            onQueryChanged: _onQueryChanged,
            onClear: _clearQuery,
            collectionPath: _selectedCollectionPath!,
            service: _service,
          ),
        const Divider(height: 1),
        // Results
        Expanded(
          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: stream,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.error_outline,
                          size: 48,
                          color: Theme.of(context).colorScheme.error,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Query Error',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${snapshot.error}',
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 12),
                        ),
                        const SizedBox(height: 16),
                        FilledButton.icon(
                          onPressed: _clearQuery,
                          icon: const Icon(Icons.clear),
                          label: const Text('Clear Query'),
                        ),
                      ],
                    ),
                  ),
                );
              }

              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final docs = snapshot.data!.docs;

              return Column(
                children: [
                  // Results count
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    color: Theme.of(context).colorScheme.surfaceContainerLow,
                    child: Row(
                      children: [
                        Icon(
                          Icons.list,
                          size: 16,
                          color: Theme.of(context).colorScheme.outline,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${docs.length} document${docs.length == 1 ? '' : 's'}${_hasActiveQuery ? ' (filtered)' : ''}',
                          style: TextStyle(
                            fontSize: 13,
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: docs.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  _hasActiveQuery
                                      ? Icons.filter_list_off
                                      : Icons.folder_off,
                                  size: 48,
                                  color: Theme.of(context).colorScheme.outline,
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  _hasActiveQuery
                                      ? 'No documents match your query'
                                      : 'No documents in this collection',
                                  style: TextStyle(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.outline,
                                  ),
                                ),
                                if (_hasActiveQuery) ...[
                                  const SizedBox(height: 16),
                                  TextButton.icon(
                                    onPressed: _clearQuery,
                                    icon: const Icon(Icons.clear),
                                    label: const Text('Clear Query'),
                                  ),
                                ],
                              ],
                            ),
                          )
                        : ListView.builder(
                            itemCount: docs.length,
                            itemBuilder: (context, index) {
                              final doc = docs[index];
                              return ListTile(
                                leading: const Icon(Icons.description),
                                title: Text(doc.id),
                                subtitle: Text('${doc.data().length} fields'),
                                onTap: () =>
                                    _onDocumentSelected(doc.reference.path),
                              );
                            },
                          ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  void _showAddCollectionDialog() {
    final controller = TextEditingController();
    final rootContext = context;

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Add Collection'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Collection Name',
            hintText: 'e.g., Orders, Products',
            border: OutlineInputBorder(),
          ),
          autofocus: true,
          onSubmitted: (value) async {
            if (value.trim().isNotEmpty) {
              Navigator.pop(dialogContext);
              await _service.addCollection(value.trim());
              setState(() {});
              if (!rootContext.mounted) return;
              ScaffoldMessenger.of(rootContext).showSnackBar(
                SnackBar(content: Text('Collection "${value.trim()}" added')),
              );
            }
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              final name = controller.text.trim();
              if (name.isNotEmpty) {
                Navigator.pop(dialogContext);
                await _service.addCollection(name);
                setState(() {});
                if (!rootContext.mounted) return;
                ScaffoldMessenger.of(rootContext).showSnackBar(
                  SnackBar(content: Text('Collection "$name" added')),
                );
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  void _showManageCollectionsDialog() {
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          final collections = _service.getRootCollections();
          return AlertDialog(
            title: const Text('Manage Collections'),
            content: SizedBox(
              width: 400,
              height: 400,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Collections are stored in Firestore at _config/collections',
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.outline,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: ListView.builder(
                      itemCount: collections.length,
                      itemBuilder: (context, index) {
                        final collection = collections[index];
                        return ListTile(
                          leading: const Icon(Icons.folder),
                          title: Text(collection),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete_outline),
                            tooltip: 'Remove from list',
                            onPressed: () async {
                              final confirm = await showDialog<bool>(
                                context: context,
                                builder: (context) => AlertDialog(
                                  title: const Text('Remove Collection?'),
                                  content: Text(
                                    'Remove "$collection" from the list?\n\n'
                                    'This only removes it from the app\'s collection list. '
                                    'The actual Firestore collection and its data will NOT be deleted.',
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.pop(context, false),
                                      child: const Text('Cancel'),
                                    ),
                                    FilledButton(
                                      onPressed: () =>
                                          Navigator.pop(context, true),
                                      child: const Text('Remove'),
                                    ),
                                  ],
                                ),
                              );
                              if (confirm == true) {
                                await _service.removeCollection(collection);
                                setDialogState(() {});
                                setState(() {});
                              }
                            },
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showAddDocumentDialog() {
    final idController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Document'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: idController,
              decoration: const InputDecoration(
                labelText: 'Document ID (leave empty for auto-generated)',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(context);
              final id = idController.text.trim();
              if (id.isEmpty) {
                await _service.addDocument(_selectedCollectionPath!, {
                  'created': FieldValue.serverTimestamp(),
                });
              } else {
                await _service.setDocument('$_selectedCollectionPath/$id', {
                  'created': FieldValue.serverTimestamp(),
                });
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }
}
