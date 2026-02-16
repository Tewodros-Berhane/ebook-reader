import "package:flutter_riverpod/flutter_riverpod.dart";

import "../data/models/book_record.dart";
import "../data/services/drive_service.dart";
import "../data/services/library_service.dart";
import "../data/services/sync_service.dart";
import "library_state.dart";

class LibraryController extends StateNotifier<LibraryState> {
  LibraryController({
    required LibraryService libraryService,
    required SyncService syncService,
  }) : _libraryService = libraryService,
       _syncService = syncService,
       super(LibraryState.initial);

  final LibraryService _libraryService;
  final SyncService _syncService;

  bool _loaded = false;

  Future<void> loadInitial({bool signedIn = false}) async {
    if (_loaded) {
      return;
    }
    _loaded = true;

    await _loadFolderSelection();
    await reloadLocal();

    if (signedIn) {
      await refreshFromDrive();
      await syncProgress(silent: true);
    }
  }

  Future<void> _loadFolderSelection() async {
    final FolderSelection? selected = await _libraryService.selectedFolder();
    state = state.copyWith(
      selectedFolderId: selected?.id,
      selectedFolderName: selected?.name,
    );
  }

  Future<void> reloadLocal() async {
    final List<BookRecord> local = await _libraryService.localBooks();
    state = state.copyWith(books: local, loading: false, error: null);
  }

  Future<void> refreshFromDrive({String? folderId}) async {
    state = state.copyWith(loading: true, error: null);
    try {
      final List<BookRecord> updated = await _libraryService.refreshFromDrive(
        folderId: folderId ?? state.selectedFolderId,
      );
      state = state.copyWith(books: updated, loading: false, error: null);
    } catch (_) {
      state = state.copyWith(
        loading: false,
        error: "Could not fetch books from Drive.",
      );
    }
  }

  Future<List<DriveFolder>> folderOptions() {
    return _libraryService.listFolders();
  }

  Future<void> selectFolder(DriveFolder? folder) async {
    await _libraryService.saveSelectedFolder(folder);
    state = state.copyWith(
      selectedFolderId: folder?.id,
      selectedFolderName: folder?.name,
      error: null,
    );
    await refreshFromDrive(folderId: folder?.id);
  }

  Future<BookRecord> prepareForReading(String fileId) async {
    final BookRecord? local = await _libraryService.bookById(fileId);
    if (local == null) {
      throw StateError("Book not found in local database.");
    }

    final BookRecord ready = await _libraryService.ensureDownloaded(local);
    await reloadLocal();
    return ready;
  }

  Future<void> saveProgress({
    required String fileId,
    required String cfi,
    int? chapter,
    double? percent,
  }) async {
    await _libraryService.updateProgress(
      fileId: fileId,
      cfi: cfi,
      chapter: chapter,
      percent: percent,
    );
    await reloadLocal();
  }

  Future<void> syncProgress({bool silent = false}) async {
    if (state.syncing) {
      return;
    }

    final String? previousError = state.error;
    await _libraryService.markDirtyPending();
    await reloadLocal();

    state = state.copyWith(syncing: true, error: silent ? previousError : null);

    try {
      await _syncService.syncProgress(deviceName: "Flutter-App");
      await reloadLocal();
      state = state.copyWith(syncing: false, error: null);
    } catch (err) {
      final String failureMessage = _formatSyncError(err);
      await _libraryService.markDirtyFailed(failureMessage);
      await reloadLocal();
      state = state.copyWith(
        syncing: false,
        error: silent ? previousError : "Sync failed.",
      );
    }
  }

  String _formatSyncError(Object err) {
    final String raw = err.toString().trim();
    if (raw.isEmpty) {
      return "Unknown sync error";
    }

    final String compact = raw.replaceAll("\n", " ");
    if (compact.length <= 180) {
      return compact;
    }

    return "${compact.substring(0, 177)}...";
  }
}
