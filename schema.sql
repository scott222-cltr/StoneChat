-- StoneChat starter database. Run this in Supabase SQL Editor.
-- IMPORTANT: review/test all policies before launching to the public.
create extension if not exists pgcrypto;

create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  username text unique not null check (char_length(username) between 3 and 24),
  display_name text not null default 'StoneChat member',
  bio text not null default '',
  avatar_url text,
  created_at timestamptz not null default now()
);

create table if not exists public.conversations (
  id uuid primary key default gen_random_uuid(),
  title text not null default 'Conversation',
  is_group boolean not null default false,
  created_by uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.conversation_members (
  conversation_id uuid not null references public.conversations(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  joined_at timestamptz not null default now(),
  primary key (conversation_id, user_id)
);

create table if not exists public.messages (
  id uuid primary key default gen_random_uuid(),
  conversation_id uuid not null references public.conversations(id) on delete cascade,
  sender_id uuid not null references auth.users(id) on delete cascade,
  body text not null default '',
  message_type text not null default 'text' check (message_type in ('text','image')),
  media_url text,
  created_at timestamptz not null default now(),
  constraint message_has_content check (char_length(body) > 0 or media_url is not null)
);

create table if not exists public.snaps (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  media_url text not null,
  caption text not null default '',
  created_at timestamptz not null default now(),
  expires_at timestamptz not null default (now() + interval '24 hours')
);

create table if not exists public.updates (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  body text not null check (char_length(body) between 1 and 500),
  created_at timestamptz not null default now()
);

create table if not exists public.user_blocks (
  blocker_id uuid not null references auth.users(id) on delete cascade,
  blocked_id uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (blocker_id, blocked_id),
  check (blocker_id <> blocked_id)
);

create table if not exists public.user_reports (
  id uuid primary key default gen_random_uuid(),
  reporter_id uuid not null references auth.users(id) on delete cascade,
  reported_user_id uuid not null references auth.users(id) on delete cascade,
  reason text not null check (char_length(reason) between 3 and 1000),
  created_at timestamptz not null default now(),
  status text not null default 'open' check (status in ('open','reviewing','closed'))
);

alter table public.profiles enable row level security;
alter table public.conversations enable row level security;
alter table public.conversation_members enable row level security;
alter table public.messages enable row level security;
alter table public.snaps enable row level security;
alter table public.updates enable row level security;
alter table public.user_blocks enable row level security;
alter table public.user_reports enable row level security;

-- Profiles are visible to signed-in members; users can only edit their own profile.
create policy "profiles visible to authenticated" on public.profiles for select to authenticated using (true);
create policy "users insert own profile" on public.profiles for insert to authenticated with check (auth.uid() = id);
create policy "users update own profile" on public.profiles for update to authenticated using (auth.uid() = id) with check (auth.uid() = id);

create policy "members see their conversations" on public.conversations for select to authenticated
using (exists (select 1 from public.conversation_members cm where cm.conversation_id = id and cm.user_id = auth.uid()));
create policy "signed-in users create conversations" on public.conversations for insert to authenticated with check (created_by = auth.uid());
create policy "members update conversations" on public.conversations for update to authenticated
using (exists (select 1 from public.conversation_members cm where cm.conversation_id = id and cm.user_id = auth.uid()))
with check (exists (select 1 from public.conversation_members cm where cm.conversation_id = id and cm.user_id = auth.uid()));

create policy "members see membership rows" on public.conversation_members for select to authenticated
using (user_id = auth.uid());
create policy "users join conversations they create" on public.conversation_members for insert to authenticated
with check (user_id = auth.uid() or exists (select 1 from public.conversations c where c.id = conversation_id and c.created_by = auth.uid()));
create policy "users leave own conversations" on public.conversation_members for delete to authenticated using (user_id = auth.uid());

create policy "members read messages" on public.messages for select to authenticated
using (exists (select 1 from public.conversation_members cm where cm.conversation_id = conversation_id and cm.user_id = auth.uid()));
create policy "members send messages as themselves" on public.messages for insert to authenticated
with check (sender_id = auth.uid() and exists (select 1 from public.conversation_members cm where cm.conversation_id = conversation_id and cm.user_id = auth.uid()));
create policy "users delete own messages" on public.messages for delete to authenticated using (sender_id = auth.uid());

create policy "signed in members read snaps" on public.snaps for select to authenticated using (true);
create policy "users post own snaps" on public.snaps for insert to authenticated with check (user_id = auth.uid());
create policy "users delete own snaps" on public.snaps for delete to authenticated using (user_id = auth.uid());

create policy "signed in members read updates" on public.updates for select to authenticated using (true);
create policy "users post own updates" on public.updates for insert to authenticated with check (user_id = auth.uid());
create policy "users delete own updates" on public.updates for delete to authenticated using (user_id = auth.uid());

create policy "users see their own blocks" on public.user_blocks for select to authenticated using (blocker_id = auth.uid());
create policy "users block others" on public.user_blocks for insert to authenticated with check (blocker_id = auth.uid());
create policy "users unblock others" on public.user_blocks for delete to authenticated using (blocker_id = auth.uid());

create policy "users create reports" on public.user_reports for insert to authenticated with check (reporter_id = auth.uid());
create policy "reporters see own reports" on public.user_reports for select to authenticated using (reporter_id = auth.uid());

-- Keep the app's chat list fresh.
create or replace function public.touch_conversation()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  update public.conversations set updated_at = now() where id = new.conversation_id;
  return new;
end;
$$;
drop trigger if exists messages_touch_conversation on public.messages;
create trigger messages_touch_conversation after insert on public.messages
for each row execute function public.touch_conversation();

-- Make new profile rows when an auth account is created.
create or replace function public.handle_new_user()
returns trigger language plpgsql security definer set search_path = public as $$
declare
  desired_username text;
begin
  desired_username := coalesce(new.raw_user_meta_data->>'username', split_part(new.email, '@', 1), 'member');
  desired_username := regexp_replace(lower(desired_username), '[^a-z0-9_]', '', 'g');
  if char_length(desired_username) < 3 then desired_username := 'member_' || substr(new.id::text, 1, 6); end if;
  insert into public.profiles (id, username, display_name)
  values (new.id, desired_username, coalesce(new.raw_user_meta_data->>'username', desired_username))
  on conflict (id) do nothing;
  return new;
end;
$$;
drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created after insert on auth.users
for each row execute function public.handle_new_user();

-- Snap media storage bucket. Public URLs make images easy to display in this starter.
-- For a production social app, use private buckets and signed URLs instead.
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('snaps', 'snaps', true, 10485760, array['image/jpeg','image/png','image/webp'])
on conflict (id) do nothing;

create policy "signed-in users upload snaps" on storage.objects for insert to authenticated
with check (bucket_id = 'snaps' and (storage.foldername(name))[1] = auth.uid()::text);
create policy "signed-in users read snaps" on storage.objects for select to authenticated using (bucket_id = 'snaps');
create policy "users delete their own snap files" on storage.objects for delete to authenticated
using (bucket_id = 'snaps' and (storage.foldername(name))[1] = auth.uid()::text);

-- Realtime: in Supabase Dashboard > Database > Replication, enable Realtime for messages.
