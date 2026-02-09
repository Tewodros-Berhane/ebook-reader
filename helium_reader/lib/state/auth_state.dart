enum AuthStatus { loading, signedOut, signedIn, offline }

class AuthState {
  const AuthState({
    required this.status,
    required this.email,
    required this.displayName,
    required this.photoUrl,
    required this.error,
  });

  final AuthStatus status;
  final String email;
  final String displayName;
  final String photoUrl;
  final String? error;

  bool get canReadLibrary =>
      status == AuthStatus.signedIn || status == AuthStatus.offline;

  AuthState copyWith({
    AuthStatus? status,
    String? email,
    String? displayName,
    String? photoUrl,
    String? error,
  }) {
    return AuthState(
      status: status ?? this.status,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      photoUrl: photoUrl ?? this.photoUrl,
      error: error,
    );
  }

  static const AuthState loading = AuthState(
    status: AuthStatus.loading,
    email: "",
    displayName: "",
    photoUrl: "",
    error: null,
  );
}
