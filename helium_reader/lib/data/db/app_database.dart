import "dart:io";

import "package:flutter/foundation.dart";
import "package:path/path.dart" as p;
import "package:path_provider/path_provider.dart";
import "package:sqflite_common_ffi/sqflite_ffi.dart";

import "../models/book_record.dart";

class AppDatabase {
  AppDatabase._();

  static final AppDatabase instance = AppDatabase._();

  Database? _db;

  Future<void> initialize() async {
    if (_db != null) {
      return;
    }

    if (!kIsWeb &&
        (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }

    final Directory baseDir = await getApplicationSupportDirectory();
    final String dbPath = p.join(baseDir.path, "helium_reader.db");

    _db = await openDatabase(
      dbPath,
      version: 1,
      onCreate: (Database db, int version) async {
        await db.execute('''
          CREATE TABLE books (
            fileId TEXT PRIMARY KEY,
            title TEXT NOT NULL,
            author TEXT NOT NULL,
            thumbnailUrl TEXT NOT NULL,
            localPath TEXT NOT NULL,
            lastCfi TEXT NOT NULL,
            timestamp INTEGER NOT NULL,
            isDirty INTEGER NOT NULL,
            downloadStatus TEXT NOT NULL,
            modifiedTime INTEGER NOT NULL
          )
        ''');

        await db.execute('''
          CREATE TABLE app_settings (
            key TEXT PRIMARY KEY,
            value TEXT NOT NULL
          )
        ''');
      },
    );
  }

  Database get _database {
    final Database? db = _db;
    if (db == null) {
      throw StateError("Database is not initialized.");
    }
    return db;
  }

  Future<List<BookRecord>> listBooks() async {
    final List<Map<String, Object?>> rows = await _database.query(
      "books",
      orderBy: "modifiedTime DESC",
    );
    return rows.map(BookRecord.fromMap).toList();
  }

  Future<BookRecord?> getBook(String fileId) async {
    final List<Map<String, Object?>> rows = await _database.query(
      "books",
      where: "fileId = ?",
      whereArgs: <Object?>[fileId],
      limit: 1,
    );
    if (rows.isEmpty) {
      return null;
    }
    return BookRecord.fromMap(rows.first);
  }

  Future<void> upsertBook(BookRecord book) async {
    await _database.insert(
      "books",
      book.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> upsertBooks(List<BookRecord> books) async {
    final Batch batch = _database.batch();
    for (final BookRecord book in books) {
      batch.insert(
        "books",
        book.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  Future<void> updateProgress({
    required String fileId,
    required String cfi,
    required int timestamp,
    required bool isDirty,
  }) async {
    await _database.update(
      "books",
      <String, Object?>{
        "lastCfi": cfi,
        "timestamp": timestamp,
        "isDirty": isDirty ? 1 : 0,
      },
      where: "fileId = ?",
      whereArgs: <Object?>[fileId],
    );
  }

  Future<void> updateDownload({
    required String fileId,
    required String localPath,
    required DownloadStatus status,
  }) async {
    await _database.update(
      "books",
      <String, Object?>{"localPath": localPath, "downloadStatus": status.name},
      where: "fileId = ?",
      whereArgs: <Object?>[fileId],
    );
  }

  Future<void> markClean(List<String> fileIds) async {
    if (fileIds.isEmpty) {
      return;
    }

    final Batch batch = _database.batch();
    for (final String fileId in fileIds) {
      batch.update(
        "books",
        <String, Object?>{"isDirty": 0},
        where: "fileId = ?",
        whereArgs: <Object?>[fileId],
      );
    }
    await batch.commit(noResult: true);
  }

  Future<List<BookRecord>> listDirtyBooks() async {
    final List<Map<String, Object?>> rows = await _database.query(
      "books",
      where: "isDirty = 1",
      orderBy: "timestamp DESC",
    );
    return rows.map(BookRecord.fromMap).toList();
  }

  Future<bool> hasDownloadedBooks() async {
    final List<Map<String, Object?>> rows = await _database.query(
      "books",
      where: "downloadStatus = ? AND localPath != ''",
      whereArgs: <Object?>[DownloadStatus.ready.name],
      limit: 1,
    );
    return rows.isNotEmpty;
  }

  Future<void> setSetting(String key, String value) async {
    await _database.insert("app_settings", <String, Object?>{
      "key": key,
      "value": value,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<String?> getSetting(String key) async {
    final List<Map<String, Object?>> rows = await _database.query(
      "app_settings",
      where: "key = ?",
      whereArgs: <Object?>[key],
      limit: 1,
    );
    if (rows.isEmpty) {
      return null;
    }
    return rows.first["value"] as String?;
  }
}
