import "package:flutter_riverpod/flutter_riverpod.dart";

import "../data/db/app_database.dart";
import "../data/services/auth_service.dart";
import "../data/services/drive_service.dart";
import "../data/services/file_service.dart";
import "../data/services/library_service.dart";
import "../data/services/mysql_progress_service.dart";
import "../data/services/sync_service.dart";
import "../data/services/window_state_service.dart";
import "../state/auth_controller.dart";
import "../state/auth_state.dart";
import "../state/library_controller.dart";
import "../state/library_state.dart";
import "../state/settings_controller.dart";
import "../state/settings_state.dart";

final Provider<AppDatabase> appDatabaseProvider = Provider<AppDatabase>((ref) {
  return AppDatabase.instance;
});

final Provider<AuthService> authServiceProvider = Provider<AuthService>((ref) {
  return AuthService();
});

final Provider<FileService> fileServiceProvider = Provider<FileService>((ref) {
  return const FileService();
});

final Provider<DriveService> driveServiceProvider = Provider<DriveService>((
  ref,
) {
  final AuthService authService = ref.watch(authServiceProvider);
  return DriveService(authService);
});

final Provider<LibraryService> libraryServiceProvider =
    Provider<LibraryService>((ref) {
      final AppDatabase database = ref.watch(appDatabaseProvider);
      final DriveService driveService = ref.watch(driveServiceProvider);
      final FileService fileService = ref.watch(fileServiceProvider);
      return LibraryService(
        database: database,
        driveService: driveService,
        fileService: fileService,
      );
    });

final Provider<MySqlProgressService> mySqlProgressServiceProvider =
    Provider<MySqlProgressService>((ref) {
      return MySqlProgressService();
    });

final Provider<SyncService> syncServiceProvider = Provider<SyncService>((ref) {
  final LibraryService libraryService = ref.watch(libraryServiceProvider);
  final MySqlProgressService mySqlProgressService = ref.watch(
    mySqlProgressServiceProvider,
  );
  final AuthService authService = ref.watch(authServiceProvider);

  return SyncService(
    libraryService: libraryService,
    mySqlProgressService: mySqlProgressService,
    authService: authService,
  );
});

final Provider<WindowStateService> windowStateServiceProvider =
    Provider<WindowStateService>((ref) {
      return const WindowStateService();
    });

final StateNotifierProvider<AuthController, AuthState> authControllerProvider =
    StateNotifierProvider<AuthController, AuthState>((ref) {
      final AuthService authService = ref.watch(authServiceProvider);
      final LibraryService libraryService = ref.watch(libraryServiceProvider);
      return AuthController(
        authService: authService,
        libraryService: libraryService,
      );
    });

final StateNotifierProvider<LibraryController, LibraryState>
libraryControllerProvider =
    StateNotifierProvider<LibraryController, LibraryState>((ref) {
      final LibraryService libraryService = ref.watch(libraryServiceProvider);
      final SyncService syncService = ref.watch(syncServiceProvider);
      return LibraryController(
        libraryService: libraryService,
        syncService: syncService,
      );
    });

final StateNotifierProvider<SettingsController, SettingsState>
settingsControllerProvider =
    StateNotifierProvider<SettingsController, SettingsState>((ref) {
      return SettingsController();
    });
