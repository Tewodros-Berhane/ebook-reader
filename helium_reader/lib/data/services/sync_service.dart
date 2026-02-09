import "dart:async";
import "dart:convert";

import "../models/book_record.dart";
import "../models/sync_payload.dart";
import "drive_service.dart";
import "library_service.dart";

class SyncService {
  SyncService({
    required LibraryService libraryService,
    required DriveService driveService,
  }) : _libraryService = libraryService,
       _driveService = driveService;

  static const int _maxAttempts = 3;

  final LibraryService _libraryService;
  final DriveService _driveService;

  Future<void>? _inFlight;

  Future<void> syncProgress({String deviceName = "Flutter"}) {
    final Future<void>? running = _inFlight;
    if (running != null) {
      return running;
    }

    final Future<void> operation = _syncWithRetry(deviceName: deviceName);
    _inFlight = operation;

    return operation.whenComplete(() {
      if (identical(_inFlight, operation)) {
        _inFlight = null;
      }
    });
  }

  Future<void> _syncWithRetry({required String deviceName}) async {
    Object? lastError;

    for (int attempt = 1; attempt <= _maxAttempts; attempt += 1) {
      try {
        await _syncOnce(deviceName: deviceName);
        return;
      } catch (err) {
        lastError = err;
        if (attempt >= _maxAttempts) {
          rethrow;
        }
        await Future<void>.delayed(Duration(milliseconds: 350 * attempt));
      }
    }

    throw lastError ?? StateError("Unexpected sync failure.");
  }

  Future<void> _syncOnce({required String deviceName}) async {
    final SyncFileDocument? existing = await _driveService.getSyncDocument();
    final SyncPayload cloud = existing?.payload ?? SyncPayload.empty();

    final Map<String, SyncBookEntry> mergedBooks = <String, SyncBookEntry>{
      ...cloud.books,
    };

    final List<BookRecord> localBooks = await _libraryService.localBooks();
    final List<String> cleaned = <String>[];

    for (final BookRecord local in localBooks) {
      if (local.lastCfi.isEmpty) {
        continue;
      }

      final SyncBookEntry? cloudEntry = mergedBooks[local.fileId];

      if (local.isDirty) {
        if (cloudEntry == null || local.timestamp >= cloudEntry.ts) {
          mergedBooks[local.fileId] = SyncBookEntry(
            cfi: local.lastCfi,
            ts: local.timestamp,
          );
          cleaned.add(local.fileId);
        } else {
          await _libraryService.applyCloudProgress(
            fileId: local.fileId,
            cfi: cloudEntry.cfi,
            timestamp: cloudEntry.ts,
          );
        }
        continue;
      }

      if (cloudEntry != null && cloudEntry.ts > local.timestamp) {
        await _libraryService.applyCloudProgress(
          fileId: local.fileId,
          cfi: cloudEntry.cfi,
          timestamp: cloudEntry.ts,
        );
      }
    }

    final SyncPayload merged = SyncPayload(
      lastSynced: DateTime.now().toUtc().toIso8601String(),
      lastDevice: deviceName,
      books: mergedBooks,
    );

    await _driveService.upsertSyncDocument(
      payload: merged,
      existingFileId: existing?.fileId,
    );

    if (cleaned.isNotEmpty) {
      await _libraryService.markClean(cleaned);
    }
  }

  Future<bool> backgroundSyncAttempt({
    String deviceName = "Flutter-Background",
  }) async {
    try {
      await syncProgress(deviceName: deviceName);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<String> exportSnapshot() async {
    final List<BookRecord> books = await _libraryService.localBooks();
    final Map<String, Object?> payload = <String, Object?>{
      "books": books.map((b) => b.toMap()).toList(growable: false),
    };
    return jsonEncode(payload);
  }
}
