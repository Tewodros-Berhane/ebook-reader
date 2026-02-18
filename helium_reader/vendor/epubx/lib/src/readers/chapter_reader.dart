import '../ref_entities/epub_book_ref.dart';
import '../ref_entities/epub_chapter_ref.dart';
import '../ref_entities/epub_text_content_file_ref.dart';
import '../schema/navigation/epub_navigation_point.dart';

class ChapterReader {
  static List<EpubChapterRef> getChapters(EpubBookRef bookRef) {
    if (bookRef.Schema!.Navigation == null) {
      return <EpubChapterRef>[];
    }
    return getChaptersImpl(
      bookRef,
      bookRef.Schema!.Navigation!.NavMap!.Points!,
    );
  }

  static List<EpubChapterRef> getChaptersImpl(
    EpubBookRef bookRef,
    List<EpubNavigationPoint> navigationPoints,
  ) {
    var result = <EpubChapterRef>[];
    for (var navigationPoint in navigationPoints) {
      String? contentFileName;
      String? anchor;
      if (navigationPoint.Content?.Source == null) {
        continue;
      }

      var contentSourceAnchorCharIndex =
          navigationPoint.Content!.Source!.indexOf('#');
      if (contentSourceAnchorCharIndex == -1) {
        contentFileName = navigationPoint.Content!.Source;
        anchor = null;
      } else {
        contentFileName = navigationPoint.Content!.Source!
            .substring(0, contentSourceAnchorCharIndex);
        anchor = navigationPoint.Content!.Source!
            .substring(contentSourceAnchorCharIndex + 1);
      }

      contentFileName = Uri.decodeFull(contentFileName!).replaceAll('\\', '/');

      EpubTextContentFileRef? htmlContentFileRef =
          bookRef.Content!.Html![contentFileName];

      if (htmlContentFileRef == null) {
        final String normalizedTarget = contentFileName.toLowerCase();
        for (final entry in bookRef.Content!.Html!.entries) {
          final String key = entry.key.toLowerCase().replaceAll('\\', '/');
          if (key == normalizedTarget) {
            htmlContentFileRef = entry.value;
            break;
          }
        }
      }

      if (htmlContentFileRef == null) {
        // Skip malformed TOC entries instead of failing to open the whole book.
        continue;
      }

      var chapterRef = EpubChapterRef(htmlContentFileRef);
      chapterRef.ContentFileName =
          htmlContentFileRef.FileName ?? contentFileName;
      chapterRef.Anchor = anchor;
      chapterRef.Title = navigationPoint.NavigationLabels!.first.Text;
      chapterRef.SubChapters =
          getChaptersImpl(bookRef, navigationPoint.ChildNavigationPoints!);

      result.add(chapterRef);
    }
    return result;
  }
}
