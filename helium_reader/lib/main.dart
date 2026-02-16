import "dart:io";

import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:window_manager/window_manager.dart";
import "package:workmanager/workmanager.dart";

import "app/helium_app.dart";
import "core/config/app_config.dart";
import "data/db/app_database.dart";
import "data/services/auth_service.dart";
import "data/services/drive_service.dart";
import "data/services/file_service.dart";
import "data/services/library_service.dart";
import "data/services/mysql_progress_service.dart";
import "data/services/sync_service.dart";
import "data/services/window_state_service.dart";

@pragma("vm:entry-point")
void backgroundSyncDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    WidgetsFlutterBinding.ensureInitialized();

    try {
      await AppDatabase.instance.initialize();
      final AuthService authService = AuthService();
      await authService.initialize();
      await authService.signInSilently();

      final DriveService driveService = DriveService(authService);
      final LibraryService libraryService = LibraryService(
        database: AppDatabase.instance,
        driveService: driveService,
        fileService: const FileService(),
      );
      final SyncService syncService = SyncService(
        libraryService: libraryService,
        mySqlProgressService: MySqlProgressService(),
        authService: authService,
      );

      return syncService.backgroundSyncAttempt(deviceName: "Mobile-Background");
    } catch (_) {
      return false;
    }
  });
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await _bootstrap();
  runApp(const ProviderScope(child: HeliumApp()));
}

Future<void> _bootstrap() async {
  await AppDatabase.instance.initialize();

  if (Platform.isAndroid || Platform.isIOS) {
    await Workmanager().initialize(backgroundSyncDispatcher);

    try {
      await Workmanager().registerPeriodicTask(
        "helium-dirty-sync",
        "sync_dirty_progress",
        frequency: const Duration(hours: 1),
        constraints: Constraints(networkType: NetworkType.connected),
      );
    } catch (_) {
      // task may already be registered
    }
  }

  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    await windowManager.ensureInitialized();
    final WindowStateService windowStateService = const WindowStateService();
    final ({double width, double height})? size = await windowStateService
        .loadWindowSize();

    final WindowOptions options = WindowOptions(
      size: Size(size?.width ?? 1200, size?.height ?? 780),
      minimumSize: const Size(980, 620),
      center: true,
      title: AppConfig.appName,
      backgroundColor: const Color(0xFF212121),
    );

    await windowManager.waitUntilReadyToShow(options, () async {
      await windowManager.show();
      await windowManager.focus();
    });
  }
}
