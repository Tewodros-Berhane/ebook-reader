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
    final Color statusColor;
    final String statusText;

    if (book.isDirty) {
      statusColor = AppTheme.accent;
      statusText = "Sync pending";
    } else if (book.isDownloaded) {
      statusColor = const Color(0xFF7CD992);
      statusText = "Downloaded";
    } else {
      statusColor = const Color(0xFF9E9E9E);
      statusText = "Cloud";
    }

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
                        width: 7,
                        height: 7,
                        decoration: BoxDecoration(
                          color: statusColor,
                          borderRadius: BorderRadius.circular(99),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        statusText,
                        style: const TextStyle(
                          fontSize: 10,
                          color: AppTheme.muted,
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
