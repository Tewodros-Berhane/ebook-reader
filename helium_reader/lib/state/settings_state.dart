class SettingsState {
  const SettingsState({
    required this.keepScreenOn,
    required this.fullscreenReading,
    required this.confirmWebLinks,
    required this.tapTurnPages,
    required this.disableDrawerSwipe,
    required this.openLastBookOnLaunch,
    required this.showFolderListInDrawer,
    required this.bookWideIndicator,
    required this.syncOnWifiOnly,
  });

  final bool keepScreenOn;
  final bool fullscreenReading;
  final bool confirmWebLinks;
  final bool tapTurnPages;
  final bool disableDrawerSwipe;
  final bool openLastBookOnLaunch;
  final bool showFolderListInDrawer;
  final bool bookWideIndicator;
  final bool syncOnWifiOnly;

  SettingsState copyWith({
    bool? keepScreenOn,
    bool? fullscreenReading,
    bool? confirmWebLinks,
    bool? tapTurnPages,
    bool? disableDrawerSwipe,
    bool? openLastBookOnLaunch,
    bool? showFolderListInDrawer,
    bool? bookWideIndicator,
    bool? syncOnWifiOnly,
  }) {
    return SettingsState(
      keepScreenOn: keepScreenOn ?? this.keepScreenOn,
      fullscreenReading: fullscreenReading ?? this.fullscreenReading,
      confirmWebLinks: confirmWebLinks ?? this.confirmWebLinks,
      tapTurnPages: tapTurnPages ?? this.tapTurnPages,
      disableDrawerSwipe: disableDrawerSwipe ?? this.disableDrawerSwipe,
      openLastBookOnLaunch: openLastBookOnLaunch ?? this.openLastBookOnLaunch,
      showFolderListInDrawer:
          showFolderListInDrawer ?? this.showFolderListInDrawer,
      bookWideIndicator: bookWideIndicator ?? this.bookWideIndicator,
      syncOnWifiOnly: syncOnWifiOnly ?? this.syncOnWifiOnly,
    );
  }

  static const SettingsState defaults = SettingsState(
    keepScreenOn: true,
    fullscreenReading: true,
    confirmWebLinks: true,
    tapTurnPages: false,
    disableDrawerSwipe: false,
    openLastBookOnLaunch: true,
    showFolderListInDrawer: false,
    bookWideIndicator: true,
    syncOnWifiOnly: false,
  );
}
