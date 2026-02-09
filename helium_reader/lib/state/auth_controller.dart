import "dart:async";

import "package:flutter/services.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:google_sign_in/google_sign_in.dart";

import "../data/models/auth_profile.dart";
import "../data/services/auth_service.dart";
import "../data/services/library_service.dart";
import "auth_state.dart";

class AuthController extends StateNotifier<AuthState> {
  AuthController({
    required AuthService authService,
    required LibraryService libraryService,
  }) : _authService = authService,
       _libraryService = libraryService,
       super(AuthState.loading) {
    bootstrap();
  }

  final AuthService _authService;
  final LibraryService _libraryService;

  Future<void> bootstrap() async {
    state = AuthState.loading;
    try {
      await _authService.initialize();
      final AuthProfile? profile = await _authService.signInSilently();

      if (profile != null) {
        await _authService.accessToken(promptIfNecessary: false);
        state = AuthState(
          status: AuthStatus.signedIn,
          email: profile.email,
          displayName: profile.displayName,
          photoUrl: profile.photoUrl,
          error: null,
        );
        return;
      }

      final bool hasDownloads = await _libraryService.hasDownloadedBooks();
      final AuthProfile? cachedProfile = await _authService.cachedProfile();
      if (hasDownloads) {
        state = AuthState(
          status: AuthStatus.offline,
          email: cachedProfile?.email ?? "",
          displayName: cachedProfile?.displayName ?? "Offline mode",
          photoUrl: cachedProfile?.photoUrl ?? "",
          error: null,
        );
      } else {
        state = AuthState(
          status: AuthStatus.signedOut,
          email: cachedProfile?.email ?? "",
          displayName: cachedProfile?.displayName ?? "",
          photoUrl: cachedProfile?.photoUrl ?? "",
          error: null,
        );
      }
    } catch (err) {
      final bool hasDownloads = await _libraryService.hasDownloadedBooks();
      if (hasDownloads) {
        state = AuthState(
          status: AuthStatus.offline,
          email: state.email,
          displayName: state.displayName,
          photoUrl: state.photoUrl,
          error: null,
        );
        return;
      }

      state = AuthState(
        status: AuthStatus.signedOut,
        email: "",
        displayName: "",
        photoUrl: "",
        error: _friendlyError(err),
      );
    }
  }

  Future<void> signIn() async {
    state = state.copyWith(status: AuthStatus.loading, error: null);
    try {
      final AuthProfile profile = await _authService.signInInteractive();
      await _authService.accessToken(promptIfNecessary: true);

      state = AuthState(
        status: AuthStatus.signedIn,
        email: profile.email,
        displayName: profile.displayName,
        photoUrl: profile.photoUrl,
        error: null,
      );
    } catch (err) {
      state = AuthState(
        status: AuthStatus.signedOut,
        email: state.email,
        displayName: state.displayName,
        photoUrl: state.photoUrl,
        error: _friendlyError(err),
      );
    }
  }

  Future<void> signOut() async {
    await _authService.signOut();
    state = const AuthState(
      status: AuthStatus.signedOut,
      email: "",
      displayName: "",
      photoUrl: "",
      error: null,
    );
  }

  String _friendlyError(Object err) {
    if (err is GoogleSignInException) {
      return "Sign-in failed (${err.code.name}).";
    }

    if (err is MissingPluginException) {
      return "Google Sign-In plugin is not available on this platform.";
    }

    if (err is StateError ||
        err is UnsupportedError ||
        err is TimeoutException) {
      final String text = err.toString();
      final int idx = text.indexOf(": ");
      return idx >= 0 ? text.substring(idx + 2) : text;
    }

    final String text = err.toString();
    if (text.isEmpty || text == "null") {
      return "Authentication failed.";
    }

    return text.startsWith("Exception: ")
        ? text.replaceFirst("Exception: ", "")
        : text;
  }
}
