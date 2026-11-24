# Creare il tuo database Supabase (gratis, 10 minuti)

FrigoSelf usa un progetto Supabase **tuo**: nessun altro servizio è necessario.

## 1. Crea il progetto
1. Vai su https://supabase.com → **Start your project** → accedi (anche con GitHub).
2. **New project**: scegli un nome (es. `frigoself`), una password per il database
   (salvala), la regione più vicina (es. *Frankfurt*). Attendi 1–2 minuti.

## 2. Crea le tabelle
1. Menu a sinistra → **SQL Editor** → **New query**.
2. Apri `supabase/migrations/000_base_schema.sql`, copia tutto, incolla, **Run**.
3. Nuova query: apri `001_frigoself_mobile.sql`, copia tutto, incolla, **Run**.
   Deve comparire "Success". Crea tabelle, regole di sicurezza (RLS), funzioni,
   bucket foto `photos` e `avatars` e il tempo reale.

## 3. Accesso utenti
**Authentication → Providers**: *Email* è già attivo. Per provare subito senza
email di conferma: **Authentication → Sign In / Providers → Email → disattiva
"Confirm email"** (riattivalo prima della pubblicazione).
Google/Apple sono facoltativi (vedi README).

## 4. Copia le due chiavi
**Project Settings → API Keys**:
- **Project URL** (`https://xxxx.supabase.co`)
- **Publishable key** (`sb_publishable_...`) — NON la `service_role`/secret.

## 5. Usale nell'app
Da terminale:
```bash
flutter run --dart-define=SUPABASE_URL=https://xxxx.supabase.co \
            --dart-define=SUPABASE_KEY=sb_publishable_...
```
Su GitHub (per l'APK): **Settings → Secrets and variables → Actions → New
repository secret**, crea `SUPABASE_URL` e `SUPABASE_KEY`
(e, se usi Google, `GOOGLE_WEB_CLIENT_ID`).
