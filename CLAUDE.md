# Firestore Admin Tool

A standalone Flutter Windows desktop app for browsing and managing the Firestore database for the `vietfuelprocapp` Firebase project.

## Project Overview

- **Location**: `c:\src\firestore_admin`
- **Platform**: Windows desktop only
- **Firebase Project**: vietfuelprocapp (shares config with `c:\src\gemini001`)
- **Authentication**: None (direct Firestore access)

## Architecture

### Two-Panel Layout
```
+------------------+--------------------------------+
| Collections      | Document Viewer / Results      |
| (Tree View)      |                                |
|                  | - Field table with types       |
| - Suppliers      | - Edit/Delete fields           |
| - Announcements  | - Add new fields               |
| - Bids           | - Back navigation to results   |
| - Shipments      |                                |
| - etc.           | Query Builder (collapsible)    |
+------------------+--------------------------------+
```

### Key Files

```
lib/
├── main.dart                         # App entry, Firebase init
├── firebase_options.dart             # Firebase config (from gemini001)
├── services/
│   └── firestore_admin_service.dart  # Core Firestore operations
├── screens/
│   └── home_screen.dart              # Main two-panel layout
└── widgets/
    ├── collection_tree.dart          # Left panel tree view
    ├── document_viewer.dart          # Document field viewer/editor
    ├── field_editor.dart             # Field editing dialog
    ├── query_builder.dart            # Query builder UI
    └── search_results_panel.dart     # Global search results
```

## Features Implemented

### 1. Collection Browser
- Tree view of all known collections
- Expandable to show documents
- Click to view document details

### 2. Document Viewer
- Table showing field name, type, value
- Supports all Firestore types (string, number, boolean, timestamp, geopoint, map, array, reference, null)
- Inline editing for primitive types
- Add/delete fields
- Delete document

### 3. Global Search
- Search bar in app bar
- Searches across ALL collections and ALL fields
- Highlights matched text
- Results grouped by collection
- Click result to view document
- "Back to Results" navigation

### 4. Query Builder
- Field dropdown (auto-populated from collection documents)
- Operators: ==, !=, <, <=, >, >=, starts with, contains, array has, is null, is not null
- "contains" operator uses client-side filtering (Firestore limitation)
- ORDER BY with field dropdown and ASC/DESC
- LIMIT
- Back navigation from document to query results

### 5. Client-Side Filtering
- `_FilteredQuerySnapshot` wrapper class for filtered results
- Supports nested field paths (e.g., `address.city`)
- Case-insensitive string matching

## Known Collections

Defined in `firestore_admin_service.dart`:
- Suppliers, SupplierHistory, Announcements, Bids, Shipments
- Contracts, Banks, CreditChecks, Smartphoneaccess, BidFlows, audit_trails

## Build & Run

```bash
# Development
cd c:\src\firestore_admin
flutter run -d windows

# Build release executable
flutter build windows --release

# Output location
build\windows\x64\runner\Release\firestore_admin.exe
```

## Future Enhancement Ideas

- Export/import documents as JSON
- Batch operations (bulk delete, bulk update)
- Dark/light theme toggle
- Firebase Authentication integration
- Subcollection navigation
- Copy document to another collection
- Undo/redo for edits
- Audit log viewer
