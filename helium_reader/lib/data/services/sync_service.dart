import "dart:async";
import "dart:convert";
import "dart:developer" as dev;

import "../models/book_record.dart";
import "../models/reading_locator.dart";
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
      } catch (err, stack) {
        lastError = err;
        _log(
          "Sync attempt $attempt/$_maxAttempts failed: $err",
          error: err,
          stackTrace: stack,
        );

        if (attempt >= _maxAttempts) {
          rethrow;
        }
        await Future<void>.delayed(Duration(milliseconds: 350 * attempt));
      }
    }

    throw lastError ?? StateError("Unexpected sync failure.");
  }

  Future<void> _syncOnce({required String deviceName}) async {
    final SyncFileDocument? cloudDocument = await _driveService
        .getSyncDocument();
    final SyncPayload cloudPayload =
        cloudDocument?.payload ?? SyncPayload.empty();
    final Map<String, SyncBookEntry> cloudBooks =
        Map<String, SyncBookEntry>.from(cloudPayload.books);

    final Map<String, SyncBookEntry> toUpload = <String, SyncBookEntry>{};
    final List<BookRecord> localBooks = await _libraryService.localBooks();
    final List<String> cleaned = <String>[];

    int pulled = 0;
    int guarded = 0;

    for (final BookRecord local in localBooks) {
      final bool hasProgress =
          local.lastCfi.isNotEmpty ||
          local.hasFallbackProgress ||
          local.hasStructuredLocator;
      if (!hasProgress) {
        continue;
      }

      final SyncBookEntry? cloudEntry = cloudBooks[local.fileId];

      if (local.isDirty) {
        if (cloudEntry == null || local.timestamp >= cloudEntry.ts) {
          if (cloudEntry != null && _isLikelyRegression(local, cloudEntry)) {
            guarded += 1;
            pulled += 1;
            await _applyCloudEntry(local.fileId, cloudEntry);
            continue;
          }

          toUpload[local.fileId] = _entryFromLocal(local);
          cleaned.add(local.fileId);
        } else {
          pulled += 1;
          await _applyCloudEntry(local.fileId, cloudEntry);
        }
        continue;
      }

      if (cloudEntry != null && cloudEntry.ts > local.timestamp) {
        pulled += 1;
        await _applyCloudEntry(local.fileId, cloudEntry);
        continue;
      }

      if (cloudEntry == null && local.timestamp > 0) {
        toUpload[local.fileId] = _entryFromLocal(local);
      }
    }

    if (toUpload.isNotEmpty) {
      final Map<String, SyncBookEntry> mergedBooks =
          Map<String, SyncBookEntry>.from(cloudBooks)..addAll(toUpload);
      final SyncPayload nextPayload = cloudPayload.copyWith(
        lastSynced: DateTime.now().toUtc().toIso8601String(),
        lastDevice: deviceName,
        books: mergedBooks,
      );

      await _driveService.upsertSyncDocument(
        payload: nextPayload,
        existingFileId: cloudDocument?.fileId,
      );
    }

    if (cleaned.isNotEmpty) {
      await _libraryService.markClean(cleaned);
    }

    _log(
      "Sync complete: local=${localBooks.length}, cloud=${cloudBooks.length}, pulled=$pulled, upload=${toUpload.length}, cleaned=${cleaned.length}, guarded=$guarded",
    );
  }

  SyncBookEntry _entryFromLocal(BookRecord local) {
    return SyncBookEntry(
      cfi: local.lastCfi,
      ts: local.timestamp,
      chapter: local.hasFallbackProgress ? local.lastChapter : null,
      percent: local.hasFallbackProgress ? local.lastPercent : null,
      locator: local.locator?.toJson(),
    );
  }

  Future<void> _applyCloudEntry(String fileId, SyncBookEntry cloudEntry) {
    return _libraryService.applyCloudProgress(
      fileId: fileId,
      cfi: cloudEntry.cfi,
      timestamp: cloudEntry.ts,
      locatorJson: _encodeLocator(cloudEntry.locator),
      chapter: cloudEntry.chapter,
      percent: cloudEntry.percent,
    );
  }

  bool _isLikelyRegression(BookRecord local, SyncBookEntry cloudEntry) {
    final double? localScore = _progressScoreForLocal(local);
    final double? cloudScore = _progressScoreForCloud(cloudEntry);
    if (localScore == null || cloudScore == null) {
      return false;
    }

    // Prevent stale local rewinds from overwriting clearly newer cloud position.
    return localScore + 0.20 < cloudScore;
  }

  double? _progressScoreForLocal(BookRecord local) {
    final ReadingLocator? locator = local.locator;
    final double? total = locator?.totalProgression;
    if (total != null) {
      return total.clamp(0, 1).toDouble() * 10000;
    }

    if (local.lastChapter > 0) {
      final double percent = local.lastPercent.isFinite
          ? local.lastPercent.clamp(0, 100).toDouble()
          : 0;
      return local.lastChapter.toDouble() + (percent / 100);
    }

    final double? progression = locator?.progression;
    if (progression != null) {
      return progression.clamp(0, 1).toDouble();
    }

    return null;
  }

  double? _progressScoreForCloud(SyncBookEntry cloudEntry) {
    final ReadingLocator? locator = _locatorFromMap(cloudEntry.locator);
    final double? total = locator?.totalProgression;
    if (total != null) {
      return total.clamp(0, 1).toDouble() * 10000;
    }

    final int chapter = cloudEntry.chapter ?? -1;
    if (chapter > 0) {
      final double percent = (cloudEntry.percent ?? 0).clamp(0, 100).toDouble();
      return chapter.toDouble() + (percent / 100);
    }

    final double? progression = locator?.progression;
    if (progression != null) {
      return progression.clamp(0, 1).toDouble();
    }

    return null;
  }

  ReadingLocator? _locatorFromMap(Map<String, Object?>? raw) {
    if (raw == null || raw.isEmpty) {
      return null;
    }

    try {
      return ReadingLocator.fromJson(raw);
    } catch (_) {
      return null;
    }
  }

  Future<bool> backgroundSyncAttempt({
    String deviceName = "Flutter-Background",
  }) async {
    try {
      await syncProgress(deviceName: deviceName);
      return true;
    } catch (err, stack) {
      _log("Background sync failed: $err", error: err, stackTrace: stack);
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

  String? _encodeLocator(Map<String, Object?>? locator) {
    if (locator == null || locator.isEmpty) {
      return null;
    }
    return jsonEncode(locator);
  }

  void _log(String message, {Object? error, StackTrace? stackTrace}) {
    final String line = "[helium.sync] $message";
    // print() ensures visibility in terminal when running flutter run.
    // ignore: avoid_print
    print(line);
    dev.log(line, name: "helium.sync", error: error, stackTrace: stackTrace);
  }
}
