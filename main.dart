import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'core/supabase_config.dart';
import 'core/theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (!SupabaseConfig.isConfigured) {
    runApp(const _MissingConfigApp());
    return;
  }

  await Supabase.initialize(
    url: SupabaseConfig.url,
    anonKey: SupabaseConfig.anonKey,
  );

  await initializeDateFormatting('it');
  await initializeDateFormatting('en');

  runApp(const ProviderScope(child: FrigoSelfApp()));
}

/// Mostrata solo se l'app è stata compilata senza URL/chiave di Supabase.
class _MissingConfigApp extends StatelessWidget {
  const _MissingConfigApp();

  @override
  Widget build(BuildContext context) => MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        home: const Scaffold(
          body: SafeArea(
            child: Padding(
              padding: EdgeInsets.all(28),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.settings_suggest, size: 72),
                    SizedBox(height: 16),
                    Text('Configura Supabase',
                        style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
                    SizedBox(height: 12),
                    Text(
                      'Questa copia di FrigoSelf è stata compilata senza i dati '
                      'del database.\n\nCompila con:\n'
                      'flutter run --dart-define=SUPABASE_URL=... '
                      '--dart-define=SUPABASE_KEY=...\n\n'
                      'Guida: supabase/SETUP_SUPABASE.md',
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
}
