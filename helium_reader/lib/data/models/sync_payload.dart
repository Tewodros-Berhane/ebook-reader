class SyncBookEntry {
  const SyncBookEntry({
    required this.cfi,
    required this.ts,
    this.chapter,
    this.percent,
  });

  final String cfi;
  final int ts;
  final int? chapter;
  final double? percent;

  Map<String, Object?> toJson() {
    return <String, Object?>{
      "cfi": cfi,
      "ts": ts,
      if (chapter != null) "chapter": chapter,
      if (percent != null) "percent": percent,
    };
  }

  factory SyncBookEntry.fromJson(Map<String, Object?> json) {
    final num? rawPercent = json["percent"] as num?;
    return SyncBookEntry(
      cfi: (json["cfi"] as String?) ?? "",
      ts: (json["ts"] as num?)?.toInt() ?? 0,
      chapter: (json["chapter"] as num?)?.toInt(),
      percent: rawPercent?.toDouble(),
    );
  }
}

class SyncPayload {
  const SyncPayload({
    required this.lastSynced,
    required this.lastDevice,
    required this.books,
  });

  final String lastSynced;
  final String lastDevice;
  final Map<String, SyncBookEntry> books;

  factory SyncPayload.empty() {
    return const SyncPayload(
      lastSynced: "",
      lastDevice: "",
      books: <String, SyncBookEntry>{},
    );
  }

  SyncPayload copyWith({
    String? lastSynced,
    String? lastDevice,
    Map<String, SyncBookEntry>? books,
  }) {
    return SyncPayload(
      lastSynced: lastSynced ?? this.lastSynced,
      lastDevice: lastDevice ?? this.lastDevice,
      books: books ?? this.books,
    );
  }

  Map<String, Object?> toJson() {
    final Map<String, Object?> serializedBooks = <String, Object?>{};
    for (final MapEntry<String, SyncBookEntry> entry in books.entries) {
      serializedBooks[entry.key] = entry.value.toJson();
    }

    return <String, Object?>{
      "last_synced": lastSynced,
      "last_device": lastDevice,
      "books": serializedBooks,
    };
  }

  factory SyncPayload.fromJson(Map<String, Object?> json) {
    final Map<String, SyncBookEntry> parsedBooks = <String, SyncBookEntry>{};
    final Object? rawBooks = json["books"];
    if (rawBooks is Map) {
      for (final MapEntry<dynamic, dynamic> entry in rawBooks.entries) {
        if (entry.key is String && entry.value is Map<String, Object?>) {
          parsedBooks[entry.key as String] = SyncBookEntry.fromJson(
            entry.value as Map<String, Object?>,
          );
        } else if (entry.key is String && entry.value is Map) {
          final Map<String, Object?> casted = <String, Object?>{};
          (entry.value as Map).forEach((key, value) {
            if (key is String) {
              casted[key] = value;
            }
          });
          parsedBooks[entry.key as String] = SyncBookEntry.fromJson(casted);
        }
      }
    }

    return SyncPayload(
      lastSynced: (json["last_synced"] as String?) ?? "",
      lastDevice: (json["last_device"] as String?) ?? "",
      books: parsedBooks,
    );
  }
}

class SyncFileDocument {
  const SyncFileDocument({required this.fileId, required this.payload});

  final String fileId;
  final SyncPayload payload;
}
