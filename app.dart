import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/l10n/app_l10n.dart';
import 'core/theme/app_theme.dart';
import 'presentation/providers/providers.dart';
import 'presentation/screens/auth/auth_screens.dart';
import 'presentation/screens/home_shell.dart';
import 'presentation/screens/splash_screen.dart';

/// Radice dell'app: tema, lingua e scelta della schermata iniziale.
///
/// ATTENZIONE: file ricostruito dopo una sovrascrittura accidentale.
class FrigoSelfApp extends ConsumerWidget {
  const FrigoSelfApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);

    return MaterialApp(
      title: 'FrigoSelf',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: settings.themeMode,
      locale:
          settings.languageCode == null ? null : Locale(settings.languageCode!),
      supportedLocales: AppL10n.supported,
      localizationsDelegates: AppL10n.delegates,
      home: const _Root(),
    );
  }
}

/// Sceglie la schermata: accesso → verifica email → famiglia → app.
class _Root extends ConsumerWidget {
  const _Root();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authStateProvider);
    return auth.when(
      loading: () => const SplashScreen(),
      error: (e, _) => Scaffold(body: Center(child: Text('$e'))),
      data: (user) {
        if (user == null) return const LoginScreen();

        // Chi si registra con email deve prima verificarla.
        // Google e Apple arrivano già verificati.
        if (user.usesPassword && !user.emailVerified) {
          return const VerifyEmailScreen();
        }

        final profile = ref.watch(profileProvider);
        return profile.when(
          loading: () => const SplashScreen(),
          error: (e, _) => Scaffold(body: Center(child: Text('$e'))),
          data: (p) =>
              p?.familyId == null ? const FamilySetupScreen() : const HomeShell(),
        );
      },
    );
  }
}
