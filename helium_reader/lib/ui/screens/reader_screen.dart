import "dart:async";
import "dart:io";

import "package:epub_view/epub_view.dart";
import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

import "../../app/providers.dart";
import "../../core/theme/app_theme.dart";
import "../../data/models/book_record.dart";

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
  String? _lastPersistedCfi;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initialize();
  }

  Future<void> _initialize() async {
    try {
      final BookRecord ready = await ref
          .read(libraryControllerProvider.notifier)
          .prepareForReading(widget.book.fileId);
      final EpubController controller = EpubController(
        document: EpubDocument.openFile(File(ready.localPath)),
        epubCfi: ready.lastCfi.isEmpty ? null : ready.lastCfi,
      );

      _lastPersistedCfi = ready.lastCfi.isEmpty ? null : ready.lastCfi;
      controller.currentValueListenable.addListener(_onPositionChanged);
      _periodicCheckpoint = Timer.periodic(
        const Duration(seconds: 2),
        (_) => _scheduleProgressSave(),
      );

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

  void _onPositionChanged() {
    _scheduleProgressSave();
  }

  void _scheduleProgressSave() {
    _progressDebounce?.cancel();
    _progressDebounce = Timer(const Duration(milliseconds: 450), () async {
      await _persistProgress(sync: false);
    });
  }

  Future<void> _persistProgress({
    String? cfi,
    bool sync = false,
    bool forceWrite = false,
  }) async {
    final BookRecord? book = _book;
    if (book == null) {
      return;
    }

    final String? resolvedCfi = cfi ?? _epubController?.generateEpubCfi();
    if (resolvedCfi == null || resolvedCfi.isEmpty) {
      return;
    }

    if (!forceWrite && resolvedCfi == _lastPersistedCfi) {
      if (sync) {
        await ref
            .read(libraryControllerProvider.notifier)
            .syncProgress(silent: true);
      }
      return;
    }

    await ref
        .read(libraryControllerProvider.notifier)
        .saveProgress(fileId: book.fileId, cfi: resolvedCfi);

    _lastPersistedCfi = resolvedCfi;

    if (sync) {
      await ref
          .read(libraryControllerProvider.notifier)
          .syncProgress(silent: true);
    }
  }

  Future<void> _syncBeforeExit([String? cfi]) async {
    try {
      await _persistProgress(cfi: cfi, sync: true, forceWrite: true);
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

    await _syncBeforeExit(_epubController?.generateEpubCfi());

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
      final String? cfi = _epubController?.generateEpubCfi();
      unawaited(_syncBeforeExit(cfi));
    }
  }

  @override
  void dispose() {
    final String? cfi = _epubController?.generateEpubCfi();

    _progressDebounce?.cancel();
    _periodicCheckpoint?.cancel();
    WidgetsBinding.instance.removeObserver(this);

    final EpubController? controller = _epubController;
    if (controller != null) {
      controller.currentValueListenable.removeListener(_onPositionChanged);
    }

    _epubController?.dispose();
    unawaited(_syncBeforeExit(cfi));

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final EpubController? controller = _epubController;

    return PopScope<void>(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) {
          return;
        }
        unawaited(_closeReader());
      },
      child: Scaffold(
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
          title: controller == null
              ? Text(widget.book.title)
              : EpubViewActualChapter(
                  controller: controller,
                  builder: (chapter) {
                    return Text(
                      chapter?.chapter?.Title?.replaceAll("\n", " ").trim() ??
                          widget.book.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    );
                  },
                ),
          actions: <Widget>[
            if (controller != null)
              IconButton(
                tooltip: "Table of contents",
                onPressed: () => _scaffoldKey.currentState?.openDrawer(),
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
                  child: EpubViewTableOfContents(controller: controller),
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
      ),
    );
  }
}
