# FrigoSelf — Il tuo cibo, sotto controllo

App Flutter (Android e iOS) per gestire frigo, congelatore e dispensa di tutta la famiglia
e ricevere avvisi prima che gli alimenti scadano.

Usa **Supabase** (il tuo progetto gratuito, guida in `supabase/SETUP_SUPABASE.md`):
account, dispensa condivisa in tempo reale, foto.

> **Stato:** codice scritto e controllato in modo statico (import, pacchetti,
> parentesi), ma **mai compilato né eseguito**: nell'ambiente di sviluppo non
> c'era Flutter. Al primo `flutter run` possono uscire piccoli errori da correggere.

## Cosa contiene

| Area | File principali |
|------|-----------------|
| Accesso: email, Google, Apple, reset password, verifica email, eliminazione account | `data/repositories/auth_repository.dart`, `presentation/screens/auth/` |
| Famiglia con codice d'invito a 6 caratteri, tempo reale | `data/repositories/`, `domain/models/family_models.dart` |
| Frigo, Congelatore, Dispensa; scadenze 🟢🟡🔴 | `presentation/screens/storage_screen.dart`, `core/utils/food_logic.dart` |
| Aggiunta/modifica, dettaglio, azioni rapide | `add_edit_item_screen.dart`, `item_detail_screen.dart`, `item_actions.dart` |
| Foto, barcode, OCR della data di scadenza | `data/services/media_services.dart`, `ocr_service.dart`, `scanner_screen.dart` |
| Notifiche locali (anche offline) | `data/services/notification_service.dart` |
| Calendario, statistiche, ricette, lista della spesa | `calendar_screen.dart`, `stats_screen.dart`, `recipes_screen.dart`, `shopping_screen.dart` |
| Impostazioni, esportazione/importazione, consensi, feedback | `settings_screen.dart`, `export_service.dart` |
| Italiano e inglese, tema chiaro/scuro con colori del logo | `core/l10n/app_l10n.dart`, `core/theme/app_theme.dart` |
| Test | `test/`, `integration_test/` |

Regola dei colori: 🟢 oltre 7 giorni · 🟡 da 3 a 7 · 🔴 meno di 3 giorni o scaduto.

## Avvio in 4 passi

Serve Flutter 3.27 o superiore.

**1. Database (una sola volta).** Crea un progetto Supabase gratuito e segui
`supabase/SETUP_SUPABASE.md`: esegui `000_base_schema.sql` e poi
`001_frigoself_mobile.sql` nello SQL Editor. Le migrazioni sono state provate su
PostgreSQL 16 (isolamento tra famiglie, codice d'invito, eliminazione account)
e si possono rilanciare senza danni.

**2. Piattaforme.**
```bash
flutter create . --project-name frigoself --org it.frigoself --platforms android,ios
python3 scripts/setup_platforms.py     # permessi, notifiche, desugaring, minSdk 23
flutter pub get && dart run flutter_launcher_icons   # icona dell'app
```

**3. Esecuzione.**
```bash
flutter pub get
flutter test
flutter run --dart-define=SUPABASE_URL=https://xxxx.supabase.co --dart-define=SUPABASE_KEY=sb_publishable_...
```

**4. APK con GitHub.** Carica il progetto su GitHub (anche `.github` e `.gitignore`):
crea i secret `SUPABASE_URL` e `SUPABASE_KEY`; ad ogni push l'Actions `Build Android APK` compila e produce `frigoself-apk`.

## Da sapere

- **Stati:** "consumato" e "buttato" non cancellano l'alimento ma cambiano `status`
  (servono alle statistiche).
- **Chiavi:** l'URL e la chiave "publishable" sono pubblici per progettazione
  (la sicurezza è nelle regole RLS). Non inserire mai la `service_role`.
  Non sono nel codice: si passano con `--dart-define` (vedi sopra).
- **Google:** per "Accedi con Google" imposta `--dart-define=GOOGLE_WEB_CLIENT_ID=...`
  e abilita il provider in Supabase → Authentication.
- **Apple:** richiede un Mac, un account sviluppatore e il provider Apple attivo in Supabase.
- **iPhone:** le notifiche locali funzionano da app installata; il permesso viene chiesto all'avvio.
- Lo script `scripts/setup_platforms.py` è stato provato solo su template simulati.

## Non ancora fatto

Widget per la schermata Home, Wear OS / Apple Watch, dashboard web amministrativa,
splash nativa, pubblicazione su Play Store e App Store.
