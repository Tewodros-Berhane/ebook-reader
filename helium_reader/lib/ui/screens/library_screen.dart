import "dart:async";

import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

import "../../app/providers.dart";
import "../../core/theme/app_theme.dart";
import "../../data/models/book_record.dart";
import "../../data/services/drive_service.dart";
import "../../state/auth_state.dart";
import "../../state/library_state.dart";
import "../widgets/book_grid_card.dart";
import "reader_screen.dart";
import "settings_screen.dart";

class LibraryScreen extends ConsumerStatefulWidget {
  const LibraryScreen({super.key});

  @override
  ConsumerState<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends ConsumerState<LibraryScreen>
    with WidgetsBindingObserver {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  String? _accessToken;
  String? _openingFileId;
  bool _folderPickerBusy = false;
  bool _autoSyncInFlight = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final AuthState auth = ref.read(authControllerProvider);
      ref
          .read(libraryControllerProvider.notifier)
          .loadInitial(signedIn: auth.status == AuthStatus.signedIn);
      _loadToken();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_autoSyncIfSignedIn());
    }
  }

  Future<void> _loadToken() async {
    final String? token = await ref
        .read(authServiceProvider)
        .accessToken(promptIfNecessary: false);
    if (!mounted) {
      return;
    }
    setState(() {
      _accessToken = token;
    });
  }

  Future<void> _refreshLibrary({bool silentSync = false}) async {
    await ref.read(libraryControllerProvider.notifier).refreshFromDrive();
    await ref
        .read(libraryControllerProvider.notifier)
        .syncProgress(silent: silentSync);
    await _loadToken();
  }

  Future<void> _autoSyncIfSignedIn() async {
    if (_autoSyncInFlight) {
      return;
    }

    final AuthState auth = ref.read(authControllerProvider);
    if (auth.status != AuthStatus.signedIn) {
      return;
    }

    _autoSyncInFlight = true;
    try {
      await ref
          .read(libraryControllerProvider.notifier)
          .syncProgress(silent: true);
      await _loadToken();
    } finally {
      _autoSyncInFlight = false;
    }
  }

  Future<void> _waitForSyncIdle({
    Duration timeout = const Duration(seconds: 8),
  }) async {
    final DateTime deadline = DateTime.now().add(timeout);
    while (ref.read(libraryControllerProvider).syncing &&
        DateTime.now().isBefore(deadline)) {
      await Future<void>.delayed(const Duration(milliseconds: 140));
    }
  }

  Future<void> _syncBeforeOpenIfSignedIn() async {
    final AuthState auth = ref.read(authControllerProvider);
    if (auth.status != AuthStatus.signedIn) {
      return;
    }

    await _waitForSyncIdle();
    await ref
        .read(libraryControllerProvider.notifier)
        .syncProgress(silent: true);
    await _waitForSyncIdle();
  }

  Future<void> _pickFolder() async {
    final AuthState authState = ref.read(authControllerProvider);
    if (authState.status != AuthStatus.signedIn) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Folder picker requires an active Google session."),
        ),
      );
      return;
    }

    setState(() {
      _folderPickerBusy = true;
    });

    try {
      final List<DriveFolder> folders = await ref
          .read(libraryControllerProvider.notifier)
          .folderOptions();
      if (!mounted) {
        return;
      }

      final String? pickedFolderId = await showModalBottomSheet<String>(
        context: context,
        showDragHandle: true,
        backgroundColor: const Color(0xFF2B2B2B),
        builder: (context) {
          return SafeArea(
            child: ListView(
              children: <Widget>[
                const ListTile(
                  title: Text(
                    "Choose Drive folder",
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    "Only EPUB files from this folder will be listed.",
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.public_rounded),
                  title: const Text("All Drive files"),
                  onTap: () => Navigator.of(context).pop("__all__"),
                ),
                const Divider(height: 1),
                ...folders.map((folder) {
                  return ListTile(
                    leading: const Icon(Icons.folder_rounded),
                    title: Text(folder.name),
                    onTap: () => Navigator.of(context).pop(folder.id),
                  );
                }),
                if (folders.isEmpty)
                  const ListTile(
                    title: Text("No folders found"),
                    subtitle: Text(
                      "Your Drive may not contain folder entries.",
                    ),
                  ),
              ],
            ),
          );
        },
      );

      if (!mounted || pickedFolderId == null) {
        return;
      }

      if (pickedFolderId == "__all__") {
        await ref.read(libraryControllerProvider.notifier).selectFolder(null);
      } else {
        final DriveFolder folder = folders.firstWhere(
          (f) => f.id == pickedFolderId,
        );
        await ref.read(libraryControllerProvider.notifier).selectFolder(folder);
      }

      await ref
          .read(libraryControllerProvider.notifier)
          .syncProgress(silent: true);
      await _loadToken();
    } catch (err) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Could not load folders: $err")));
    } finally {
      if (mounted) {
        setState(() {
          _folderPickerBusy = false;
        });
      }
    }
  }

  Future<void> _openBook(BookRecord book) async {
    setState(() {
      _openingFileId = book.fileId;
    });

    try {
      await _syncBeforeOpenIfSignedIn();

      final BookRecord ready = await ref
          .read(libraryControllerProvider.notifier)
          .prepareForReading(book.fileId);
      if (!mounted) {
        return;
      }
      await Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => ReaderScreen(book: ready)),
      );

      await _autoSyncIfSignedIn();
    } catch (err) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Could not open book: $err")));
    } finally {
      if (mounted) {
        setState(() {
          _openingFileId = null;
        });
      }
    }
  }

  SliverGridDelegate _gridDelegate(double maxWidth) {
    final int crossAxisCount = ((maxWidth - 20) / 175).floor().clamp(2, 6);

    return SliverGridDelegateWithFixedCrossAxisCount(
      crossAxisCount: crossAxisCount,
      childAspectRatio: 0.66,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
    );
  }

  @override
  Widget build(BuildContext context) {
    final AuthState authState = ref.watch(authControllerProvider);
    final LibraryState libraryState = ref.watch(libraryControllerProvider);
    final bool canPickFolder = authState.status == AuthStatus.signedIn;

    return Scaffold(
      key: _scaffoldKey,
      drawer: Drawer(
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              const Padding(
                padding: EdgeInsets.fromLTRB(18, 14, 18, 16),
                child: Text(
                  "Helium",
                  style: TextStyle(fontSize: 36, fontWeight: FontWeight.w600),
                ),
              ),
              _drawerTile(
                icon: Icons.bookmark_rounded,
                title: "My books",
                onTap: () => Navigator.of(context).pop(),
              ),
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 10),
                child: Text(
                  "Categories",
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(color: AppTheme.muted),
                ),
              ),
              _drawerTile(
                icon: Icons.add,
                title: "Create category",
                onTap: () => Navigator.of(context).pop(),
              ),
              const Divider(height: 1),
              _drawerTile(
                icon: Icons.settings,
                title: "Settings",
                onTap: () async {
                  Navigator.of(context).pop();
                  await Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const SettingsScreen(),
                    ),
                  );
                },
              ),
              _drawerTile(
                icon: Icons.feedback_outlined,
                title: "Send feedback",
                onTap: () => Navigator.of(context).pop(),
              ),
              const Spacer(),
              _drawerTile(
                icon: Icons.logout_rounded,
                title: "Sign out",
                onTap: () async {
                  Navigator.of(context).pop();
                  await ref.read(authControllerProvider.notifier).signOut();
                },
              ),
            ],
          ),
        ),
      ),
      appBar: AppBar(
        leading: IconButton(
          onPressed: () => _scaffoldKey.currentState?.openDrawer(),
          icon: const Icon(Icons.menu_rounded),
        ),
        title: const Text("My books"),
        actions: <Widget>[
          IconButton(onPressed: () {}, icon: const Icon(Icons.search_rounded)),
          PopupMenuButton<String>(
            itemBuilder: (context) => <PopupMenuEntry<String>>[
              const PopupMenuItem<String>(
                value: "refresh",
                child: Text("Sync now"),
              ),
              const PopupMenuItem<String>(
                value: "folder",
                child: Text("Pick folder"),
              ),
              const PopupMenuItem<String>(
                value: "settings",
                child: Text("Settings"),
              ),
            ],
            onSelected: (value) async {
              if (value == "refresh") {
                await _refreshLibrary();
              } else if (value == "folder") {
                await _pickFolder();
              } else if (value == "settings" && mounted) {
                await Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const SettingsScreen(),
                  ),
                );
              }
            },
          ),
        ],
      ),
      body: Column(
        children: <Widget>[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: AppTheme.divider)),
            ),
            child: Row(
              children: <Widget>[
                const Icon(
                  Icons.folder_rounded,
                  size: 18,
                  color: AppTheme.muted,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    libraryState.selectedFolderName == null ||
                            libraryState.selectedFolderName!.isEmpty
                        ? "All Drive files"
                        : libraryState.selectedFolderName!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: AppTheme.muted),
                  ),
                ),
                TextButton.icon(
                  onPressed: (_folderPickerBusy || !canPickFolder)
                      ? null
                      : _pickFolder,
                  icon: _folderPickerBusy
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.swap_horiz_rounded, size: 18),
                  label: const Text("Change"),
                ),
              ],
            ),
          ),
          if (libraryState.loading || libraryState.syncing)
            const LinearProgressIndicator(minHeight: 2),
          if (libraryState.syncing)
            const Padding(
              padding: EdgeInsets.only(top: 6),
              child: Text(
                "Syncing...",
                style: TextStyle(fontSize: 12, color: AppTheme.muted),
              ),
            ),
          if (authState.status == AuthStatus.offline)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(
                "Offline mode: Drive sync will resume when login is available.",
                style: TextStyle(fontSize: 12, color: AppTheme.muted),
              ),
            ),
          if (libraryState.error != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  libraryState.error!,
                  style: const TextStyle(color: AppTheme.accent),
                ),
              ),
            ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => _refreshLibrary(silentSync: true),
              child: libraryState.books.isEmpty
                  ? ListView(
                      children: const <Widget>[
                        SizedBox(height: 160),
                        Center(
                          child: Text(
                            "No books yet. Sync to load EPUBs from Drive.",
                            style: TextStyle(color: AppTheme.muted),
                          ),
                        ),
                      ],
                    )
                  : LayoutBuilder(
                      builder: (context, constraints) {
                        return GridView.builder(
                          padding: const EdgeInsets.fromLTRB(12, 12, 12, 16),
                          gridDelegate: _gridDelegate(constraints.maxWidth),
                          itemCount: libraryState.books.length,
                          itemBuilder: (context, index) {
                            final BookRecord book = libraryState.books[index];
                            return Stack(
                              children: <Widget>[
                                Positioned.fill(
                                  child: BookGridCard(
                                    book: book,
                                    accessToken: _accessToken,
                                    onTap: () => _openBook(book),
                                  ),
                                ),
                                if (_openingFileId == book.fileId)
                                  Positioned.fill(
                                    child: DecoratedBox(
                                      decoration: BoxDecoration(
                                        color: Colors.black.withValues(
                                          alpha: 0.45,
                                        ),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: const Center(
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            );
                          },
                        );
                      },
                    ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.small(
        onPressed: () => _refreshLibrary(),
        child: const Icon(Icons.sync),
      ),
    );
  }

  Widget _drawerTile({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon, size: 24),
      title: Text(title, style: const TextStyle(fontSize: 14)),
      onTap: onTap,
    );
  }
}
