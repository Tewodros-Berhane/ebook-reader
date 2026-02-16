import "dart:async";
import "dart:convert";

import "../models/book_record.dart";
import "../models/sync_payload.dart";
import "auth_service.dart";
import "library_service.dart";
import "mysql_progress_service.dart";

class SyncService {
  SyncService({
    required LibraryService libraryService,
    required MySqlProgressService mySqlProgressService,
    required AuthService authService,
  }) : _libraryService = libraryService,
       _mySqlProgressService = mySqlProgressService,
       _authService = authService;

  static const int _maxAttempts = 3;

  final LibraryService _libraryService;
  final MySqlProgressService _mySqlProgressService;
  final AuthService _authService;

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
    final String userEmail = await _resolveUserEmail();
    final Map<String, SyncBookEntry> cloudBooks = await _mySqlProgressService
        .fetchUserProgress(userEmail: userEmail);

    final Map<String, SyncBookEntry> toUpload = <String, SyncBookEntry>{};
    final List<BookRecord> localBooks = await _libraryService.localBooks();
    final List<String> cleaned = <String>[];

    for (final BookRecord local in localBooks) {
      final bool hasProgress =
          local.lastCfi.isNotEmpty || local.hasFallbackProgress;
      if (!hasProgress) {
        continue;
      }

      final SyncBookEntry? cloudEntry = cloudBooks[local.fileId];

      if (local.isDirty) {
        if (cloudEntry == null || local.timestamp >= cloudEntry.ts) {
          toUpload[local.fileId] = SyncBookEntry(
            cfi: local.lastCfi,
            ts: local.timestamp,
            chapter: local.hasFallbackProgress ? local.lastChapter : null,
            percent: local.hasFallbackProgress ? local.lastPercent : null,
          );
          cleaned.add(local.fileId);
        } else {
          await _libraryService.applyCloudProgress(
            fileId: local.fileId,
            cfi: cloudEntry.cfi,
            timestamp: cloudEntry.ts,
            chapter: cloudEntry.chapter,
            percent: cloudEntry.percent,
          );
        }
        continue;
      }

      if (cloudEntry != null && cloudEntry.ts > local.timestamp) {
        await _libraryService.applyCloudProgress(
          fileId: local.fileId,
          cfi: cloudEntry.cfi,
          timestamp: cloudEntry.ts,
          chapter: cloudEntry.chapter,
          percent: cloudEntry.percent,
        );
        continue;
      }

      if (cloudEntry == null && local.timestamp > 0) {
        toUpload[local.fileId] = SyncBookEntry(
          cfi: local.lastCfi,
          ts: local.timestamp,
          chapter: local.hasFallbackProgress ? local.lastChapter : null,
          percent: local.hasFallbackProgress ? local.lastPercent : null,
        );
      }
    }

    if (toUpload.isNotEmpty) {
      await _mySqlProgressService.upsertUserProgress(
        userEmail: userEmail,
        entries: toUpload,
        deviceName: deviceName,
      );
    }

    if (cleaned.isNotEmpty) {
      await _libraryService.markClean(cleaned);
    }
  }

  Future<String> _resolveUserEmail() async {
    final String token =
        (await _authService.accessToken(promptIfNecessary: false) ?? "").trim();
    if (token.isEmpty) {
      throw StateError("Sign in is required before syncing progress.");
    }

    final String email =
        (await _authService.cachedProfile())?.email.trim() ?? "";
    if (email.isEmpty) {
      throw StateError("Cannot sync without a signed-in Google account email.");
    }

    return email.toLowerCase();
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
