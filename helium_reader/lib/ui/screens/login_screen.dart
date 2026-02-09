import "package:flutter/material.dart";

import "../../core/config/app_config.dart";

class LoginScreen extends StatelessWidget {
  const LoginScreen({
    super.key,
    required this.onSignIn,
    required this.errorMessage,
  });

  final Future<void> Function() onSignIn;
  final String? errorMessage;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const Icon(
                Icons.menu_book_rounded,
                size: 76,
                color: Color(0xFFEF7D86),
              ),
              const SizedBox(height: 12),
              Text(
                AppConfig.appName,
                style: const TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                "Google Drive EPUB reader with offline-first sync.",
                textAlign: TextAlign.center,
                style: TextStyle(color: Color(0xFFA7A7A7)),
              ),
              const SizedBox(height: 30),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () => onSignIn(),
                  icon: const Icon(Icons.login_rounded),
                  label: const Text("Sign in with Google"),
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                "If you are offline, previously downloaded books remain readable after sign-in has been completed once.",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: Color(0xFFA7A7A7)),
              ),
              if (errorMessage != null && errorMessage!.isNotEmpty) ...<Widget>[
                const SizedBox(height: 12),
                Text(
                  errorMessage!,
                  style: const TextStyle(color: Color(0xFFEF7D86)),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
