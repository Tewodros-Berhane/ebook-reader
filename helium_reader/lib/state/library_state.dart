import "../data/models/book_record.dart";

class LibraryState {
  const LibraryState({
    required this.books,
    required this.loading,
    required this.syncing,
    required this.selectedFolderId,
    required this.selectedFolderName,
    required this.error,
  });

  static const Object _keep = Object();

  final List<BookRecord> books;
  final bool loading;
  final bool syncing;
  final String? selectedFolderId;
  final String? selectedFolderName;
  final String? error;

  LibraryState copyWith({
    List<BookRecord>? books,
    bool? loading,
    bool? syncing,
    Object? selectedFolderId = _keep,
    Object? selectedFolderName = _keep,
    Object? error = _keep,
  }) {
    return LibraryState(
      books: books ?? this.books,
      loading: loading ?? this.loading,
      syncing: syncing ?? this.syncing,
      selectedFolderId: selectedFolderId == _keep
          ? this.selectedFolderId
          : selectedFolderId as String?,
      selectedFolderName: selectedFolderName == _keep
          ? this.selectedFolderName
          : selectedFolderName as String?,
      error: error == _keep ? this.error : error as String?,
    );
  }

  static const LibraryState initial = LibraryState(
    books: <BookRecord>[],
    loading: false,
    syncing: false,
    selectedFolderId: null,
    selectedFolderName: null,
    error: null,
  );
}
