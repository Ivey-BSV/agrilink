create table if not exists public.user_blocks (
  id uuid primary key default gen_random_uuid(),
  blocker_id uuid not null references auth.users(id) on delete cascade,
  blocked_id uuid not null references auth.users(id) on delete cascade,
  created_at timestamp with time zone default now(),
  unique (blocker_id, blocked_id),
  check (blocker_id <> blocked_id)
);

alter table public.user_blocks enable row level security;

drop policy if exists "Users can read own block relations" on public.user_blocks;
create policy "Users can read own block relations"
on public.user_blocks
for select
to authenticated
using (auth.uid() = blocker_id or auth.uid() = blocked_id);

drop policy if exists "Users can insert own blocks" on public.user_blocks;
create policy "Users can insert own blocks"
on public.user_blocks
for insert
to authenticated
with check (auth.uid() = blocker_id);

drop policy if exists "Users can delete own blocks" on public.user_blocks;
create policy "Users can delete own blocks"
on public.user_blocks
for delete
to authenticated
using (auth.uid() = blocker_id);

create index if not exists user_blocks_blocker_idx on public.user_blocks(blocker_id);
create index if not exists user_blocks_blocked_idx on public.user_blocks(blocked_id);
