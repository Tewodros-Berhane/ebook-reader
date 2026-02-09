import "package:shared_preferences/shared_preferences.dart";

class WindowStateService {
  const WindowStateService();

  static const String _widthKey = "window.width";
  static const String _heightKey = "window.height";

  Future<({double width, double height})?> loadWindowSize() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final double? width = prefs.getDouble(_widthKey);
    final double? height = prefs.getDouble(_heightKey);
    if (width == null || height == null) {
      return null;
    }
    return (width: width, height: height);
  }

  Future<void> saveWindowSize({
    required double width,
    required double height,
  }) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_widthKey, width);
    await prefs.setDouble(_heightKey, height);
  }
}
