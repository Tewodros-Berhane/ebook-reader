import "dart:io";

import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:window_manager/window_manager.dart";

import "../core/config/app_config.dart";
import "../core/theme/app_theme.dart";
import "../data/services/window_state_service.dart";
import "providers.dart";
import "root_gate.dart";

class HeliumApp extends ConsumerStatefulWidget {
  const HeliumApp({super.key});

  @override
  ConsumerState<HeliumApp> createState() => _HeliumAppState();
}

class _HeliumAppState extends ConsumerState<HeliumApp> with WindowListener {
  @override
  void initState() {
    super.initState();
    if (_isDesktop) {
      windowManager.addListener(this);
    }
  }

  @override
  void dispose() {
    if (_isDesktop) {
      windowManager.removeListener(this);
    }
    super.dispose();
  }

  @override
  Future<void> onWindowResize() async {
    if (!_isDesktop) {
      return;
    }
    final Rect bounds = await windowManager.getBounds();
    final WindowStateService service = ref.read(windowStateServiceProvider);
    await service.saveWindowSize(width: bounds.width, height: bounds.height);
  }

  bool get _isDesktop =>
      Platform.isWindows || Platform.isLinux || Platform.isMacOS;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppConfig.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark(),
      home: const RootGate(),
    );
  }
}
