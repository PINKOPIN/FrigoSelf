-- =====================================================================
-- FrigoSelf — schema di base (database VUOTO)
-- =====================================================================
-- Da eseguire PRIMA di 001_frigoself_mobile.sql, una sola volta, su un
-- database in cui le tabelle families, family_members e food_items
-- NON esistono ancora.
--
-- È sicuro rilanciarlo: usa "if not exists" e "create or replace".
-- Non cancella e non modifica dati.
--
-- COSA CREA
--   * families        (id, name, join_code, created_by, created_at)
--   * family_members  (family_id, user_id, role, joined_at)
--   * food_items      (colonne di base; le altre le aggiunge la 001)
--   * join_family_by_code(_code)  → entra in una famiglia con il codice
--   * RLS attiva sulle tre tabelle (le regole le crea la 001)
-- =====================================================================

create extension if not exists pgcrypto;

-- ---------- Famiglie ----------
create table if not exists public.families (
  id          uuid primary key default gen_random_uuid(),
  name        text not null default 'La mia famiglia',
  join_code   text not null unique,
  created_by  uuid default auth.uid() references auth.users (id) on delete set null,
  created_at  timestamptz not null default now()
);

-- ---------- Membri ----------
create table if not exists public.family_members (
  family_id   uuid not null references public.families (id) on delete cascade,
  user_id     uuid not null references auth.users (id) on delete cascade,
  role        text not null default 'member',
  joined_at   timestamptz not null default now(),
  primary key (family_id, user_id)
);

create index if not exists family_members_user_idx
  on public.family_members (user_id);

-- ---------- Alimenti (colonne di base) ----------
-- category e location restano testo libero per restare compatibili con
-- l'app web (Frutta, Verdure, Carne, Pesce, Latticini, Surgelati, Bevande,
-- Dispensa / Frigo, Freezer, Dispensa).
create table if not exists public.food_items (
  id          uuid primary key default gen_random_uuid(),
  family_id   uuid not null references public.families (id) on delete cascade,
  created_by  uuid default auth.uid() references auth.users (id) on delete set null,
  name        text not null,
  category    text not null default 'Dispensa',
  location    text not null default 'Frigo',
  expiry      date not null
);

-- RLS attiva: senza regole nessuno può leggere o scrivere.
-- Le regole vere (solo i membri della famiglia) sono nella 001.
alter table public.families       enable row level security;
alter table public.family_members enable row level security;
alter table public.food_items     enable row level security;

-- ---------- Entrare in una famiglia con il codice ----------
-- Chiamata dall'app: .rpc('join_family_by_code', params: {'_code': 'ABC234'})
-- Se il codice non esiste lancia un errore (l'app lo mostra come "codice non valido").
create or replace function public.join_family_by_code(_code text)
returns uuid
language plpgsql security definer
set search_path = public
as $$
declare
  fid uuid;
begin
  if auth.uid() is null then
    raise exception 'not authenticated' using errcode = '28000';
  end if;

  select id into fid
    from public.families
    where join_code = upper(trim(_code));

  if fid is null then
    raise exception 'invalid code' using errcode = 'P0002';
  end if;

  insert into public.family_members (family_id, user_id)
    values (fid, auth.uid())
    on conflict (family_id, user_id) do nothing;

  return fid;
end $$;

revoke all on function public.join_family_by_code(text) from public, anon;
grant execute on function public.join_family_by_code(text) to authenticated;
