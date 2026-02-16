import "package:cached_network_image/cached_network_image.dart";
import "package:flutter/material.dart";

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

    return Card(
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
                  const SizedBox(height: 2),
                  Text(
                    book.author,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12, color: AppTheme.muted),
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
    if (thumbnailUri == null) {
      return _placeholder();
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
      cacheKey: "thumb-${book.fileId}-${thumbnailUri.toString()}",
      httpHeaders: headers,
      errorWidget: (context, url, error) => _placeholder(),
      placeholder: (context, url) => Container(color: const Color(0xFF363636)),
    );
  }

  Uri? get _thumbnailUri {
    if (book.fileId.isNotEmpty) {
      return Uri.https("drive.google.com", "/thumbnail", <String, String>{
        "id": book.fileId,
        "sz": "w420",
      });
    }

    if (book.thumbnailUrl.isEmpty) {
      return null;
    }

    final Uri? parsed = Uri.tryParse(book.thumbnailUrl.trim());
    if (parsed == null) {
      return null;
    }

    if (parsed.scheme == "http") {
      return parsed.replace(scheme: "https");
    }

    return parsed;
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
