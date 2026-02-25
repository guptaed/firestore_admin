import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';

/// A wrapper to return filtered query results with the same interface
class _FilteredQuerySnapshot implements QuerySnapshot<Map<String, dynamic>> {
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> _docs;
  final QuerySnapshot<Map<String, dynamic>> _original;

  _FilteredQuerySnapshot(this._docs, this._original);

  @override
  List<QueryDocumentSnapshot<Map<String, dynamic>>> get docs => _docs;

  @override
  List<DocumentChange<Map<String, dynamic>>> get docChanges =>
      _original.docChanges;

  @override
  SnapshotMetadata get metadata => _original.metadata;

  @override
  int get size => _docs.length;
}

class FirestoreAdminService {
  static final FirestoreAdminService _instance =
      FirestoreAdminService._internal();
  factory FirestoreAdminService() => _instance;
  FirestoreAdminService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Config document path for storing collection names
  static const String _configDocPath = '_config/collections';

  // Default collections (fallback if Firestore config doesn't exist)
  static const List<String> _defaultCollections = [
    'Suppliers',
    'SupplierHistory',
    'Announcements',
    'Bids',
    'Shipments',
    'Contracts',
    'Banks',
    'CreditChecks',
    'CreditCheckHistory',
    'Smartphoneaccess',
    'BidFlows',
    'audit_trails',
  ];

  // Dynamic list of collections (loaded from Firestore)
  List<String> _collections = [];
  bool _collectionsLoaded = false;

  /// Get all known root collections
  List<String> getRootCollections() {
    if (!_collectionsLoaded) {
      return List.from(_defaultCollections);
    }
    return List.from(_collections);
  }

  /// Load collections from Firestore config document
  /// Falls back to default list if document doesn't exist
  Future<List<String>> loadCollections() async {
    try {
      final doc = await _firestore.doc(_configDocPath).get();
      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        if (data['names'] is List) {
          _collections = List<String>.from(data['names']);
          _collectionsLoaded = true;
          return _collections;
        }
      }
    } catch (e) {
      // Fall back to defaults on error
    }

    // If no config exists, create it with defaults
    _collections = List.from(_defaultCollections);
    _collectionsLoaded = true;
    await _saveCollectionsToFirestore();
    return _collections;
  }

  /// Save collections list to Firestore
  Future<void> _saveCollectionsToFirestore() async {
    await _firestore.doc(_configDocPath).set({
      'names': _collections,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Add a new collection to the list
  Future<void> addCollection(String name) async {
    if (!_collections.contains(name)) {
      _collections.add(name);
      _collections.sort();
      await _saveCollectionsToFirestore();
    }
  }

  /// Remove a collection from the list
  Future<void> removeCollection(String name) async {
    _collections.remove(name);
    await _saveCollectionsToFirestore();
  }

  /// Refresh collections from Firestore
  Future<List<String>> refreshCollections() async {
    _collectionsLoaded = false;
    return loadCollections();
  }

  /// Stream documents in a collection
  Stream<QuerySnapshot<Map<String, dynamic>>> streamCollection(
    String collectionPath,
  ) {
    return _firestore.collection(collectionPath).snapshots();
  }

  /// Get all documents in a collection
  Future<QuerySnapshot<Map<String, dynamic>>> getDocuments(
    String collectionPath,
  ) {
    return _firestore.collection(collectionPath).get();
  }

  /// Build and execute a query with conditions
  Stream<QuerySnapshot<Map<String, dynamic>>> streamQueryCollection({
    required String collectionPath,
    List<QueryCondition> conditions = const [],
    String? orderByField,
    bool descending = false,
    int? limit,
  }) {
    Query<Map<String, dynamic>> query = _firestore.collection(collectionPath);

    // Separate server-side and client-side conditions
    final serverConditions = conditions
        .where((c) => !c.operator.isClientSide)
        .toList();
    final clientConditions = conditions
        .where((c) => c.operator.isClientSide)
        .toList();

    // Apply server-side where conditions
    for (final condition in serverConditions) {
      query = _applyCondition(query, condition);
    }

    // Apply ordering
    if (orderByField != null && orderByField.isNotEmpty) {
      query = query.orderBy(orderByField, descending: descending);
    }

    // Apply limit only if no client-side filtering (we'll limit after filtering)
    if (limit != null && limit > 0 && clientConditions.isEmpty) {
      query = query.limit(limit);
    }

    // If we have client-side conditions, filter the stream
    if (clientConditions.isNotEmpty) {
      return query.snapshots().map((snapshot) {
        var docs = snapshot.docs.where((doc) {
          return clientConditions.every((condition) {
            return _matchesClientCondition(doc.data(), condition);
          });
        }).toList();

        // Apply limit after client-side filtering
        if (limit != null && limit > 0 && docs.length > limit) {
          docs = docs.take(limit).toList();
        }

        return _FilteredQuerySnapshot(docs, snapshot);
      });
    }

    return query.snapshots();
  }

  /// Check if a document matches a client-side condition
  bool _matchesClientCondition(
    Map<String, dynamic> data,
    QueryCondition condition,
  ) {
    final fieldValue = _getNestedField(data, condition.field);

    if (fieldValue == null) {
      return false;
    }

    switch (condition.operator) {
      case QueryOperator.stringContains:
        if (fieldValue is String) {
          return fieldValue.toLowerCase().contains(
            condition.value.toLowerCase(),
          );
        }
        return fieldValue.toString().toLowerCase().contains(
          condition.value.toLowerCase(),
        );
      default:
        return false;
    }
  }

  /// Get a nested field value using dot notation (e.g., "address.city")
  dynamic _getNestedField(Map<String, dynamic> data, String fieldPath) {
    final parts = fieldPath.split('.');
    dynamic current = data;

    for (final part in parts) {
      if (current is Map<String, dynamic>) {
        current = current[part];
      } else {
        return null;
      }
    }

    return current;
  }

  /// Apply a single condition to a query
  Query<Map<String, dynamic>> _applyCondition(
    Query<Map<String, dynamic>> query,
    QueryCondition condition,
  ) {
    final field = condition.field;
    final value = condition.parsedValue;

    switch (condition.operator) {
      case QueryOperator.equals:
        return query.where(field, isEqualTo: value);
      case QueryOperator.notEquals:
        return query.where(field, isNotEqualTo: value);
      case QueryOperator.lessThan:
        return query.where(field, isLessThan: value);
      case QueryOperator.lessThanOrEqual:
        return query.where(field, isLessThanOrEqualTo: value);
      case QueryOperator.greaterThan:
        return query.where(field, isGreaterThan: value);
      case QueryOperator.greaterThanOrEqual:
        return query.where(field, isGreaterThanOrEqualTo: value);
      case QueryOperator.startsWith:
        // Firestore prefix query using >= and <
        final prefix = value.toString();
        final prefixEnd =
            prefix.substring(0, prefix.length - 1) +
            String.fromCharCode(prefix.codeUnitAt(prefix.length - 1) + 1);
        return query
            .where(field, isGreaterThanOrEqualTo: prefix)
            .where(field, isLessThan: prefixEnd);
      case QueryOperator.arrayContains:
        return query.where(field, arrayContains: value);
      case QueryOperator.isNull:
        return query.where(field, isNull: true);
      case QueryOperator.isNotNull:
        return query.where(field, isNull: false);
      case QueryOperator.stringContains:
        // This is handled client-side, should not reach here
        return query;
    }
  }

  /// Get a single document by path
  Future<DocumentSnapshot<Map<String, dynamic>>> getDocument(
    String documentPath,
  ) {
    return _firestore.doc(documentPath).get();
  }

  /// Stream a single document
  Stream<DocumentSnapshot<Map<String, dynamic>>> streamDocument(
    String documentPath,
  ) {
    return _firestore.doc(documentPath).snapshots();
  }

  /// Update a document field
  Future<void> updateField(
    String documentPath,
    String fieldName,
    dynamic value,
  ) {
    return _firestore.doc(documentPath).update({fieldName: value});
  }

  /// Update entire document
  Future<void> updateDocument(String documentPath, Map<String, dynamic> data) {
    return _firestore.doc(documentPath).update(data);
  }

  /// Delete a document
  Future<void> deleteDocument(String documentPath) {
    return _firestore.doc(documentPath).delete();
  }

  /// Add a new document to a collection
  Future<DocumentReference<Map<String, dynamic>>> addDocument(
    String collectionPath,
    Map<String, dynamic> data,
  ) {
    return _firestore.collection(collectionPath).add(data);
  }

  /// Set a document with a specific ID
  Future<void> setDocument(String documentPath, Map<String, dynamic> data) {
    return _firestore.doc(documentPath).set(data);
  }

  /// Capture a JSON-serializable snapshot for the selected collections.
  Future<SnapshotData> createSnapshot({
    required List<String> collections,
  }) async {
    final selectedCollections = collections.toSet().toList()..sort();
    final counts = <String, int>{};
    final collectionPayload = <String, List<Map<String, dynamic>>>{};

    for (final collection in selectedCollections) {
      final snapshot = await _firestore.collection(collection).get();
      counts[collection] = snapshot.size;

      collectionPayload[collection] = snapshot.docs
          .map(
            (doc) => {
              'id': doc.id,
              'data': _serializeSnapshotValue(doc.data()),
            },
          )
          .toList();
    }

    final payload = <String, dynamic>{
      'snapshotVersion': 1,
      'createdAt': DateTime.now().toUtc().toIso8601String(),
      'collections': collectionPayload,
    };

    return SnapshotData(payload: payload, documentCounts: counts);
  }

  /// Preview restore impact against current Firestore state.
  Future<SnapshotPreview> previewSnapshotRestore(
    Map<String, dynamic> payload,
  ) async {
    final parsedCollections = _parseSnapshotCollections(payload);
    final details = <SnapshotCollectionPreview>[];

    for (final entry in parsedCollections.entries) {
      final collection = entry.key;
      final snapshotDocCount = entry.value.length;
      final existing = await _firestore.collection(collection).get();
      details.add(
        SnapshotCollectionPreview(
          collection: collection,
          snapshotDocumentCount: snapshotDocCount,
          existingDocumentCount: existing.size,
        ),
      );
    }

    return SnapshotPreview(collections: details);
  }

  /// Restore snapshot payload into Firestore.
  /// If [clearCollectionsBeforeRestore] is true, all existing docs in each
  /// target collection are deleted first.
  Future<SnapshotRestoreResult> restoreSnapshot(
    Map<String, dynamic> payload, {
    bool clearCollectionsBeforeRestore = false,
  }) async {
    final parsedCollections = _parseSnapshotCollections(payload);

    var deletedCount = 0;
    var upsertedCount = 0;

    for (final entry in parsedCollections.entries) {
      final collection = entry.key;
      final snapshotDocuments = entry.value;
      final collectionRef = _firestore.collection(collection);

      if (clearCollectionsBeforeRestore) {
        final existingSnapshot = await collectionRef.get();
        deletedCount += existingSnapshot.size;

        var batch = _firestore.batch();
        var batchCount = 0;
        for (final doc in existingSnapshot.docs) {
          batch.delete(doc.reference);
          batchCount++;
          if (batchCount >= 400) {
            await batch.commit();
            batch = _firestore.batch();
            batchCount = 0;
          }
        }
        if (batchCount > 0) {
          await batch.commit();
        }
      }

      var setBatch = _firestore.batch();
      var setBatchCount = 0;
      for (final item in snapshotDocuments) {
        final id = item['id'];
        final data = item['data'];
        if (id is! String || data is! Map<String, dynamic>) {
          continue;
        }

        final decoded = _deserializeSnapshotValue(data);
        if (decoded is! Map<String, dynamic>) {
          continue;
        }

        setBatch.set(collectionRef.doc(id), decoded);
        setBatchCount++;
        upsertedCount++;

        if (setBatchCount >= 400) {
          await setBatch.commit();
          setBatch = _firestore.batch();
          setBatchCount = 0;
        }
      }
      if (setBatchCount > 0) {
        await setBatch.commit();
      }
    }

    return SnapshotRestoreResult(
      collectionsProcessed: parsedCollections.length,
      deletedDocuments: deletedCount,
      upsertedDocuments: upsertedCount,
      clearCollectionsBeforeRestore: clearCollectionsBeforeRestore,
    );
  }

  Map<String, List<Map<String, dynamic>>> _parseSnapshotCollections(
    Map<String, dynamic> payload,
  ) {
    final collectionsNode = payload['collections'];
    if (collectionsNode is! Map) {
      throw const FormatException('Snapshot JSON missing "collections" object');
    }

    final parsed = <String, List<Map<String, dynamic>>>{};
    for (final entry in collectionsNode.entries) {
      final collection = entry.key.toString();
      final rawList = entry.value;
      if (rawList is! List) {
        continue;
      }

      final docs = <Map<String, dynamic>>[];
      for (final item in rawList) {
        if (item is! Map) continue;
        final normalized = <String, dynamic>{};
        item.forEach((k, v) => normalized[k.toString()] = v);
        docs.add(normalized);
      }

      parsed[collection] = docs;
    }

    return parsed;
  }

  dynamic _serializeSnapshotValue(dynamic value) {
    if (value is Timestamp) {
      return {
        '__vf_type': 'timestamp',
        'value': value.toDate().toUtc().toIso8601String(),
      };
    }
    if (value is GeoPoint) {
      return {
        '__vf_type': 'geopoint',
        'latitude': value.latitude,
        'longitude': value.longitude,
      };
    }
    if (value is DocumentReference) {
      return {'__vf_type': 'reference', 'path': value.path};
    }
    if (value is Blob) {
      return {'__vf_type': 'blob', 'bytesBase64': base64Encode(value.bytes)};
    }
    if (value is Map) {
      final result = <String, dynamic>{};
      for (final entry in value.entries) {
        result[entry.key.toString()] = _serializeSnapshotValue(entry.value);
      }
      return result;
    }
    if (value is List) {
      return value.map(_serializeSnapshotValue).toList();
    }
    return value;
  }

  dynamic _deserializeSnapshotValue(dynamic value) {
    if (value is List) {
      return value.map(_deserializeSnapshotValue).toList();
    }
    if (value is! Map) {
      return value;
    }

    final map = <String, dynamic>{};
    value.forEach((k, v) => map[k.toString()] = v);

    final marker = map['__vf_type'];
    if (marker is String) {
      switch (marker) {
        case 'timestamp':
          final iso = map['value'];
          if (iso is String) {
            final parsed = DateTime.tryParse(iso);
            if (parsed != null) {
              return Timestamp.fromDate(parsed.toUtc());
            }
          }
          break;
        case 'geopoint':
          final lat = map['latitude'];
          final lng = map['longitude'];
          if (lat is num && lng is num) {
            return GeoPoint(lat.toDouble(), lng.toDouble());
          }
          break;
        case 'reference':
          final path = map['path'];
          if (path is String && path.isNotEmpty) {
            return _firestore.doc(path);
          }
          break;
        case 'blob':
          final bytesBase64 = map['bytesBase64'];
          if (bytesBase64 is String) {
            try {
              return Blob(base64Decode(bytesBase64));
            } catch (_) {
              return bytesBase64;
            }
          }
          break;
      }
    }

    final decoded = <String, dynamic>{};
    map.forEach((k, v) {
      decoded[k] = _deserializeSnapshotValue(v);
    });
    return decoded;
  }

  /// Get subcollections of a document (returns known subcollection names).
  /// Note: Firestore client SDK doesn't support listing subcollections
  /// dynamically, so this is an explicit data-model map.
  List<String> getKnownSubcollectionsForDocument(String documentPath) {
    final segments = documentPath.split('/');
    if (segments.length < 2) return [];

    final parentCollection = segments[segments.length - 2];
    final documentId = segments.last;

    // Define known subcollections based on your data model.
    if (parentCollection == 'Suppliers') {
      return ['history'];
    }

    if (parentCollection == 'AppConfig' &&
        documentId == 'notification_templates') {
      return ['templates'];
    }

    return [];
  }

  /// Convert Firestore value to display string with type info
  static String getFieldType(dynamic value) {
    if (value == null) return 'null';
    if (value is String) return 'string';
    if (value is int) return 'number';
    if (value is double) return 'number';
    if (value is bool) return 'boolean';
    if (value is Timestamp) return 'timestamp';
    if (value is GeoPoint) return 'geopoint';
    if (value is DocumentReference) return 'reference';
    if (value is List) return 'array';
    if (value is Map) return 'map';
    return value.runtimeType.toString();
  }

  /// Format a value for display
  static String formatValue(dynamic value) {
    if (value == null) return 'null';
    if (value is Timestamp) {
      return value.toDate().toString();
    }
    if (value is GeoPoint) {
      return '(${value.latitude}, ${value.longitude})';
    }
    if (value is DocumentReference) {
      return value.path;
    }
    if (value is List) {
      return '[${value.length} items]';
    }
    if (value is Map) {
      return '{${value.length} fields}';
    }
    return value.toString();
  }

  /// Flatten nested map fields for grid rendering using dot notation.
  /// Example: {"a": {"b": 1}} -> {"a.b": 1}
  Map<String, dynamic> flattenForGrid(
    Map<String, dynamic> data, {
    int maxDepth = 2,
  }) {
    final flattened = <String, dynamic>{};

    void visit(String path, dynamic value, int depth) {
      if (value is Map<String, dynamic> && depth < maxDepth) {
        if (value.isEmpty) {
          if (path.isNotEmpty) flattened[path] = value;
          return;
        }
        for (final entry in value.entries) {
          final nextPath = path.isEmpty ? entry.key : '$path.${entry.key}';
          visit(nextPath, entry.value, depth + 1);
        }
        return;
      }

      if (path.isNotEmpty) {
        flattened[path] = value;
      }
    }

    for (final entry in data.entries) {
      visit(entry.key, entry.value, 0);
    }

    return flattened;
  }

  /// Extract unique, sorted grid columns from flattened rows.
  List<String> extractGridColumns(Iterable<Map<String, dynamic>> rows) {
    final columns = <String>{};
    for (final row in rows) {
      columns.addAll(row.keys);
    }

    final sorted = columns.toList();
    sorted.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return sorted;
  }

  /// Format a value for a compact grid cell.
  String formatGridCellValue(dynamic value, {int maxLength = 160}) {
    String text;
    if (value is Timestamp || value is GeoPoint || value is DocumentReference) {
      text = formatValue(value);
    } else if (value is Map || value is List) {
      try {
        text = jsonEncode(value);
      } catch (_) {
        text = formatValue(value);
      }
    } else {
      text = formatValue(value);
    }

    if (text.length <= maxLength) {
      return text;
    }
    return '${text.substring(0, maxLength - 3)}...';
  }

  /// Parse a string value to the appropriate Firestore type
  static dynamic parseValue(String input, String targetType) {
    switch (targetType) {
      case 'string':
        return input;
      case 'number':
        if (input.contains('.')) {
          return double.tryParse(input) ?? 0.0;
        }
        return int.tryParse(input) ?? 0;
      case 'boolean':
        return input.toLowerCase() == 'true';
      case 'null':
        return null;
      default:
        return input;
    }
  }

  /// Search across all collections for documents containing the search term
  Future<List<SearchResult>> searchAllCollections(String searchTerm) async {
    if (searchTerm.isEmpty) return [];

    final results = <SearchResult>[];
    final lowerSearchTerm = searchTerm.toLowerCase();
    final collectionsToSearch = _collectionsLoaded
        ? _collections
        : _defaultCollections;

    for (final collection in collectionsToSearch) {
      try {
        final snapshot = await _firestore.collection(collection).get();

        for (final doc in snapshot.docs) {
          final matchedFields = <MatchedField>[];

          // Check document ID
          if (doc.id.toLowerCase().contains(lowerSearchTerm)) {
            matchedFields.add(
              MatchedField(
                fieldName: '(Document ID)',
                fieldValue: doc.id,
                fieldType: 'string',
              ),
            );
          }

          // Check all fields
          _searchInMap(doc.data(), lowerSearchTerm, matchedFields, '');

          if (matchedFields.isNotEmpty) {
            results.add(
              SearchResult(
                collection: collection,
                documentId: doc.id,
                documentPath: doc.reference.path,
                matchedFields: matchedFields,
                data: doc.data(),
              ),
            );
          }
        }
      } catch (e) {
        // Skip collections that can't be accessed
        continue;
      }
    }

    return results;
  }

  /// Recursively search in a map for matching values
  void _searchInMap(
    Map<String, dynamic> data,
    String searchTerm,
    List<MatchedField> matches,
    String prefix,
  ) {
    for (final entry in data.entries) {
      final fieldPath = prefix.isEmpty ? entry.key : '$prefix.${entry.key}';
      final value = entry.value;

      if (value == null) continue;

      if (value is String) {
        if (value.toLowerCase().contains(searchTerm)) {
          matches.add(
            MatchedField(
              fieldName: fieldPath,
              fieldValue: value,
              fieldType: 'string',
            ),
          );
        }
      } else if (value is num) {
        if (value.toString().contains(searchTerm)) {
          matches.add(
            MatchedField(
              fieldName: fieldPath,
              fieldValue: value.toString(),
              fieldType: 'number',
            ),
          );
        }
      } else if (value is Map<String, dynamic>) {
        _searchInMap(value, searchTerm, matches, fieldPath);
      } else if (value is List) {
        for (var i = 0; i < value.length; i++) {
          final item = value[i];
          if (item is String && item.toLowerCase().contains(searchTerm)) {
            matches.add(
              MatchedField(
                fieldName: '$fieldPath[$i]',
                fieldValue: item,
                fieldType: 'string',
              ),
            );
          } else if (item is num && item.toString().contains(searchTerm)) {
            matches.add(
              MatchedField(
                fieldName: '$fieldPath[$i]',
                fieldValue: item.toString(),
                fieldType: 'number',
              ),
            );
          } else if (item is Map<String, dynamic>) {
            _searchInMap(item, searchTerm, matches, '$fieldPath[$i]');
          }
        }
      }
    }
  }
}

/// Represents a search result
class SearchResult {
  final String collection;
  final String documentId;
  final String documentPath;
  final List<MatchedField> matchedFields;
  final Map<String, dynamic> data;

  SearchResult({
    required this.collection,
    required this.documentId,
    required this.documentPath,
    required this.matchedFields,
    required this.data,
  });
}

/// Represents a matched field in search results
class MatchedField {
  final String fieldName;
  final String fieldValue;
  final String fieldType;

  MatchedField({
    required this.fieldName,
    required this.fieldValue,
    required this.fieldType,
  });
}

/// Operators for query conditions
enum QueryOperator {
  equals('==', 'equals'),
  notEquals('!=', 'not equals'),
  lessThan('<', 'less than'),
  lessThanOrEqual('<=', 'less than or equal'),
  greaterThan('>', 'greater than'),
  greaterThanOrEqual('>=', 'greater than or equal'),
  startsWith('starts with', 'starts with'),
  stringContains('contains', 'contains (client-side)'),
  arrayContains('array has', 'array contains'),
  isNull('is null', 'is null'),
  isNotNull('is not null', 'is not null');

  final String symbol;
  final String label;

  const QueryOperator(this.symbol, this.label);

  /// Whether this operator requires client-side filtering
  bool get isClientSide => this == QueryOperator.stringContains;
}

/// Represents a query condition (where clause)
class QueryCondition {
  final String field;
  final QueryOperator operator;
  final String value;
  final String valueType; // 'string', 'number', 'boolean'

  QueryCondition({
    required this.field,
    required this.operator,
    required this.value,
    this.valueType = 'string',
  });

  /// Parse the value to the appropriate type for Firestore
  dynamic get parsedValue {
    if (operator == QueryOperator.isNull ||
        operator == QueryOperator.isNotNull) {
      return null;
    }

    switch (valueType) {
      case 'number':
        if (value.contains('.')) {
          return double.tryParse(value) ?? 0.0;
        }
        return int.tryParse(value) ?? 0;
      case 'boolean':
        return value.toLowerCase() == 'true';
      case 'string':
      default:
        return value;
    }
  }

  @override
  String toString() {
    if (operator == QueryOperator.isNull ||
        operator == QueryOperator.isNotNull) {
      return '$field ${operator.symbol}';
    }
    return '$field ${operator.symbol} "$value"';
  }
}

class SnapshotData {
  final Map<String, dynamic> payload;
  final Map<String, int> documentCounts;

  SnapshotData({required this.payload, required this.documentCounts});

  int get totalDocuments =>
      documentCounts.values.fold(0, (total, docTotal) => total + docTotal);
}

class SnapshotCollectionPreview {
  final String collection;
  final int snapshotDocumentCount;
  final int existingDocumentCount;

  SnapshotCollectionPreview({
    required this.collection,
    required this.snapshotDocumentCount,
    required this.existingDocumentCount,
  });
}

class SnapshotPreview {
  final List<SnapshotCollectionPreview> collections;

  SnapshotPreview({required this.collections});

  int get snapshotTotalDocuments =>
      collections.fold(0, (total, item) => total + item.snapshotDocumentCount);

  int get existingTotalDocuments =>
      collections.fold(0, (total, item) => total + item.existingDocumentCount);
}

class SnapshotRestoreResult {
  final int collectionsProcessed;
  final int deletedDocuments;
  final int upsertedDocuments;
  final bool clearCollectionsBeforeRestore;

  SnapshotRestoreResult({
    required this.collectionsProcessed,
    required this.deletedDocuments,
    required this.upsertedDocuments,
    required this.clearCollectionsBeforeRestore,
  });
}
