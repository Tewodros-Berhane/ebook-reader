enum DownloadStatus { pending, downloading, ready }

enum SyncStatus { synced, pending, failed }

class BookRecord {
  const BookRecord({
    required this.fileId,
    required this.title,
    required this.author,
    required this.thumbnailUrl,
    required this.localPath,
    required this.lastCfi,
    required this.lastChapter,
    required this.lastPercent,
    required this.timestamp,
    required this.isDirty,
    required this.syncStatus,
    required this.syncError,
    required this.downloadStatus,
    required this.modifiedTime,
  });

  final String fileId;
  final String title;
  final String author;
  final String thumbnailUrl;
  final String localPath;
  final String lastCfi;
  final int lastChapter;
  final double lastPercent;
  final int timestamp;
  final bool isDirty;
  final SyncStatus syncStatus;
  final String syncError;
  final DownloadStatus downloadStatus;
  final int modifiedTime;

  bool get isDownloaded =>
      localPath.isNotEmpty && downloadStatus == DownloadStatus.ready;

  bool get hasFallbackProgress => lastChapter > 0 && lastPercent >= 0;

  BookRecord copyWith({
    String? fileId,
    String? title,
    String? author,
    String? thumbnailUrl,
    String? localPath,
    String? lastCfi,
    int? lastChapter,
    double? lastPercent,
    int? timestamp,
    bool? isDirty,
    SyncStatus? syncStatus,
    String? syncError,
    DownloadStatus? downloadStatus,
    int? modifiedTime,
  }) {
    return BookRecord(
      fileId: fileId ?? this.fileId,
      title: title ?? this.title,
      author: author ?? this.author,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      localPath: localPath ?? this.localPath,
      lastCfi: lastCfi ?? this.lastCfi,
      lastChapter: lastChapter ?? this.lastChapter,
      lastPercent: lastPercent ?? this.lastPercent,
      timestamp: timestamp ?? this.timestamp,
      isDirty: isDirty ?? this.isDirty,
      syncStatus: syncStatus ?? this.syncStatus,
      syncError: syncError ?? this.syncError,
      downloadStatus: downloadStatus ?? this.downloadStatus,
      modifiedTime: modifiedTime ?? this.modifiedTime,
    );
  }

  Map<String, Object?> toMap() {
    return <String, Object?>{
      "fileId": fileId,
      "title": title,
      "author": author,
      "thumbnailUrl": thumbnailUrl,
      "localPath": localPath,
      "lastCfi": lastCfi,
      "lastChapter": lastChapter,
      "lastPercent": lastPercent,
      "timestamp": timestamp,
      "isDirty": isDirty ? 1 : 0,
      "syncStatus": syncStatus.name,
      "syncError": syncError,
      "downloadStatus": downloadStatus.name,
      "modifiedTime": modifiedTime,
    };
  }

  factory BookRecord.fromMap(Map<String, Object?> map) {
    final String rawStatus =
        (map["downloadStatus"] as String?) ?? DownloadStatus.pending.name;
    final String rawSyncStatus =
        (map["syncStatus"] as String?) ??
        ((((map["isDirty"] as int?) ?? 0) == 1)
            ? SyncStatus.pending.name
            : SyncStatus.synced.name);
    final num rawPercent = (map["lastPercent"] as num?) ?? -1;

    return BookRecord(
      fileId: (map["fileId"] as String?) ?? "",
      title: (map["title"] as String?) ?? "Unknown title",
      author: (map["author"] as String?) ?? "Unknown author",
      thumbnailUrl: (map["thumbnailUrl"] as String?) ?? "",
      localPath: (map["localPath"] as String?) ?? "",
      lastCfi: (map["lastCfi"] as String?) ?? "",
      lastChapter: (map["lastChapter"] as int?) ?? -1,
      lastPercent: rawPercent.toDouble(),
      timestamp: (map["timestamp"] as int?) ?? 0,
      isDirty: ((map["isDirty"] as int?) ?? 0) == 1,
      syncStatus: SyncStatus.values.firstWhere(
        (status) => status.name == rawSyncStatus,
        orElse: () => SyncStatus.synced,
      ),
      syncError: (map["syncError"] as String?) ?? "",
      downloadStatus: DownloadStatus.values.firstWhere(
        (status) => status.name == rawStatus,
        orElse: () => DownloadStatus.pending,
      ),
      modifiedTime: (map["modifiedTime"] as int?) ?? 0,
    );
  }
}
