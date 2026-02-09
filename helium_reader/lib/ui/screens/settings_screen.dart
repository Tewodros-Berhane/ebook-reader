import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

import "../../app/providers.dart";
import "../../core/theme/app_theme.dart";

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsControllerProvider);
    final controller = ref.read(settingsControllerProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: const Text("Settings")),
      body: ListView(
        children: <Widget>[
          _switchTile(
            title: "Keep screen on",
            value: settings.keepScreenOn,
            onChanged: controller.setKeepScreenOn,
          ),
          _switchTile(
            title: "Fullscreen reading",
            value: settings.fullscreenReading,
            onChanged: controller.setFullscreenReading,
          ),
          const _ValueTile(title: "App theme", subtitle: "System default"),
          _switchTile(
            title: "Sync",
            subtitle: settings.syncOnWifiOnly ? "Wi-Fi only" : "Off",
            value: settings.syncOnWifiOnly,
            onChanged: controller.setSyncOnWifiOnly,
          ),
          const _SectionLabel("Navigation"),
          _switchTile(
            title: "Tap left/right to turn pages",
            value: settings.tapTurnPages,
            onChanged: controller.setTapTurnPages,
          ),
          _switchTile(
            title: "Confirm when opening web links",
            value: settings.confirmWebLinks,
            onChanged: controller.setConfirmWebLinks,
          ),
          const _SectionLabel("Accessibility"),
          _switchTile(
            title: "Disable drawer swipe while reading",
            value: settings.disableDrawerSwipe,
            onChanged: controller.setDisableDrawerSwipe,
          ),
          _switchTile(
            title: "Open last book on launch",
            value: settings.openLastBookOnLaunch,
            onChanged: controller.setOpenLastBookOnLaunch,
          ),
          const _SectionLabel("Advanced"),
          const _ValueTile(
            title: "Library folder",
            subtitle: "Managed automatically",
          ),
          _switchTile(
            title: "Show folder list in drawer",
            value: settings.showFolderListInDrawer,
            onChanged: controller.setShowFolderListInDrawer,
          ),
          _switchTile(
            title: "Use book-wide page indicator",
            value: settings.bookWideIndicator,
            onChanged: controller.setBookWideIndicator,
          ),
          const _SectionLabel("About"),
          const _ValueTile(title: "App version", subtitle: "0.1.0"),
          ListTile(
            title: const Text("Privacy policy"),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {},
          ),
          ListTile(
            title: const Text("Licenses & attribution"),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              showLicensePage(context: context);
            },
          ),
          const SizedBox(height: 14),
        ],
      ),
    );
  }

  Widget _switchTile({
    required String title,
    String? subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return SwitchListTile.adaptive(
      title: Text(title),
      subtitle: subtitle == null
          ? null
          : Text(subtitle, style: const TextStyle(color: AppTheme.muted)),
      value: value,
      onChanged: onChanged,
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
      child: Text(
        title,
        style: const TextStyle(
          color: AppTheme.accent,
          fontSize: 28 / 2,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

class _ValueTile extends StatelessWidget {
  const _ValueTile({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(title),
      subtitle: Text(subtitle, style: const TextStyle(color: AppTheme.muted)),
    );
  }
}
