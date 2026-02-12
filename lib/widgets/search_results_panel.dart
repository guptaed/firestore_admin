import 'package:flutter/material.dart';
import '../services/firestore_admin_service.dart';

class SearchResultsPanel extends StatelessWidget {
  final String searchTerm;
  final List<SearchResult> results;
  final bool isLoading;
  final Function(String documentPath) onResultTap;
  final VoidCallback onClose;

  const SearchResultsPanel({
    super.key,
    required this.searchTerm,
    required this.results,
    required this.isLoading,
    required this.onResultTap,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    // Group results by collection
    final groupedResults = <String, List<SearchResult>>{};
    for (final result in results) {
      groupedResults.putIfAbsent(result.collection, () => []).add(result);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primaryContainer,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(12),
              topRight: Radius.circular(12),
            ),
          ),
          child: Row(
            children: [
              Icon(
                Icons.search,
                size: 20,
                color: Theme.of(context).colorScheme.onPrimaryContainer,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Search Results',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                      ),
                    ),
                    Text(
                      'Searching for: "$searchTerm"',
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context)
                            .colorScheme
                            .onPrimaryContainer
                            .withValues(alpha: 0.8),
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: Icon(
                  Icons.close,
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                ),
                tooltip: 'Close search',
                onPressed: onClose,
              ),
            ],
          ),
        ),
        // Summary bar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          color: Theme.of(context).colorScheme.surfaceContainerLow,
          child: Row(
            children: [
              if (isLoading)
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                Icon(
                  results.isEmpty ? Icons.search_off : Icons.check_circle,
                  size: 16,
                  color: results.isEmpty
                      ? Theme.of(context).colorScheme.outline
                      : Colors.green,
                ),
              const SizedBox(width: 8),
              Text(
                isLoading
                    ? 'Searching...'
                    : results.isEmpty
                        ? 'No matches found'
                        : 'Found ${results.length} match${results.length == 1 ? '' : 'es'} in ${groupedResults.length} collection${groupedResults.length == 1 ? '' : 's'}',
                style: TextStyle(
                  fontSize: 13,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        // Results list
        Expanded(
          child: isLoading
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 16),
                      Text('Searching all collections...'),
                    ],
                  ),
                )
              : results.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.search_off,
                            size: 64,
                            color: Theme.of(context).colorScheme.outline,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No matches found',
                            style: TextStyle(
                              fontSize: 18,
                              color: Theme.of(context).colorScheme.outline,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Try a different search term',
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.outline,
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      itemCount: groupedResults.length,
                      itemBuilder: (context, index) {
                        final collection =
                            groupedResults.keys.elementAt(index);
                        final collectionResults = groupedResults[collection]!;
                        return _buildCollectionGroup(
                          context,
                          collection,
                          collectionResults,
                        );
                      },
                    ),
        ),
      ],
    );
  }

  Widget _buildCollectionGroup(
    BuildContext context,
    String collection,
    List<SearchResult> results,
  ) {
    return ExpansionTile(
      initiallyExpanded: true,
      leading: Icon(
        Icons.folder,
        color: Colors.amber[700],
      ),
      title: Row(
        children: [
          Text(
            collection,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '${results.length}',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onPrimaryContainer,
              ),
            ),
          ),
        ],
      ),
      children: results.map((result) {
        return _buildResultItem(context, result);
      }).toList(),
    );
  }

  Widget _buildResultItem(BuildContext context, SearchResult result) {
    return InkWell(
      onTap: () => onResultTap(result.documentPath),
      child: Container(
        padding: const EdgeInsets.only(left: 24, right: 16, top: 8, bottom: 8),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: Theme.of(context).dividerColor.withValues(alpha: 0.3),
            ),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Document ID row
            Row(
              children: [
                Icon(
                  Icons.description,
                  size: 18,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    result.documentId,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios,
                  size: 14,
                  color: Theme.of(context).colorScheme.outline,
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Matched fields
            ...result.matchedFields.take(3).map((field) {
              return Padding(
                padding: const EdgeInsets.only(left: 26, bottom: 4),
                child: _buildMatchedField(context, field, result),
              );
            }),
            if (result.matchedFields.length > 3)
              Padding(
                padding: const EdgeInsets.only(left: 26),
                child: Text(
                  '+ ${result.matchedFields.length - 3} more matches',
                  style: TextStyle(
                    fontSize: 12,
                    fontStyle: FontStyle.italic,
                    color: Theme.of(context).colorScheme.outline,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildMatchedField(
    BuildContext context,
    MatchedField field,
    SearchResult result,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
          decoration: BoxDecoration(
            color: _getTypeColor(field.fieldType).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            field.fieldName,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: _getTypeColor(field.fieldType),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildHighlightedValue(context, field.fieldValue, searchTerm),
        ),
      ],
    );
  }

  Widget _buildHighlightedValue(
    BuildContext context,
    String value,
    String searchTerm,
  ) {
    final lowerValue = value.toLowerCase();
    final lowerSearch = searchTerm.toLowerCase();
    final startIndex = lowerValue.indexOf(lowerSearch);

    if (startIndex == -1) {
      return Text(
        value,
        style: const TextStyle(fontSize: 12),
        overflow: TextOverflow.ellipsis,
      );
    }

    final endIndex = startIndex + searchTerm.length;
    final before = value.substring(0, startIndex);
    final match = value.substring(startIndex, endIndex);
    final after = value.substring(endIndex);

    return RichText(
      overflow: TextOverflow.ellipsis,
      text: TextSpan(
        style: TextStyle(
          fontSize: 12,
          color: Theme.of(context).colorScheme.onSurface,
        ),
        children: [
          TextSpan(text: before),
          TextSpan(
            text: match,
            style: TextStyle(
              backgroundColor: Colors.yellow.withValues(alpha: 0.5),
              fontWeight: FontWeight.bold,
              color: Colors.orange[900],
            ),
          ),
          TextSpan(text: after),
        ],
      ),
    );
  }

  Color _getTypeColor(String type) {
    switch (type) {
      case 'string':
        return Colors.green;
      case 'number':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }
}
