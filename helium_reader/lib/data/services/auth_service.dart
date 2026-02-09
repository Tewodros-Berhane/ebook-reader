import "dart:async";
import "dart:convert";
import "dart:io";
import "dart:math";

import "package:flutter/foundation.dart";
import "package:flutter_secure_storage/flutter_secure_storage.dart";
import "package:google_sign_in/google_sign_in.dart";
import "package:http/http.dart" as http;

import "../../core/config/app_config.dart";
import "../../core/config/drive_scopes.dart";
import "../models/auth_profile.dart";

class AuthService {
  AuthService({FlutterSecureStorage? storage, http.Client? httpClient})
    : _storage = storage ?? const FlutterSecureStorage(),
      _httpClient = httpClient ?? http.Client(),
      _signIn = GoogleSignIn.instance;

  static const String _tokenKey = "auth.access_token";
  static const String _refreshTokenKey = "auth.refresh_token";
  static const String _tokenExpiryKey = "auth.token_expiry";
  static const String _profileKey = "auth.profile";

  static const Duration _desktopAuthTimeout = Duration(minutes: 3);
  static const Duration _tokenExpirySkew = Duration(minutes: 1);

  final FlutterSecureStorage _storage;
  final http.Client _httpClient;
  final GoogleSignIn _signIn;

  StreamSubscription<GoogleSignInAuthenticationEvent>? _eventSub;
  GoogleSignInAccount? _activeAccount;
  bool _initialized = false;

  bool get _useDesktopOAuth => !kIsWeb && Platform.isWindows;

  Future<void> initialize() async {
    if (_initialized) {
      return;
    }

    if (_useDesktopOAuth) {
      _initialized = true;
      return;
    }

    await _signIn.initialize(
      clientId: AppConfig.googleClientId.isEmpty
          ? null
          : AppConfig.googleClientId,
      serverClientId: AppConfig.googleServerClientId.isEmpty
          ? null
          : AppConfig.googleServerClientId,
    );

    _eventSub = _signIn.authenticationEvents.listen((event) async {
      switch (event) {
        case GoogleSignInAuthenticationEventSignIn():
          _activeAccount = event.user;
          await _persistProfile(
            AuthProfile(
              email: event.user.email,
              displayName: event.user.displayName ?? "",
              photoUrl: event.user.photoUrl ?? "",
            ),
          );
        case GoogleSignInAuthenticationEventSignOut():
          _activeAccount = null;
      }
    });

    _initialized = true;
  }

  Future<AuthProfile?> signInSilently() async {
    await initialize();

    if (_useDesktopOAuth) {
      final bool hasToken = await _ensureDesktopAccessToken();
      if (!hasToken) {
        return null;
      }
      return cachedProfile();
    }

    final Future<GoogleSignInAccount?>? signInFuture = _signIn
        .attemptLightweightAuthentication();
    if (signInFuture == null) {
      return cachedProfile();
    }

    final GoogleSignInAccount? account = await signInFuture;
    if (account == null) {
      return cachedProfile();
    }

    _activeAccount = account;
    final AuthProfile profile = AuthProfile(
      email: account.email,
      displayName: account.displayName ?? "",
      photoUrl: account.photoUrl ?? "",
    );
    await _persistProfile(profile);
    return profile;
  }

  Future<AuthProfile> signInInteractive() async {
    await initialize();

    if (_useDesktopOAuth) {
      return _desktopSignInInteractive();
    }

    if (!_signIn.supportsAuthenticate()) {
      throw UnsupportedError("Interactive sign-in is unsupported here.");
    }

    final GoogleSignInAccount account = await _signIn.authenticate(
      scopeHint: DriveScopes.scopes,
    );
    _activeAccount = account;

    final AuthProfile profile = AuthProfile(
      email: account.email,
      displayName: account.displayName ?? "",
      photoUrl: account.photoUrl ?? "",
    );
    await _persistProfile(profile);
    return profile;
  }

  Future<void> signOut() async {
    if (!_useDesktopOAuth) {
      try {
        await _signIn.disconnect();
      } catch (_) {
        // Ignore platform plugin state mismatch.
      }
    }

    _activeAccount = null;
    await clearStoredAuth();
  }

  Future<Map<String, String>?> authorizationHeaders({
    bool promptIfNecessary = false,
  }) async {
    if (_useDesktopOAuth) {
      final String? token = await accessToken(
        promptIfNecessary: promptIfNecessary,
      );
      if (token == null || token.isEmpty) {
        return null;
      }
      return <String, String>{HttpHeaders.authorizationHeader: "Bearer $token"};
    }

    final GoogleSignInAccount? account = _activeAccount;
    if (account == null) {
      return null;
    }

    final Map<String, String>? headers = await account.authorizationClient
        .authorizationHeaders(
          DriveScopes.scopes,
          promptIfNecessary: promptIfNecessary,
        );

    if (headers != null) {
      final String? token = _extractAccessToken(headers);
      if (token != null) {
        await _storage.write(key: _tokenKey, value: token);
      }
    }

    return headers;
  }

  Future<String?> accessToken({bool promptIfNecessary = false}) async {
    if (_useDesktopOAuth) {
      return _desktopAccessToken(promptIfNecessary: promptIfNecessary);
    }

    final Map<String, String>? headers = await authorizationHeaders(
      promptIfNecessary: promptIfNecessary,
    );
    if (headers == null) {
      return _storage.read(key: _tokenKey);
    }
    return _extractAccessToken(headers);
  }

  Future<AuthProfile?> cachedProfile() async {
    final String? raw = await _storage.read(key: _profileKey);
    if (raw == null || raw.isEmpty) {
      return null;
    }

    final Object? decoded = jsonDecode(raw);
    if (decoded is! Map<String, Object?>) {
      if (decoded is! Map) {
        return null;
      }

      final Map<String, Object?> casted = <String, Object?>{};
      decoded.forEach((key, value) {
        if (key is String) {
          casted[key] = value;
        }
      });
      return AuthProfile.fromJson(casted);
    }

    return AuthProfile.fromJson(decoded);
  }

  Future<bool> hasCachedToken() async {
    final String? token = await _storage.read(key: _tokenKey);
    return token != null && token.isNotEmpty;
  }

  Future<void> clearStoredAuth() async {
    await _storage.delete(key: _tokenKey);
    await _storage.delete(key: _refreshTokenKey);
    await _storage.delete(key: _tokenExpiryKey);
    await _storage.delete(key: _profileKey);
  }

  Future<void> dispose() async {
    await _eventSub?.cancel();
    _httpClient.close();
  }

  Future<String?> _desktopAccessToken({required bool promptIfNecessary}) async {
    if (await _ensureDesktopAccessToken()) {
      return _storage.read(key: _tokenKey);
    }

    if (!promptIfNecessary) {
      return null;
    }

    await _desktopSignInInteractive();
    return _storage.read(key: _tokenKey);
  }

  Future<bool> _ensureDesktopAccessToken() async {
    final String? token = await _storage.read(key: _tokenKey);
    final bool expired = await _isStoredTokenExpired();

    if (token != null && token.isNotEmpty && !expired) {
      return true;
    }

    return _refreshDesktopAccessToken();
  }

  Future<bool> _refreshDesktopAccessToken() async {
    final String? refreshToken = await _storage.read(key: _refreshTokenKey);
    if (refreshToken == null || refreshToken.isEmpty) {
      return false;
    }

    if (AppConfig.googleClientId.isEmpty) {
      return false;
    }

    final Map<String, String> form = <String, String>{
      "client_id": AppConfig.googleClientId,
      "grant_type": "refresh_token",
      "refresh_token": refreshToken,
    };

    if (AppConfig.googleClientSecret.isNotEmpty) {
      form["client_secret"] = AppConfig.googleClientSecret;
    }

    final http.Response response = await _httpClient.post(
      Uri.parse("https://oauth2.googleapis.com/token"),
      headers: const <String, String>{
        HttpHeaders.contentTypeHeader: "application/x-www-form-urlencoded",
      },
      body: form,
    );

    if (response.statusCode != HttpStatus.ok) {
      if (response.statusCode == HttpStatus.badRequest ||
          response.statusCode == HttpStatus.unauthorized) {
        await _storage.delete(key: _refreshTokenKey);
      }
      return false;
    }

    final Map<String, Object?> payload = _decodeObject(response.body);
    final String? accessToken = payload["access_token"] as String?;
    if (accessToken == null || accessToken.isEmpty) {
      return false;
    }

    final int expiresInSeconds = _parseExpiresIn(payload["expires_in"]);
    await _persistDesktopTokens(
      accessToken: accessToken,
      refreshToken: refreshToken,
      expiresInSeconds: expiresInSeconds,
    );

    return true;
  }

  Future<AuthProfile> _desktopSignInInteractive() async {
    if (AppConfig.googleClientId.isEmpty) {
      throw StateError("Missing GOOGLE_CLIENT_ID for desktop sign-in.");
    }

    final Uri redirectUri = Uri.parse(AppConfig.googleRedirectUri);
    if (!redirectUri.hasAuthority ||
        redirectUri.host.isEmpty ||
        redirectUri.port <= 0) {
      throw StateError("GOOGLE_REDIRECT_URI must include host and port.");
    }

    final Set<String> scopeSet = <String>{
      ...DriveScopes.scopes,
      "openid",
      "email",
      "profile",
    };

    final String state = _randomState();
    final Uri authUri =
        Uri.https("accounts.google.com", "/o/oauth2/v2/auth", <String, String>{
          "client_id": AppConfig.googleClientId,
          "redirect_uri": redirectUri.toString(),
          "response_type": "code",
          "scope": scopeSet.join(" "),
          "access_type": "offline",
          "prompt": "consent",
          "include_granted_scopes": "true",
          "state": state,
        });

    final HttpServer server = await HttpServer.bind(
      redirectUri.host,
      redirectUri.port,
    );

    final Completer<String> codeCompleter = Completer<String>();
    late final StreamSubscription<HttpRequest> requestSub;

    requestSub = server.listen((HttpRequest request) async {
      if (request.uri.path != redirectUri.path) {
        request.response
          ..statusCode = HttpStatus.notFound
          ..headers.contentType = ContentType.html
          ..write("<h3>Not found</h3>");
        await request.response.close();
        return;
      }

      final String? reqState = request.uri.queryParameters["state"];
      final String? code = request.uri.queryParameters["code"];
      final String? error = request.uri.queryParameters["error"];

      if (error != null && !codeCompleter.isCompleted) {
        codeCompleter.completeError(
          StateError("Google sign-in cancelled or failed: $error"),
        );
      } else if (reqState != state && !codeCompleter.isCompleted) {
        codeCompleter.completeError(StateError("OAuth state mismatch."));
      } else if ((code == null || code.isEmpty) && !codeCompleter.isCompleted) {
        codeCompleter.completeError(StateError("Missing OAuth code."));
      } else if (!codeCompleter.isCompleted) {
        codeCompleter.complete(code!);
      }

      request.response
        ..statusCode = HttpStatus.ok
        ..headers.contentType = ContentType.html
        ..write(
          "<html><body style='font-family:sans-serif;background:#111;color:#eee;padding:24px'><h3>Helium Reader</h3><p>Authentication complete. You can close this tab.</p></body></html>",
        );
      await request.response.close();
    });

    try {
      await _openSystemBrowser(authUri);
      final String code = await codeCompleter.future.timeout(
        _desktopAuthTimeout,
      );
      final _DesktopToken token = await _exchangeCodeForToken(
        code: code,
        redirectUri: redirectUri,
      );

      await _persistDesktopTokens(
        accessToken: token.accessToken,
        refreshToken: token.refreshToken,
        expiresInSeconds: token.expiresInSeconds,
      );

      final AuthProfile profile = await _fetchProfile(token.accessToken);
      await _persistProfile(profile);
      return profile;
    } on TimeoutException {
      throw StateError("Timed out waiting for Google OAuth callback.");
    } finally {
      await requestSub.cancel();
      await server.close(force: true);
    }
  }

  Future<void> _openSystemBrowser(Uri uri) async {
    if (Platform.isWindows) {
      final String url = uri.toString();

      final ProcessResult direct = await Process.run("rundll32", <String>[
        "url.dll,FileProtocolHandler",
        url,
      ]);
      if (direct.exitCode == 0) {
        return;
      }

      final ProcessResult fallback = await Process.run("cmd", <String>[
        "/c",
        "start",
        "",
        '"$url"',
      ]);

      if (fallback.exitCode == 0) {
        return;
      }

      throw StateError(
        "Unable to launch browser for sign-in."
        " rundll32=${direct.exitCode}, cmd=${fallback.exitCode}",
      );
    }

    throw UnsupportedError("Desktop OAuth flow is implemented for Windows.");
  }

  Future<_DesktopToken> _exchangeCodeForToken({
    required String code,
    required Uri redirectUri,
  }) async {
    final Map<String, String> form = <String, String>{
      "code": code,
      "client_id": AppConfig.googleClientId,
      "grant_type": "authorization_code",
      "redirect_uri": redirectUri.toString(),
    };

    if (AppConfig.googleClientSecret.isNotEmpty) {
      form["client_secret"] = AppConfig.googleClientSecret;
    }

    final http.Response response = await _httpClient.post(
      Uri.parse("https://oauth2.googleapis.com/token"),
      headers: const <String, String>{
        HttpHeaders.contentTypeHeader: "application/x-www-form-urlencoded",
      },
      body: form,
    );

    if (response.statusCode != HttpStatus.ok) {
      final bool invalidClient = response.body.contains("invalid_client");
      final String hint = invalidClient && AppConfig.googleClientSecret.isEmpty
          ? " Add GOOGLE_CLIENT_SECRET for desktop OAuth."
          : "";
      throw StateError(
        "Token exchange failed (${response.statusCode}): ${response.body}$hint",
      );
    }

    final Map<String, Object?> payload = _decodeObject(response.body);
    final String? accessToken = payload["access_token"] as String?;
    if (accessToken == null || accessToken.isEmpty) {
      throw StateError("Token response missing access_token.");
    }

    final String? refreshToken = payload["refresh_token"] as String?;
    final int expiresInSeconds = _parseExpiresIn(payload["expires_in"]);

    return _DesktopToken(
      accessToken: accessToken,
      refreshToken: refreshToken,
      expiresInSeconds: expiresInSeconds,
    );
  }

  Future<AuthProfile> _fetchProfile(String accessToken) async {
    final http.Response response = await _httpClient.get(
      Uri.parse("https://openidconnect.googleapis.com/v1/userinfo"),
      headers: <String, String>{
        HttpHeaders.authorizationHeader: "Bearer $accessToken",
      },
    );

    if (response.statusCode != HttpStatus.ok) {
      final AuthProfile? cached = await cachedProfile();
      if (cached != null) {
        return cached;
      }
      throw StateError("Unable to load Google account profile.");
    }

    final Map<String, Object?> payload = _decodeObject(response.body);
    return AuthProfile(
      email: (payload["email"] as String? ?? "").trim(),
      displayName: (payload["name"] as String? ?? "").trim(),
      photoUrl: (payload["picture"] as String? ?? "").trim(),
    );
  }

  Future<void> _persistDesktopTokens({
    required String accessToken,
    required int expiresInSeconds,
    String? refreshToken,
  }) async {
    await _storage.write(key: _tokenKey, value: accessToken);

    final DateTime expiry = DateTime.now().toUtc().add(
      Duration(seconds: expiresInSeconds),
    );
    await _storage.write(key: _tokenExpiryKey, value: expiry.toIso8601String());

    if (refreshToken != null && refreshToken.isNotEmpty) {
      await _storage.write(key: _refreshTokenKey, value: refreshToken);
    }
  }

  Future<bool> _isStoredTokenExpired() async {
    final String? raw = await _storage.read(key: _tokenExpiryKey);
    if (raw == null || raw.isEmpty) {
      return true;
    }

    final DateTime? expiry = DateTime.tryParse(raw)?.toUtc();
    if (expiry == null) {
      return true;
    }

    return DateTime.now().toUtc().isAfter(expiry.subtract(_tokenExpirySkew));
  }

  Future<void> _persistProfile(AuthProfile profile) {
    return _storage.write(
      key: _profileKey,
      value: jsonEncode(profile.toJson()),
    );
  }

  String _randomState() {
    final Random random = Random.secure();
    final List<int> bytes = List<int>.generate(24, (_) => random.nextInt(256));
    return base64UrlEncode(bytes).replaceAll("=", "");
  }

  int _parseExpiresIn(Object? value) {
    if (value is int) {
      return value;
    }
    if (value is String) {
      return int.tryParse(value) ?? 3600;
    }
    return 3600;
  }

  Map<String, Object?> _decodeObject(String rawJson) {
    final Object? decoded = jsonDecode(rawJson);
    if (decoded is Map<String, Object?>) {
      return decoded;
    }

    if (decoded is Map) {
      final Map<String, Object?> casted = <String, Object?>{};
      decoded.forEach((key, value) {
        if (key is String) {
          casted[key] = value;
        }
      });
      return casted;
    }

    throw StateError("Expected JSON object.");
  }

  String? _extractAccessToken(Map<String, String> headers) {
    final String? authorization =
        headers[HttpHeaders.authorizationHeader] ?? headers["Authorization"];
    if (authorization == null || !authorization.startsWith("Bearer ")) {
      return null;
    }
    return authorization.replaceFirst("Bearer ", "").trim();
  }
}

class _DesktopToken {
  const _DesktopToken({
    required this.accessToken,
    required this.refreshToken,
    required this.expiresInSeconds,
  });

  final String accessToken;
  final String? refreshToken;
  final int expiresInSeconds;
}
