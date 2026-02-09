class AuthProfile {
  const AuthProfile({
    required this.email,
    required this.displayName,
    required this.photoUrl,
  });

  final String email;
  final String displayName;
  final String photoUrl;

  bool get isEmpty => email.isEmpty;

  Map<String, String> toJson() {
    return <String, String>{
      "email": email,
      "displayName": displayName,
      "photoUrl": photoUrl,
    };
  }

  factory AuthProfile.fromJson(Map<String, Object?> json) {
    return AuthProfile(
      email: (json["email"] as String?) ?? "",
      displayName: (json["displayName"] as String?) ?? "",
      photoUrl: (json["photoUrl"] as String?) ?? "",
    );
  }
}
