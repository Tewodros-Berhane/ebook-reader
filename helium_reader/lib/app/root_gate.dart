import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

import "../state/auth_state.dart";
import "providers.dart";
import "../ui/screens/library_screen.dart";
import "../ui/screens/login_screen.dart";
import "../ui/screens/splash_screen.dart";

class RootGate extends ConsumerWidget {
  const RootGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AuthState authState = ref.watch(authControllerProvider);

    switch (authState.status) {
      case AuthStatus.loading:
        return const SplashScreen();
      case AuthStatus.signedOut:
        return LoginScreen(
          errorMessage: authState.error,
          onSignIn: () => ref.read(authControllerProvider.notifier).signIn(),
        );
      case AuthStatus.signedIn:
      case AuthStatus.offline:
        return const LibraryScreen();
    }
  }
}
