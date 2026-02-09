import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:shared_preferences/shared_preferences.dart";

import "settings_state.dart";

class SettingsController extends StateNotifier<SettingsState> {
  SettingsController() : super(SettingsState.defaults) {
    _load();
  }

  static const String _keepScreenOn = "settings.keepScreenOn";
  static const String _fullscreenReading = "settings.fullscreenReading";
  static const String _confirmWebLinks = "settings.confirmWebLinks";
  static const String _tapTurnPages = "settings.tapTurnPages";
  static const String _disableDrawerSwipe = "settings.disableDrawerSwipe";
  static const String _openLastBookOnLaunch = "settings.openLastBookOnLaunch";
  static const String _showFolderListInDrawer =
      "settings.showFolderListInDrawer";
  static const String _bookWideIndicator = "settings.bookWideIndicator";
  static const String _syncOnWifiOnly = "settings.syncOnWifiOnly";

  Future<void> _load() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    state = state.copyWith(
      keepScreenOn: prefs.getBool(_keepScreenOn) ?? state.keepScreenOn,
      fullscreenReading:
          prefs.getBool(_fullscreenReading) ?? state.fullscreenReading,
      confirmWebLinks: prefs.getBool(_confirmWebLinks) ?? state.confirmWebLinks,
      tapTurnPages: prefs.getBool(_tapTurnPages) ?? state.tapTurnPages,
      disableDrawerSwipe:
          prefs.getBool(_disableDrawerSwipe) ?? state.disableDrawerSwipe,
      openLastBookOnLaunch:
          prefs.getBool(_openLastBookOnLaunch) ?? state.openLastBookOnLaunch,
      showFolderListInDrawer:
          prefs.getBool(_showFolderListInDrawer) ??
          state.showFolderListInDrawer,
      bookWideIndicator:
          prefs.getBool(_bookWideIndicator) ?? state.bookWideIndicator,
      syncOnWifiOnly: prefs.getBool(_syncOnWifiOnly) ?? state.syncOnWifiOnly,
    );
  }

  Future<void> setKeepScreenOn(bool value) =>
      _setBool(_keepScreenOn, value, (s) => s.copyWith(keepScreenOn: value));
  Future<void> setFullscreenReading(bool value) => _setBool(
    _fullscreenReading,
    value,
    (s) => s.copyWith(fullscreenReading: value),
  );
  Future<void> setConfirmWebLinks(bool value) => _setBool(
    _confirmWebLinks,
    value,
    (s) => s.copyWith(confirmWebLinks: value),
  );
  Future<void> setTapTurnPages(bool value) =>
      _setBool(_tapTurnPages, value, (s) => s.copyWith(tapTurnPages: value));
  Future<void> setDisableDrawerSwipe(bool value) => _setBool(
    _disableDrawerSwipe,
    value,
    (s) => s.copyWith(disableDrawerSwipe: value),
  );
  Future<void> setOpenLastBookOnLaunch(bool value) => _setBool(
    _openLastBookOnLaunch,
    value,
    (s) => s.copyWith(openLastBookOnLaunch: value),
  );
  Future<void> setShowFolderListInDrawer(bool value) => _setBool(
    _showFolderListInDrawer,
    value,
    (s) => s.copyWith(showFolderListInDrawer: value),
  );
  Future<void> setBookWideIndicator(bool value) => _setBool(
    _bookWideIndicator,
    value,
    (s) => s.copyWith(bookWideIndicator: value),
  );
  Future<void> setSyncOnWifiOnly(bool value) => _setBool(
    _syncOnWifiOnly,
    value,
    (s) => s.copyWith(syncOnWifiOnly: value),
  );

  Future<void> _setBool(
    String key,
    bool value,
    SettingsState Function(SettingsState) mapper,
  ) async {
    state = mapper(state);
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);
  }
}
