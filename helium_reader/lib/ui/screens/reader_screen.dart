import "dart:async";

import "package:epub_view/epub_view.dart";
import "package:flutter/foundation.dart";
import "package:flutter/material.dart";
import "package:flutter/services.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:universal_file/universal_file.dart" as ufile;

import "../../app/providers.dart";
import "../../core/theme/app_theme.dart";
import "../../data/models/book_record.dart";
import "../../data/models/reading_locator.dart";

class ReaderScreen extends ConsumerStatefulWidget {
  const ReaderScreen({super.key, required this.book});

  final BookRecord book;

  @override
  ConsumerState<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends ConsumerState<ReaderScreen>
    with WidgetsBindingObserver {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  EpubController? _epubController;
  BookRecord? _book;
  String? _error;
  bool _loading = true;
  bool _closing = false;

  Timer? _progressDebounce;
  Timer? _periodicCheckpoint;
  String? _lastPersistedSignature;
  DateTime _openedAt = DateTime.now();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initialize();
  }

  Future<void> _initialize() async {
    try {
      _openedAt = DateTime.now();
      final BookRecord ready = await ref
          .read(libraryControllerProvider.notifier)
          .prepareForReading(widget.book.fileId);

      final ReadingLocator? locator = ready.locator;
      final String startupCfi = (locator?.cfi ?? ready.lastCfi).trim();

      final EpubController controller = EpubController(
        document: EpubDocument.openFile(ufile.File(ready.localPath)),
        epubCfi: startupCfi.isEmpty ? null : startupCfi,
      );

      _lastPersistedSignature = _signatureFrom(
        cfi: ready.lastCfi,
        chapter: ready.lastChapter > 0 ? ready.lastChapter : null,
        percent: ready.lastPercent >= 0 ? ready.lastPercent : null,
        locatorJson: ready.lastLocator.trim(),
      );

      controller.currentValueListenable.addListener(_onPositionChanged);
      _periodicCheckpoint = Timer.periodic(
        const Duration(seconds: 2),
        (_) => _scheduleProgressSave(),
      );

      _restoreSavedPosition(controller, ready);

      if (!mounted) {
        controller.currentValueListenable.removeListener(_onPositionChanged);
        _periodicCheckpoint?.cancel();
        controller.dispose();
        return;
      }

      setState(() {
        _book = ready;
        _epubController = controller;
        _loading = false;
      });
    } catch (err) {
      if (!mounted) {
        return;
      }
      setState(() {
        _loading = false;
        _error = err.toString();
      });
    }
  }

  void _restoreSavedPosition(EpubController controller, BookRecord book) {
    final ReadingLocator? locator = book.locator;
    final bool hasAnySaved =
        (locator != null && locator.hasMeaningfulPosition) ||
        book.lastCfi.trim().isNotEmpty ||
        book.lastChapter > 1;

    if (!hasAnySaved) {
      return;
    }

    Future<void> restore() async {
      await _waitForNavigatorReady(controller);

      bool usedRestoreStep = false;

      final int? positionIndex = locator?.position;
      if (positionIndex != null && positionIndex >= 0) {
        final bool jumped = await _safeJumpToIndex(
          controller,
          positionIndex,
          label: "locator position",
        );
        if (jumped) {
          usedRestoreStep = true;
          _logReader(
            "Restore by locator position for ${book.fileId}: index=$positionIndex",
          );
          await Future<void>.delayed(const Duration(milliseconds: 180));
        }
      }

      final String locatorCfi = (locator?.cfi ?? "").trim();
      if (!usedRestoreStep && locatorCfi.isNotEmpty) {
        final bool moved = await _safeGotoCfi(
          controller,
          locatorCfi,
          label: "locator cfi",
        );
        if (moved) {
          usedRestoreStep = true;
          _logReader("Restore by locator CFI for ${book.fileId}: $locatorCfi");
          await Future<void>.delayed(const Duration(milliseconds: 180));
        }
      }

      final String legacyCfi = book.lastCfi.trim();
      if (!usedRestoreStep && legacyCfi.isNotEmpty) {
        final bool moved = await _safeGotoCfi(
          controller,
          legacyCfi,
          label: "legacy cfi",
        );
        if (moved) {
          usedRestoreStep = true;
          _logReader("Restore by legacy CFI for ${book.fileId}: $legacyCfi");
          await Future<void>.delayed(const Duration(milliseconds: 180));
        }
      }

      if (usedRestoreStep) {
        return;
      }

      final int targetChapter = locator?.chapter ?? book.lastChapter;
      if (targetChapter <= 1) {
        return;
      }

      final int currentChapter = controller.currentValue?.chapterNumber ?? 0;
      if (currentChapter >= targetChapter - 1) {
        return;
      }

      final bool jumped = await _jumpToChapter(controller, targetChapter);
      if (jumped) {
        _logReader(
          "Applied chapter fallback for ${book.fileId}: chapter=$currentChapter -> $targetChapter",
        );
      }
    }

    if (controller.isBookLoaded.value) {
      unawaited(restore());
      return;
    }

    late VoidCallback listener;
    listener = () {
      if (!controller.isBookLoaded.value) {
        return;
      }
      controller.isBookLoaded.removeListener(listener);
      unawaited(restore());
    };
    controller.isBookLoaded.addListener(listener);
  }

  Future<void> _waitForNavigatorReady(EpubController controller) async {
    await WidgetsBinding.instance.endOfFrame;

    if (controller.currentValue != null) {
      return;
    }

    final Completer<void> completer = Completer<void>();
    late VoidCallback listener;
    listener = () {
      if (controller.currentValue == null || completer.isCompleted) {
        return;
      }
      completer.complete();
    };

    controller.currentValueListenable.addListener(listener);
    final Timer timeout = Timer(const Duration(seconds: 2), () {
      if (!completer.isCompleted) {
        completer.complete();
      }
    });

    try {
      await completer.future;
    } finally {
      timeout.cancel();
      controller.currentValueListenable.removeListener(listener);
    }

    await Future<void>.delayed(const Duration(milliseconds: 60));
  }

  Future<bool> _safeJumpToIndex(
    EpubController controller,
    int index, {
    required String label,
  }) async {
    for (int attempt = 1; attempt <= 5; attempt += 1) {
      try {
        controller.jumpTo(index: index);
        return true;
      } catch (err) {
        _logReader("$label jump failed (attempt $attempt): $err");
        await Future<void>.delayed(Duration(milliseconds: 120 * attempt));
      }
    }

    return false;
  }

  Future<bool> _safeGotoCfi(
    EpubController controller,
    String cfi, {
    required String label,
  }) async {
    for (int attempt = 1; attempt <= 4; attempt += 1) {
      try {
        controller.gotoEpubCfi(cfi, duration: Duration.zero);
        return true;
      } catch (err) {
        _logReader("$label gotoCfi failed (attempt $attempt): $err");
        await Future<void>.delayed(Duration(milliseconds: 100 * attempt));
      }
    }

    return false;
  }

  Future<bool> _jumpToChapter(
    EpubController controller,
    int chapterNumber,
  ) async {
    final List<dynamic> toc = controller.tableOfContents();
    final int targetIndex = chapterNumber - 1;
    if (targetIndex < 0 || targetIndex >= toc.length) {
      _logReader(
        "Skipping chapter fallback: chapter $chapterNumber is outside TOC bounds (${toc.length}).",
      );
      return false;
    }

    final int startIndex = (toc[targetIndex].startIndex as int?) ?? -1;
    if (startIndex < 0) {
      return false;
    }

    return _safeJumpToIndex(controller, startIndex, label: "chapter fallback");
  }

  _ReaderProgressSnapshot _captureSnapshot() {
    final EpubController? controller = _epubController;
    final dynamic current = controller?.currentValue;

    String cfi = controller?.generateEpubCfi()?.trim() ?? "";
    final String loweredCfi = cfi.toLowerCase();
    if (loweredCfi.contains("[toc]") || loweredCfi.contains("[nav]")) {
      cfi = "";
    }

    final int? chapter = (current?.chapterNumber ?? 0) > 0
        ? current!.chapterNumber
        : null;

    double? percent = current?.progress;
    if (percent != null) {
      if (!percent.isFinite) {
        percent = null;
      } else {
        percent = percent.clamp(0, 100).toDouble();
      }
    }

    final ReadingLocator? locator = _buildLocator(
      controller: controller,
      current: current,
      cfi: cfi,
      chapter: chapter,
      percent: percent,
    );

    return _ReaderProgressSnapshot(
      cfi: cfi,
      chapter: chapter,
      percent: percent,
      locatorJson: locator?.toJsonString() ?? "",
    );
  }

  ReadingLocator? _buildLocator({
    required EpubController? controller,
    required dynamic current,
    required String cfi,
    required int? chapter,
    required double? percent,
  }) {
    if (controller == null || current == null) {
      return null;
    }

    final dynamic chapterRef = current.chapter;
    final String href = (chapterRef?.ContentFileName as String? ?? "").trim();
    final String title = (chapterRef?.Title as String? ?? "")
        .replaceAll("\n", " ")
        .trim();

    final int? paragraph = current.paragraphNumber > 0
        ? current.paragraphNumber
        : null;
    final int? position = current.position.index >= 0
        ? current.position.index
        : null;

    final double? progression = percent == null
        ? null
        : (percent / 100).clamp(0, 1).toDouble();

    double? totalProgression;
    final int tocLength = controller.tableOfContents().length;
    if (chapter != null && progression != null && tocLength > 0) {
      totalProgression = ((chapter - 1) + progression) / tocLength;
      totalProgression = totalProgression.clamp(0, 1).toDouble();
    }

    final ReadingLocator locator = ReadingLocator(
      href: href,
      type: _mimeTypeForHref(href),
      title: title.isEmpty ? null : title,
      cfi: cfi.isEmpty ? null : cfi,
      chapter: chapter,
      paragraph: paragraph,
      position: position,
      progression: progression,
      totalProgression: totalProgression,
    );

    if (!locator.hasMeaningfulPosition) {
      return null;
    }

    return locator;
  }

  String? _mimeTypeForHref(String href) {
    final String lower = href.toLowerCase();
    if (lower.endsWith(".xhtml") ||
        lower.endsWith(".html") ||
        lower.endsWith(".htm")) {
      return "application/xhtml+xml";
    }
    return null;
  }

  void _onPositionChanged() {
    _scheduleProgressSave();
  }

  void _scheduleProgressSave() {
    final _ReaderProgressSnapshot snapshot = _captureSnapshot();
    _progressDebounce?.cancel();
    _progressDebounce = Timer(const Duration(milliseconds: 450), () async {
      await _persistProgress(
        cfi: snapshot.cfi,
        locatorJson: snapshot.locatorJson,
        chapter: snapshot.chapter,
        percent: snapshot.percent,
        sync: false,
      );
    });
  }

  Future<void> _persistProgress({
    String? cfi,
    String? locatorJson,
    int? chapter,
    double? percent,
    bool sync = false,
    bool forceWrite = false,
  }) async {
    final BookRecord? book = _book;
    if (book == null) {
      return;
    }

    final _ReaderProgressSnapshot snapshot = _captureSnapshot();
    final String resolvedCfi = (cfi ?? snapshot.cfi).trim();
    final String resolvedLocatorJson = (locatorJson ?? snapshot.locatorJson)
        .trim();
    final int? resolvedChapter = chapter ?? snapshot.chapter;
    final double? resolvedPercent = percent ?? snapshot.percent;

    final bool hasFallback =
        (resolvedChapter != null && resolvedChapter > 0) &&
        (resolvedPercent != null && resolvedPercent >= 0);

    if (resolvedCfi.isEmpty && !hasFallback && resolvedLocatorJson.isEmpty) {
      return;
    }

    final String signature = _signatureFrom(
      cfi: resolvedCfi,
      locatorJson: resolvedLocatorJson,
      chapter: resolvedChapter,
      percent: resolvedPercent,
    );

    if (!forceWrite && signature == _lastPersistedSignature) {
      if (sync) {
        await ref
            .read(libraryControllerProvider.notifier)
            .syncProgress(silent: true);
      }
      return;
    }

    if (!forceWrite && _shouldSkipEarlyReset(resolvedChapter)) {
      _logReader(
        "Ignored early reset write for ${book.fileId}: chapter=${resolvedChapter ?? -1}, existing=${book.lastChapter}.",
      );
      return;
    }

    await ref
        .read(libraryControllerProvider.notifier)
        .saveProgress(
          fileId: book.fileId,
          cfi: resolvedCfi,
          locatorJson: resolvedLocatorJson,
          chapter: resolvedChapter,
          percent: resolvedPercent,
        );

    _lastPersistedSignature = signature;

    if (sync) {
      await ref
          .read(libraryControllerProvider.notifier)
          .syncProgress(silent: true);
    }
  }

  String _signatureFrom({
    required String cfi,
    required String locatorJson,
    int? chapter,
    double? percent,
  }) {
    final int chapterPart = chapter ?? -1;
    final String percentPart = percent == null
        ? "-1"
        : percent.toStringAsFixed(2);
    return "$cfi|$chapterPart|$percentPart|$locatorJson";
  }

  bool _shouldSkipEarlyReset(int? chapter) {
    final int previousChapter = _book?.lastChapter ?? -1;
    if (previousChapter <= 1) {
      return false;
    }

    final Duration elapsed = DateTime.now().difference(_openedAt);
    if (elapsed > const Duration(seconds: 8)) {
      return false;
    }

    final int candidate = chapter ?? -1;
    return candidate <= 1 || candidate + 1 < previousChapter;
  }

  bool get _useKeyboardTocShortcut =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.windows;

  void _openTocDrawer() {
    if (_epubController == null) {
      return;
    }
    _scaffoldKey.currentState?.openDrawer();
  }

  Future<void> _handleTocTap(dynamic chapter) async {
    final ScaffoldState? state = _scaffoldKey.currentState;
    if (state?.isDrawerOpen ?? false) {
      Navigator.of(context).pop();
      await Future<void>.delayed(const Duration(milliseconds: 90));
    }

    final EpubController? controller = _epubController;
    if (controller == null) {
      return;
    }

    final bool jumped = await _safeJumpToIndex(
      controller,
      chapter.startIndex,
      label: "toc",
    );

    if (jumped) {
      _logReader(
        "TOC jump for ${widget.book.fileId}: index=${chapter.startIndex}, title=${chapter.title ?? ""}",
      );
    }
  }

  void _logReader(String message) {
    // ignore: avoid_print
    print("[helium.reader] $message");
  }

  Future<void> _syncBeforeExit([_ReaderProgressSnapshot? snapshot]) async {
    try {
      await _persistProgress(
        cfi: snapshot?.cfi,
        locatorJson: snapshot?.locatorJson,
        chapter: snapshot?.chapter,
        percent: snapshot?.percent,
        sync: true,
        forceWrite: true,
      );
    } catch (_) {
      // Keep close path responsive even if sync fails.
    }
  }

  Future<void> _closeReader() async {
    if (_closing) {
      return;
    }

    setState(() {
      _closing = true;
    });

    await _syncBeforeExit(_captureSnapshot());

    if (!mounted) {
      return;
    }

    Navigator.of(context).pop();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      unawaited(_syncBeforeExit(_captureSnapshot()));
    }
  }

  @override
  void dispose() {
    final _ReaderProgressSnapshot snapshot = _captureSnapshot();

    _progressDebounce?.cancel();
    _periodicCheckpoint?.cancel();
    WidgetsBinding.instance.removeObserver(this);

    final EpubController? controller = _epubController;
    if (controller != null) {
      controller.currentValueListenable.removeListener(_onPositionChanged);
    }

    _epubController?.dispose();
    unawaited(_syncBeforeExit(snapshot));

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final EpubController? controller = _epubController;

    final Widget scaffold = Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading: IconButton(
          tooltip: "Back to library",
          onPressed: _closeReader,
          icon: _closing
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.arrow_back_rounded),
        ),
        title: Text(
          widget.book.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: <Widget>[
          if (controller != null && !_useKeyboardTocShortcut)
            IconButton(
              tooltip: "Table of contents",
              onPressed: _openTocDrawer,
              icon: const Icon(Icons.format_list_bulleted_rounded),
            ),
          IconButton(
            tooltip: "Sync now",
            onPressed: () =>
                ref.read(libraryControllerProvider.notifier).syncProgress(),
            icon: const Icon(Icons.cloud_upload_outlined),
          ),
        ],
      ),
      drawer: controller == null
          ? null
          : Drawer(
              child: SafeArea(
                child: EpubViewTableOfContents(
                  controller: controller,
                  itemBuilder: (context, index, chapter, itemCount) {
                    final bool isSubchapter = chapter.type == "subchapter";
                    final String title = (chapter.title ?? "").trim();
                    return ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.only(
                        left: isSubchapter ? 28 : 16,
                        right: 12,
                      ),
                      title: Text(
                        title.isEmpty ? "Chapter ${index + 1}" : title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      onTap: () => unawaited(_handleTocTap(chapter)),
                    );
                  },
                ),
              ),
            ),
      body: Column(
        children: <Widget>[
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : (_error != null)
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        "Could not open EPUB\n$_error",
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: AppTheme.accent),
                      ),
                    ),
                  )
                : EpubView(
                    controller: controller!,
                    onChapterChanged: (_) => _scheduleProgressSave(),
                    builders: EpubViewBuilders<DefaultBuilderOptions>(
                      options: const DefaultBuilderOptions(
                        textStyle: TextStyle(
                          fontSize: 30,
                          color: Colors.white,
                          height: 1.8,
                          fontFamily: "Georgia",
                        ),
                      ),
                    ),
                  ),
          ),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: AppTheme.divider)),
            ),
            child: const Text(
              "Reading progress is saved locally and synced to Drive.",
              style: TextStyle(fontSize: 12, color: AppTheme.muted),
            ),
          ),
        ],
      ),
    );

    final Widget wrappedScaffold = _useKeyboardTocShortcut
        ? CallbackShortcuts(
            bindings: <ShortcutActivator, VoidCallback>{
              const SingleActivator(LogicalKeyboardKey.keyT): _openTocDrawer,
            },
            child: Focus(autofocus: true, child: scaffold),
          )
        : scaffold;

    return PopScope<void>(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) {
          return;
        }
        unawaited(_closeReader());
      },
      child: wrappedScaffold,
    );
  }
}

class _ReaderProgressSnapshot {
  const _ReaderProgressSnapshot({
    required this.cfi,
    required this.chapter,
    required this.percent,
    required this.locatorJson,
  });

  final String cfi;
  final int? chapter;
  final double? percent;
  final String locatorJson;
}
