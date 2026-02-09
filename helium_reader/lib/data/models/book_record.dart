enum DownloadStatus { pending, downloading, ready }

class BookRecord {
  const BookRecord({
    required this.fileId,
    required this.title,
    required this.author,
    required this.thumbnailUrl,
    required this.localPath,
    required this.lastCfi,
    required this.timestamp,
    required this.isDirty,
    required this.downloadStatus,
    required this.modifiedTime,
  });

  final String fileId;
  final String title;
  final String author;
  final String thumbnailUrl;
  final String localPath;
  final String lastCfi;
  final int timestamp;
  final bool isDirty;
  final DownloadStatus downloadStatus;
  final int modifiedTime;

  bool get isDownloaded =>
      localPath.isNotEmpty && downloadStatus == DownloadStatus.ready;

  BookRecord copyWith({
    String? fileId,
    String? title,
    String? author,
    String? thumbnailUrl,
    String? localPath,
    String? lastCfi,
    int? timestamp,
    bool? isDirty,
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
      timestamp: timestamp ?? this.timestamp,
      isDirty: isDirty ?? this.isDirty,
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
      "timestamp": timestamp,
      "isDirty": isDirty ? 1 : 0,
      "downloadStatus": downloadStatus.name,
      "modifiedTime": modifiedTime,
    };
  }

  factory BookRecord.fromMap(Map<String, Object?> map) {
    final String rawStatus =
        (map["downloadStatus"] as String?) ?? DownloadStatus.pending.name;
    return BookRecord(
      fileId: (map["fileId"] as String?) ?? "",
      title: (map["title"] as String?) ?? "Unknown title",
      author: (map["author"] as String?) ?? "Unknown author",
      thumbnailUrl: (map["thumbnailUrl"] as String?) ?? "",
      localPath: (map["localPath"] as String?) ?? "",
      lastCfi: (map["lastCfi"] as String?) ?? "",
      timestamp: (map["timestamp"] as int?) ?? 0,
      isDirty: ((map["isDirty"] as int?) ?? 0) == 1,
      downloadStatus: DownloadStatus.values.firstWhere(
        (status) => status.name == rawStatus,
        orElse: () => DownloadStatus.pending,
      ),
      modifiedTime: (map["modifiedTime"] as int?) ?? 0,
    );
  }
}
