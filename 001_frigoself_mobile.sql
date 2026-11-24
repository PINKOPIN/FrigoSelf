-- =====================================================================
-- FrigoSelf mobile — migrazione per il database Supabase esistente
-- =====================================================================
-- COSA FA
--   * aggiunge colonne a food_items (quantità, marca, prezzo, foto, stato...)
--   * crea shopping_items e feedback
--   * crea le funzioni: frigo_create_family, frigo_family_members,
--     frigo_delete_account
--   * aggiunge regole RLS (si SOMMANO a quelle già presenti, non le sostituiscono)
--   * crea i bucket Storage "photos" e "avatars"
--   * abilita il tempo reale sulle tabelle usate dall'app
--
-- È TUTTA ADDITIVA: nessun dato esistente viene cancellato o modificato.
-- Le righe già presenti restano valide (status = 'active').
--
-- COME USARLA
--   1. Se il database è VUOTO (nessuna tabella families / food_items), esegui
--      PRIMA 000_base_schema.sql, poi questo file.
--      Se invece le tabelle esistono già (app web con dati), salta la 000 e
--      confronta lo schema con le assunzioni sotto prima di continuare.
--   2. Incolla questo file ed eseguilo (SQL Editor del tuo progetto Supabase).
--
-- ASSUNZIONI
--   * families(id uuid, name, join_code, created_by), family_members(family_id,
--     user_id), food_items(id, family_id, name, category, location, expiry):
--     sono esattamente le tabelle create da 000_base_schema.sql
--   * esiste la funzione join_family_by_code(_code text), creata dalla 000
-- =====================================================================


-- ---------- 1. Colonne aggiuntive su food_items ----------
alter table public.food_items add column if not exists category_id text;
alter table public.food_items add column if not exists quantity numeric not null default 1;
alter table public.food_items add column if not exists unit text not null default 'pz';
alter table public.food_items add column if not exists brand text not null default '';
alter table public.food_items add column if not exists price numeric;
alter table public.food_items add column if not exists notes text not null default '';
alter table public.food_items add column if not exists barcode text not null default '';
alter table public.food_items add column if not exists purchase_date date;
alter table public.food_items add column if not exists opened_date date;
alter table public.food_items add column if not exists package_photo_url text;
alter table public.food_items add column if not exists food_photo_url text;
alter table public.food_items add column if not exists favorite boolean not null default false;
alter table public.food_items add column if not exists status text not null default 'active';
alter table public.food_items add column if not exists closed_at timestamptz;
alter table public.food_items add column if not exists created_at timestamptz not null default now();
alter table public.food_items add column if not exists updated_at timestamptz not null default now();

do $$ begin
  alter table public.food_items
    add constraint food_items_status_check check (status in ('active','consumed','wasted'));
exception when duplicate_object then null; end $$;

create index if not exists food_items_family_expiry_idx
  on public.food_items (family_id, expiry);

create or replace function public.frigo_touch_updated_at()
returns trigger language plpgsql as $$
begin
  new.updated_at := now();
  return new;
end $$;

drop trigger if exists frigo_food_items_touch on public.food_items;
create trigger frigo_food_items_touch
  before update on public.food_items
  for each row execute function public.frigo_touch_updated_at();


-- ---------- 2. Nuove tabelle ----------
create table if not exists public.shopping_items (
  id uuid primary key default gen_random_uuid(),
  family_id uuid not null references public.families(id) on delete cascade,
  name text not null check (char_length(name) between 1 and 120),
  quantity text not null default '',
  checked boolean not null default false,
  added_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now()
);
create index if not exists shopping_items_family_idx
  on public.shopping_items (family_id, created_at desc);

create table if not exists public.feedback (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references auth.users(id) on delete set null,
  email text not null default '',
  text text not null check (char_length(text) between 1 and 2000),
  created_at timestamptz not null default now()
);


-- ---------- 3. Funzioni di supporto ----------
-- True se l'utente corrente è membro della famiglia.
-- security definer: evita la ricorsione delle regole RLS su family_members.
create or replace function public.frigo_is_member(_family_id uuid)
returns boolean
language sql stable security definer
set search_path = public
as $$
  select exists (
    select 1 from public.family_members
    where family_id = _family_id and user_id = auth.uid()
  );
$$;

-- Crea una famiglia con codice d'invito di 6 caratteri (niente 0/O/1/I)
-- e ne aggiunge l'utente come membro.
create or replace function public.frigo_create_family(_name text)
returns uuid
language plpgsql security definer
set search_path = public
as $$
declare
  alphabet constant text := 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  new_code text;
  fid uuid;
begin
  if auth.uid() is null then
    raise exception 'not authenticated';
  end if;

  loop
    select string_agg(substr(alphabet, 1 + floor(random() * length(alphabet))::int, 1), '')
      into new_code from generate_series(1, 6);
    exit when not exists (select 1 from public.families where join_code = new_code);
  end loop;

  insert into public.families (name, join_code)
    values (coalesce(nullif(trim(_name), ''), 'La mia famiglia'), new_code)
    returning id into fid;

  insert into public.family_members (family_id, user_id) values (fid, auth.uid());
  return fid;
end $$;

-- Nome, email e foto dei membri: solo se chi chiede fa parte della famiglia.
create or replace function public.frigo_family_members(_family_id uuid)
returns table (user_id uuid, display_name text, email text, avatar_url text)
language plpgsql stable security definer
set search_path = public
as $$
begin
  if not public.frigo_is_member(_family_id) then
    return;
  end if;
  return query
    select u.id,
           coalesce(u.raw_user_meta_data ->> 'display_name',
                    u.raw_user_meta_data ->> 'full_name', '')::text,
           coalesce(u.email, '')::text,
           (u.raw_user_meta_data ->> 'avatar_url')::text
    from public.family_members fm
    join auth.users u on u.id = fm.user_id
    where fm.family_id = _family_id;
end $$;

-- Elimina l'account di chi la chiama. Se era l'ultimo membro di una famiglia,
-- elimina anche famiglia, alimenti e lista della spesa.
create or replace function public.frigo_delete_account()
returns void
language plpgsql security definer
set search_path = public
as $$
declare
  uid uuid := auth.uid();
  fam uuid[];
begin
  if uid is null then
    raise exception 'not authenticated';
  end if;

  select coalesce(array_agg(family_id), '{}') into fam
    from public.family_members where user_id = uid;

  delete from public.family_members where user_id = uid;

  delete from public.shopping_items s
    where s.family_id = any(fam)
      and not exists (select 1 from public.family_members m where m.family_id = s.family_id);
  delete from public.food_items f
    where f.family_id = any(fam)
      and not exists (select 1 from public.family_members m where m.family_id = f.family_id);
  delete from public.families fa
    where fa.id = any(fam)
      and not exists (select 1 from public.family_members m where m.family_id = fa.id);

  delete from auth.users where id = uid;
end $$;

revoke all on function public.frigo_create_family(text) from public, anon;
revoke all on function public.frigo_family_members(uuid) from public, anon;
revoke all on function public.frigo_delete_account() from public, anon;
revoke all on function public.frigo_is_member(uuid) from public, anon;
grant execute on function public.frigo_create_family(text) to authenticated;
grant execute on function public.frigo_family_members(uuid) to authenticated;
grant execute on function public.frigo_delete_account() to authenticated;
grant execute on function public.frigo_is_member(uuid) to authenticated;


-- ---------- 4. Regole RLS (si sommano a quelle esistenti) ----------
alter table public.shopping_items enable row level security;
alter table public.feedback enable row level security;

-- food_items: i membri leggono e scrivono gli alimenti della loro famiglia.
drop policy if exists frigo_items_select on public.food_items;
create policy frigo_items_select on public.food_items
  for select to authenticated using (public.frigo_is_member(family_id));

drop policy if exists frigo_items_insert on public.food_items;
create policy frigo_items_insert on public.food_items
  for insert to authenticated with check (public.frigo_is_member(family_id));

drop policy if exists frigo_items_update on public.food_items;
create policy frigo_items_update on public.food_items
  for update to authenticated
  using (public.frigo_is_member(family_id))
  with check (public.frigo_is_member(family_id));

drop policy if exists frigo_items_delete on public.food_items;
create policy frigo_items_delete on public.food_items
  for delete to authenticated using (public.frigo_is_member(family_id));

-- shopping_items
drop policy if exists frigo_shopping_all on public.shopping_items;
create policy frigo_shopping_all on public.shopping_items
  for all to authenticated
  using (public.frigo_is_member(family_id))
  with check (public.frigo_is_member(family_id));

-- family_members: ognuno vede e può lasciare le proprie appartenenze.
drop policy if exists frigo_members_select_own on public.family_members;
create policy frigo_members_select_own on public.family_members
  for select to authenticated using (user_id = auth.uid() or public.frigo_is_member(family_id));

drop policy if exists frigo_members_leave on public.family_members;
create policy frigo_members_leave on public.family_members
  for delete to authenticated using (user_id = auth.uid());

-- families: i membri leggono la propria famiglia (nome e codice d'invito).
drop policy if exists frigo_families_select on public.families;
create policy frigo_families_select on public.families
  for select to authenticated using (public.frigo_is_member(id));

-- feedback: si può solo inviare, mai leggere dall'app.
drop policy if exists frigo_feedback_insert on public.feedback;
create policy frigo_feedback_insert on public.feedback
  for insert to authenticated
  with check (user_id is null or user_id = auth.uid());


-- ---------- 5. Storage: foto alimenti e avatar ----------
insert into storage.buckets (id, name, public)
values ('photos', 'photos', true), ('avatars', 'avatars', true)
on conflict (id) do nothing;

-- photos/<family_id>/<file>.jpg — scrivono solo i membri di quella famiglia
drop policy if exists frigo_photos_insert on storage.objects;
create policy frigo_photos_insert on storage.objects
  for insert to authenticated
  with check (
    bucket_id = 'photos'
    and public.frigo_is_member(((storage.foldername(name))[1])::uuid)
  );

drop policy if exists frigo_photos_delete on storage.objects;
create policy frigo_photos_delete on storage.objects
  for delete to authenticated
  using (
    bucket_id = 'photos'
    and public.frigo_is_member(((storage.foldername(name))[1])::uuid)
  );

-- avatars/<user_id>/avatar.jpg — scrive solo il proprietario
drop policy if exists frigo_avatars_insert on storage.objects;
create policy frigo_avatars_insert on storage.objects
  for insert to authenticated
  with check (bucket_id = 'avatars' and (storage.foldername(name))[1] = auth.uid()::text);

drop policy if exists frigo_avatars_update on storage.objects;
create policy frigo_avatars_update on storage.objects
  for update to authenticated
  using (bucket_id = 'avatars' and (storage.foldername(name))[1] = auth.uid()::text);

drop policy if exists frigo_avatars_delete on storage.objects;
create policy frigo_avatars_delete on storage.objects
  for delete to authenticated
  using (bucket_id = 'avatars' and (storage.foldername(name))[1] = auth.uid()::text);


-- ---------- 6. Tempo reale ----------
do $$
declare t text;
begin
  foreach t in array array['food_items','shopping_items','family_members'] loop
    begin
      execute format('alter publication supabase_realtime add table public.%I', t);
    exception when duplicate_object then null;
    end;
  end loop;
end $$;

-- =====================================================================
-- NOTA SULL'APP WEB
-- Quando l'app mobile segna un alimento come "consumato" o "buttato" non lo
-- cancella: cambia status. L'app web, che mostra tutte le righe, deve
-- filtrare  .eq('status', 'active')  nelle sue query per non mostrarli.
-- =====================================================================
