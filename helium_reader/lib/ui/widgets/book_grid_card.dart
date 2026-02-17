import "dart:typed_data";

import "package:cached_network_image/cached_network_image.dart";
import "package:epubx/epubx.dart" as epub;
import "package:flutter/material.dart";
import "package:image/image.dart" as img;
import "package:universal_file/universal_file.dart" as ufile;

import "../../core/theme/app_theme.dart";
import "../../data/models/book_record.dart";

class BookGridCard extends StatelessWidget {
  const BookGridCard({
    super.key,
    required this.book,
    required this.onTap,
    required this.accessToken,
  });

  final BookRecord book;
  final VoidCallback onTap;
  final String? accessToken;

  @override
  Widget build(BuildContext context) {
    final _SyncBadge badge = _syncBadgeFor(book.syncStatus);

    return Tooltip(
      message: book.title,
      waitDuration: const Duration(milliseconds: 260),
      showDuration: const Duration(seconds: 4),
      preferBelow: false,
      constraints: const BoxConstraints(maxWidth: 320),
      decoration: BoxDecoration(
        color: const Color(0xFF111319),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.divider),
      ),
      textStyle: const TextStyle(color: Colors.white, fontSize: 12),
      child: Card(
        margin: EdgeInsets.zero,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                child: ClipRRect(
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(8),
                    topRight: Radius.circular(8),
                  ),
                  child: _CoverImage(book: book, accessToken: accessToken),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 8, 9),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      book.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 7),
                    Row(
                      children: <Widget>[
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: badge.background,
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(color: badge.border),
                          ),
                          child: Text(
                            badge.label,
                            style: const TextStyle(
                              fontSize: 10,
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        if (book.syncStatus == SyncStatus.failed &&
                            book.syncError.trim().isNotEmpty)
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.only(left: 6),
                              child: Text(
                                "Sync error",
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 10,
                                  color: AppTheme.accent,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  _SyncBadge _syncBadgeFor(SyncStatus status) {
    switch (status) {
      case SyncStatus.pending:
        return const _SyncBadge(
          label: "Pending",
          border: AppTheme.accent,
          background: Color(0x2BE57D8B),
        );
      case SyncStatus.failed:
        return const _SyncBadge(
          label: "Failed",
          border: Color(0xFFE25C5C),
          background: Color(0x2BE25C5C),
        );
      case SyncStatus.synced:
        return const _SyncBadge(
          label: "Synced",
          border: Color(0xFF7CD992),
          background: Color(0x2B7CD992),
        );
    }
  }
}

class _CoverImage extends StatelessWidget {
  const _CoverImage({required this.book, required this.accessToken});

  final BookRecord book;
  final String? accessToken;

  @override
  Widget build(BuildContext context) {
    final Uri? thumbnailUri = _thumbnailUri;
    final Widget localFallback = _LocalEpubCover(book: book);

    if (thumbnailUri == null) {
      return localFallback;
    }

    final bool includeAuth = _shouldAttachAuth(thumbnailUri);
    final Map<String, String> headers = <String, String>{
      "Accept": "image/*",
      if (includeAuth) "Authorization": "Bearer ${accessToken!.trim()}",
    };

    return CachedNetworkImage(
      imageUrl: thumbnailUri.toString(),
      fit: BoxFit.cover,
      width: double.infinity,
      cacheKey:
          "thumb-${book.fileId}-${thumbnailUri.toString()}-${includeAuth ? "auth" : "anon"}",
      httpHeaders: headers,
      errorWidget: (context, url, error) => localFallback,
      placeholder: (context, url) => Container(color: const Color(0xFF363636)),
    );
  }

  Uri? get _thumbnailUri {
    final String thumbnail = book.thumbnailUrl.trim();
    if (thumbnail.isNotEmpty) {
      final Uri? parsed = Uri.tryParse(thumbnail);
      if (parsed != null) {
        if (parsed.scheme == "http") {
          return parsed.replace(scheme: "https");
        }
        return parsed;
      }
    }

    if (book.fileId.isNotEmpty) {
      return Uri.https("drive.google.com", "/thumbnail", <String, String>{
        "id": book.fileId,
        "sz": "w420",
      });
    }

    return null;
  }

  bool _shouldAttachAuth(Uri uri) {
    if (accessToken == null || accessToken!.trim().isEmpty) {
      return false;
    }

    if (uri.scheme.toLowerCase() != "https") {
      return false;
    }

    final String host = uri.host.toLowerCase();
    return host == "drive.google.com" ||
        host == "www.googleapis.com" ||
        host == "lh3.googleusercontent.com" ||
        host.endsWith(".googleusercontent.com");
  }
}

class _LocalEpubCover extends StatelessWidget {
  const _LocalEpubCover({required this.book});

  final BookRecord book;

  @override
  Widget build(BuildContext context) {
    if (!book.isDownloaded || book.localPath.trim().isEmpty) {
      return _placeholder();
    }

    return FutureBuilder<Uint8List?>(
      future: _LocalEpubCoverCache.read(book.fileId, book.localPath),
      builder: (context, snapshot) {
        final Uint8List? bytes = snapshot.data;
        if (bytes == null || bytes.isEmpty) {
          return _placeholder();
        }

        return Image.memory(
          bytes,
          fit: BoxFit.cover,
          width: double.infinity,
          gaplessPlayback: true,
        );
      },
    );
  }

  Widget _placeholder() {
    return Container(
      color: const Color(0xFF363636),
      alignment: Alignment.center,
      child: const Icon(
        Icons.menu_book_rounded,
        size: 48,
        color: Color(0xFF666666),
      ),
    );
  }
}

class _LocalEpubCoverCache {
  static final Map<String, Future<Uint8List?>> _cache =
      <String, Future<Uint8List?>>{};

  static Future<Uint8List?> read(String fileId, String localPath) {
    final String path = localPath.trim();
    if (path.isEmpty) {
      return Future<Uint8List?>.value(null);
    }

    final String key = "$fileId|$path";
    return _cache.putIfAbsent(key, () => _readFromDisk(path));
  }

  static Future<Uint8List?> _readFromDisk(String localPath) async {
    try {
      final ufile.File file = ufile.File(localPath);
      if (!await file.exists()) {
        return null;
      }

      final Uint8List epubBytes = await file.readAsBytes();
      if (epubBytes.isEmpty) {
        return null;
      }

      final epub.EpubBookRef bookRef = await epub.EpubReader.openBook(
        epubBytes,
      );
      final img.Image? cover = await bookRef.readCover();
      if (cover == null) {
        return null;
      }

      final List<int> png = img.encodePng(cover);
      if (png.isEmpty) {
        return null;
      }

      return Uint8List.fromList(png);
    } catch (_) {
      return null;
    }
  }
}

class _SyncBadge {
  const _SyncBadge({
    required this.label,
    required this.border,
    required this.background,
  });

  final String label;
  final Color border;
  final Color background;
}
