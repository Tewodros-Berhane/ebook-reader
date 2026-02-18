import "../db/app_database.dart";
import "../models/book_record.dart";
import "drive_service.dart";
import "file_service.dart";

class FolderSelection {
  const FolderSelection({required this.id, required this.name});

  final String id;
  final String name;
}

class LibraryService {
  const LibraryService({
    required AppDatabase database,
    required DriveService driveService,
    required FileService fileService,
  }) : _database = database,
       _driveService = driveService,
       _fileService = fileService;

  static const String _folderIdKey = "drive.folder.id";
  static const String _folderNameKey = "drive.folder.name";

  final AppDatabase _database;
  final DriveService _driveService;
  final FileService _fileService;

  Future<List<BookRecord>> localBooks() => _database.listBooks();

  Future<BookRecord?> bookById(String fileId) => _database.getBook(fileId);

  Future<bool> hasDownloadedBooks() => _database.hasDownloadedBooks();

  Future<List<BookRecord>> dirtyBooks() => _database.listDirtyBooks();

  Future<List<DriveFolder>> listFolders() => _driveService.listFolders();

  Future<FolderSelection?> selectedFolder() async {
    final String? id = await _database.getSetting(_folderIdKey);
    if (id == null || id.isEmpty) {
      return null;
    }
    final String name =
        (await _database.getSetting(_folderNameKey)) ?? "Selected folder";
    return FolderSelection(id: id, name: name);
  }

  Future<void> saveSelectedFolder(DriveFolder? folder) async {
    if (folder == null) {
      await _database.setSetting(_folderIdKey, "");
      await _database.setSetting(_folderNameKey, "");
      return;
    }

    await _database.setSetting(_folderIdKey, folder.id);
    await _database.setSetting(_folderNameKey, folder.name);
  }

  Future<List<BookRecord>> refreshFromDrive({String? folderId}) async {
    final List<BookRecord> existing = await _database.listBooks();
    final Map<String, BookRecord> existingById = <String, BookRecord>{
      for (final BookRecord book in existing) book.fileId: book,
    };

    final FolderSelection? selected = await selectedFolder();
    final String? effectiveFolder = folderId ?? selected?.id;

    final List<DriveBook> driveBooks = await _driveService.listEpubFiles(
      folderId: effectiveFolder,
    );
    final List<BookRecord> merged = driveBooks
        .map((driveBook) {
          final BookRecord? local = existingById[driveBook.fileId];
          return BookRecord(
            fileId: driveBook.fileId,
            title: driveBook.title,
            author: driveBook.author,
            thumbnailUrl: driveBook.thumbnailUrl,
            localPath: local?.localPath ?? "",
            lastCfi: local?.lastCfi ?? "",
            lastChapter: local?.lastChapter ?? -1,
            lastPercent: local?.lastPercent ?? -1,
            lastLocator: local?.lastLocator ?? "",
            timestamp: local?.timestamp ?? driveBook.modifiedTime,
            isDirty: local?.isDirty ?? false,
            syncStatus: local?.syncStatus ?? SyncStatus.synced,
            syncError: local?.syncError ?? "",
            downloadStatus: local?.downloadStatus ?? DownloadStatus.pending,
            modifiedTime: driveBook.modifiedTime,
            readerFontSize: local?.readerFontSize ?? 30,
          );
        })
        .toList(growable: false);

    await _database.upsertBooks(merged);
    return _database.listBooks();
  }

  Future<BookRecord> ensureDownloaded(
    BookRecord book, {
    bool forceRedownload = false,
  }) async {
    if (book.isDownloaded && !forceRedownload) {
      return book;
    }

    final String targetPath = book.localPath.trim().isNotEmpty
        ? book.localPath.trim()
        : await _fileService.bookPath(book.fileId);

    await _database.updateDownload(
      fileId: book.fileId,
      localPath: targetPath,
      status: DownloadStatus.downloading,
    );

    await _driveService.downloadFile(
      fileId: book.fileId,
      localPath: targetPath,
    );

    await _database.updateDownload(
      fileId: book.fileId,
      localPath: targetPath,
      status: DownloadStatus.ready,
    );

    final BookRecord? refreshed = await _database.getBook(book.fileId);
    if (refreshed == null) {
      throw StateError("Book disappeared from local database after download.");
    }
    return refreshed;
  }

  Future<void> updateProgress({
    required String fileId,
    required String cfi,
    String? locatorJson,
    int? chapter,
    double? percent,
  }) async {
    final BookRecord? current = await _database.getBook(fileId);
    final int resolvedChapter = chapter ?? current?.lastChapter ?? -1;
    final double resolvedPercent = percent ?? current?.lastPercent ?? -1;
    final String resolvedLocator = (locatorJson?.trim().isNotEmpty ?? false)
        ? locatorJson!.trim()
        : (current?.lastLocator ?? "");

    await _database.updateProgress(
      fileId: fileId,
      cfi: cfi,
      lastChapter: resolvedChapter,
      lastPercent: resolvedPercent,
      locatorJson: resolvedLocator,
      timestamp: DateTime.now().millisecondsSinceEpoch,
      isDirty: true,
    );
  }

  Future<void> updateReaderFontSize({
    required String fileId,
    required double fontSize,
  }) {
    return _database.updateReaderFontSize(fileId: fileId, fontSize: fontSize);
  }

  Future<void> applyCloudProgress({
    required String fileId,
    required String cfi,
    required int timestamp,
    String? locatorJson,
    int? chapter,
    double? percent,
  }) {
    return _database.updateProgress(
      fileId: fileId,
      cfi: cfi,
      lastChapter: chapter ?? -1,
      lastPercent: percent ?? -1,
      locatorJson: locatorJson?.trim() ?? "",
      timestamp: timestamp,
      isDirty: false,
    );
  }

  Future<void> markClean(List<String> fileIds) => _database.markClean(fileIds);

  Future<void> markDirtyPending() => _database.markDirtyPending();

  Future<void> markDirtyFailed(String message) =>
      _database.markDirtyFailed(message);
}
