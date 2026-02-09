class AppConfig {
  const AppConfig._();

  static const String appName = "Helium Reader";

  static const String googleClientId = String.fromEnvironment(
    "GOOGLE_CLIENT_ID",
    defaultValue: "",
  );

  static const String googleServerClientId = String.fromEnvironment(
    "GOOGLE_SERVER_CLIENT_ID",
    defaultValue: "",
  );

  static const String googleClientSecret = String.fromEnvironment(
    "GOOGLE_CLIENT_SECRET",
    defaultValue: "",
  );

  static const String googleRedirectUri = String.fromEnvironment(
    "GOOGLE_REDIRECT_URI",
    defaultValue: "http://localhost:4200/oauth2callback",
  );

  static const String scopedFolderId = String.fromEnvironment(
    "GOOGLE_DRIVE_FOLDER_ID",
    defaultValue: "",
  );
}
