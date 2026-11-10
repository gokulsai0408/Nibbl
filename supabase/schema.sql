-- Nibbl social features: usernames, friends, posts, reactions, comments.
-- Run this whole file once in Supabase: Dashboard → SQL Editor → New query → Run.
-- Then: Authentication → Sign In / Providers → enable "Allow anonymous sign-ins".
--
-- Privacy model: everyone signed in can look up usernames; posts, photos,
-- reactions and comments are visible only to the author and their accepted
-- friends. All reads go through the functions below, which enforce that.

create extension if not exists citext;

-- ---------------------------------------------------------------- tables

create table if not exists public.profiles (
  id            uuid primary key references auth.users (id) on delete cascade,
  username      citext not null unique check (username ~ '^[a-z0-9_.]{3,20}$'),
  display_name  text not null check (char_length(display_name) between 1 and 40),
  avatar_emoji  text not null default '🙂',
  mochi_level   int  not null default 1,
  streak        int  not null default 0,
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now()
);

create table if not exists public.friendships (
  id          bigint generated always as identity primary key,
  requester   uuid not null references public.profiles (id) on delete cascade,
  addressee   uuid not null references public.profiles (id) on delete cascade,
  status      text not null default 'pending' check (status in ('pending', 'accepted')),
  created_at  timestamptz not null default now(),
  check (requester <> addressee)
);
-- One row per pair, whichever direction.
create unique index if not exists friendships_pair
  on public.friendships (least(requester, addressee), greatest(requester, addressee));

create table if not exists public.posts (
  id          uuid primary key default gen_random_uuid(),
  author      uuid not null references public.profiles (id) on delete cascade,
  caption     text not null default '' check (char_length(caption) <= 500),
  photo_path  text,
  dish_name   text check (char_length(dish_name) <= 80),
  emoji       text,
  kcal        int,
  protein     int,
  recipe      jsonb,
  created_at  timestamptz not null default now()
);
create index if not exists posts_author_time on public.posts (author, created_at desc);

create table if not exists public.reactions (
  post_id     uuid not null references public.posts (id) on delete cascade,
  user_id     uuid not null references public.profiles (id) on delete cascade,
  emoji       text not null check (emoji in ('😋', '🔥', '👏', '❤️')),
  created_at  timestamptz not null default now(),
  primary key (post_id, user_id)
);

create table if not exists public.comments (
  id          bigint generated always as identity primary key,
  post_id     uuid not null references public.posts (id) on delete cascade,
  author      uuid not null references public.profiles (id) on delete cascade,
  body        text not null check (char_length(body) between 1 and 300),
  created_at  timestamptz not null default now()
);
create index if not exists comments_post_time on public.comments (post_id, created_at);

-- ---------------------------------------------------------------- helpers

create or replace function public.are_friends(a uuid, b uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from friendships
    where status = 'accepted'
      and ((requester = a and addressee = b) or (requester = b and addressee = a))
  );
$$;

create or replace function public.can_see(viewer uuid, owner uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select viewer = owner or are_friends(viewer, owner);
$$;

-- ---------------------------------------------------------------- RLS

alter table public.profiles    enable row level security;
alter table public.friendships enable row level security;
alter table public.posts       enable row level security;
alter table public.reactions   enable row level security;
alter table public.comments    enable row level security;

drop policy if exists "profiles readable" on public.profiles;
create policy "profiles readable" on public.profiles for select to authenticated using (true);
drop policy if exists "own profile insert" on public.profiles;
create policy "own profile insert" on public.profiles for insert to authenticated with check (id = auth.uid());
drop policy if exists "own profile update" on public.profiles;
create policy "own profile update" on public.profiles for update to authenticated using (id = auth.uid());

drop policy if exists "see own friendships" on public.friendships;
create policy "see own friendships" on public.friendships for select to authenticated
  using (auth.uid() in (requester, addressee));

drop policy if exists "see visible posts" on public.posts;
create policy "see visible posts" on public.posts for select to authenticated using (can_see(auth.uid(), author));
drop policy if exists "create own posts" on public.posts;
create policy "create own posts" on public.posts for insert to authenticated with check (author = auth.uid());
drop policy if exists "delete own posts" on public.posts;
create policy "delete own posts" on public.posts for delete to authenticated using (author = auth.uid());

drop policy if exists "see visible reactions" on public.reactions;
create policy "see visible reactions" on public.reactions for select to authenticated
  using (exists (select 1 from posts p where p.id = post_id and can_see(auth.uid(), p.author)));
drop policy if exists "react to visible posts" on public.reactions;
create policy "react to visible posts" on public.reactions for insert to authenticated
  with check (user_id = auth.uid()
    and exists (select 1 from posts p where p.id = post_id and can_see(auth.uid(), p.author)));
drop policy if exists "change own reaction" on public.reactions;
create policy "change own reaction" on public.reactions for update to authenticated using (user_id = auth.uid());
drop policy if exists "remove own reaction" on public.reactions;
create policy "remove own reaction" on public.reactions for delete to authenticated using (user_id = auth.uid());

drop policy if exists "see visible comments" on public.comments;
create policy "see visible comments" on public.comments for select to authenticated
  using (exists (select 1 from posts p where p.id = post_id and can_see(auth.uid(), p.author)));
drop policy if exists "comment on visible posts" on public.comments;
create policy "comment on visible posts" on public.comments for insert to authenticated
  with check (author = auth.uid()
    and exists (select 1 from posts p where p.id = post_id and can_see(auth.uid(), p.author)));
drop policy if exists "delete own or on own post" on public.comments;
create policy "delete own or on own post" on public.comments for delete to authenticated
  using (author = auth.uid() or exists (select 1 from posts p where p.id = post_id and p.author = auth.uid()));

-- ---------------------------------------------------------------- functions

-- Posts as JSON with author, reaction counts, my reaction and comment count.
create or replace function public.post_json(p posts)
returns jsonb language sql stable security definer set search_path = public as $$
  select jsonb_build_object(
    'id', p.id, 'caption', p.caption, 'photo_path', p.photo_path, 'dish_name', p.dish_name,
    'emoji', p.emoji, 'kcal', p.kcal, 'protein', p.protein, 'recipe', p.recipe, 'created_at', p.created_at,
    'author', (select to_jsonb(a) from profiles a where a.id = p.author),
    'reactions', coalesce((select jsonb_object_agg(emoji, n) from
        (select emoji, count(*) n from reactions r where r.post_id = p.id group by emoji) x), '{}'::jsonb),
    'my_reaction', (select emoji from reactions r where r.post_id = p.id and r.user_id = auth.uid()),
    'comment_count', (select count(*) from comments c where c.post_id = p.id)
  );
$$;

create or replace function public.get_feed(p_before timestamptz default now(), p_limit int default 20)
returns jsonb language sql stable security definer set search_path = public as $$
  select coalesce(jsonb_agg(post_json(p) order by p.created_at desc), '[]'::jsonb)
  from posts p
  where p.id in (
    select id from posts
    where created_at < p_before and can_see(auth.uid(), author)
    order by created_at desc
    limit least(p_limit, 50)
  );
$$;

create or replace function public.get_user_posts(p_user uuid, p_limit int default 30)
returns jsonb language sql stable security definer set search_path = public as $$
  select coalesce(jsonb_agg(post_json(p) order by p.created_at desc), '[]'::jsonb)
  from posts p
  where p.id in (
    select id from posts
    where author = p_user and can_see(auth.uid(), p_user)
    order by created_at desc
    limit least(p_limit, 60)
  );
$$;

create or replace function public.get_comments(p_post uuid)
returns jsonb language sql stable security definer set search_path = public as $$
  select coalesce(jsonb_agg(jsonb_build_object(
      'id', c.id, 'body', c.body, 'created_at', c.created_at,
      'author', (select to_jsonb(a) from profiles a where a.id = c.author)
    ) order by c.created_at), '[]'::jsonb)
  from comments c
  join posts p on p.id = c.post_id
  where c.post_id = p_post and can_see(auth.uid(), p.author);
$$;

-- My friendships with the other person's profile.
create or replace function public.get_friendships()
returns jsonb language sql stable security definer set search_path = public as $$
  select coalesce(jsonb_agg(jsonb_build_object(
      'id', f.id, 'status', f.status, 'incoming', f.addressee = auth.uid(), 'created_at', f.created_at,
      'other', (select to_jsonb(o) from profiles o
                where o.id = case when f.requester = auth.uid() then f.addressee else f.requester end)
    ) order by f.created_at desc), '[]'::jsonb)
  from friendships f
  where auth.uid() in (f.requester, f.addressee);
$$;

create or replace function public.search_profiles(q text)
returns jsonb language sql stable security definer set search_path = public as $$
  select coalesce(jsonb_agg(to_jsonb(p) order by p.username), '[]'::jsonb)
  from (
    select * from profiles
    where id <> auth.uid()
      and char_length(trim(q)) >= 2
      and (username ilike replace(lower(trim(both '@ ' from q)), '%', '') || '%'
           or display_name ilike '%' || replace(trim(q), '%', '') || '%')
    order by username
    limit 20
  ) p;
$$;

-- Sends a request; if they already asked me, this accepts it instead.
create or replace function public.send_friend_request(p_to uuid)
returns text language plpgsql security definer set search_path = public as $$
declare
  existing friendships;
begin
  if auth.uid() is null or p_to = auth.uid() then raise exception 'invalid'; end if;
  select * into existing from friendships
    where least(requester, addressee) = least(auth.uid(), p_to)
      and greatest(requester, addressee) = greatest(auth.uid(), p_to);
  if found then
    if existing.status = 'accepted' then return 'already_friends'; end if;
    if existing.addressee = auth.uid() then
      update friendships set status = 'accepted' where id = existing.id;
      return 'accepted';
    end if;
    return 'already_sent';
  end if;
  insert into friendships (requester, addressee) values (auth.uid(), p_to);
  return 'sent';
end;
$$;

create or replace function public.respond_friend_request(p_id bigint, p_accept boolean)
returns void language plpgsql security definer set search_path = public as $$
begin
  if p_accept then
    update friendships set status = 'accepted' where id = p_id and addressee = auth.uid() and status = 'pending';
  else
    delete from friendships where id = p_id and addressee = auth.uid() and status = 'pending';
  end if;
end;
$$;

-- Cancels a sent request or removes a friend.
create or replace function public.remove_friendship(p_id bigint)
returns void language sql security definer set search_path = public as $$
  delete from friendships where id = p_id and auth.uid() in (requester, addressee);
$$;

grant execute on function public.get_feed, public.get_user_posts, public.get_comments, public.get_friendships,
  public.search_profiles, public.send_friend_request, public.respond_friend_request, public.remove_friendship,
  public.are_friends, public.can_see, public.post_json to authenticated;

-- ---------------------------------------------------------------- photos

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('post-photos', 'post-photos', false, 5242880, array['image/jpeg', 'image/png', 'image/webp'])
on conflict (id) do nothing;

-- Files live at <user id>/<post id>.jpg
drop policy if exists "upload own photos" on storage.objects;
create policy "upload own photos" on storage.objects for insert to authenticated
  with check (bucket_id = 'post-photos' and (storage.foldername(name))[1] = auth.uid()::text);
drop policy if exists "delete own photos" on storage.objects;
create policy "delete own photos" on storage.objects for delete to authenticated
  using (bucket_id = 'post-photos' and (storage.foldername(name))[1] = auth.uid()::text);
drop policy if exists "friends see photos" on storage.objects;
create policy "friends see photos" on storage.objects for select to authenticated
  using (bucket_id = 'post-photos'
    and public.can_see(auth.uid(), ((storage.foldername(name))[1])::uuid));

-- ================================================================ stories
-- 24-hour stories: photos, or progress cards generated from the day's log.

create table if not exists public.stories (
  id          uuid primary key default gen_random_uuid(),
  author      uuid not null references public.profiles (id) on delete cascade,
  kind        text not null default 'photo' check (kind in ('photo', 'progress')),
  photo_path  text,
  caption     text not null default '' check (char_length(caption) <= 200),
  data        jsonb,
  recipe      jsonb,
  created_at  timestamptz not null default now(),
  expires_at  timestamptz not null default now() + interval '24 hours'
);
create index if not exists stories_author_time on public.stories (author, created_at desc);

create table if not exists public.story_views (
  story_id   uuid not null references public.stories (id) on delete cascade,
  viewer     uuid not null references public.profiles (id) on delete cascade,
  reaction   text check (reaction in ('😋', '🔥', '👏', '❤️', '💪', '😍')),
  viewed_at  timestamptz not null default now(),
  primary key (story_id, viewer)
);

alter table public.stories     enable row level security;
alter table public.story_views enable row level security;

drop policy if exists "see visible stories" on public.stories;
create policy "see visible stories" on public.stories for select to authenticated
  using (expires_at > now() and can_see(auth.uid(), author));
drop policy if exists "create own stories" on public.stories;
create policy "create own stories" on public.stories for insert to authenticated with check (author = auth.uid());
drop policy if exists "delete own stories" on public.stories;
create policy "delete own stories" on public.stories for delete to authenticated using (author = auth.uid());

-- Viewers only see their own view rows; authors read views via get_story_viewers.
drop policy if exists "own views" on public.story_views;
create policy "own views" on public.story_views for select to authenticated using (viewer = auth.uid());

-- Active stories from me and my friends, oldest first within each author.
create or replace function public.get_stories()
returns jsonb language sql stable security definer set search_path = public as $$
  select coalesce(jsonb_agg(jsonb_build_object(
      'id', s.id, 'kind', s.kind, 'photo_path', s.photo_path, 'caption', s.caption, 'data', s.data,
      'recipe', s.recipe, 'created_at', s.created_at, 'expires_at', s.expires_at,
      'author', (select to_jsonb(a) from profiles a where a.id = s.author),
      'viewed', exists (select 1 from story_views v where v.story_id = s.id and v.viewer = auth.uid()),
      'view_count', case when s.author = auth.uid()
                         then (select count(*) from story_views v where v.story_id = s.id) else null end
    ) order by s.created_at), '[]'::jsonb)
  from stories s
  where s.expires_at > now() and can_see(auth.uid(), s.author);
$$;

-- Marks a story seen (optionally with an emoji reaction).
create or replace function public.view_story(p_story uuid, p_reaction text default null)
returns void language plpgsql security definer set search_path = public as $$
begin
  if not exists (select 1 from stories s where s.id = p_story and s.expires_at > now()
                 and can_see(auth.uid(), s.author) and s.author <> auth.uid()) then
    return;
  end if;
  insert into story_views (story_id, viewer, reaction) values (p_story, auth.uid(), p_reaction)
  on conflict (story_id, viewer) do update set reaction = coalesce(excluded.reaction, story_views.reaction);
end;
$$;

-- Who saw my story (author only).
create or replace function public.get_story_viewers(p_story uuid)
returns jsonb language sql stable security definer set search_path = public as $$
  select coalesce(jsonb_agg(jsonb_build_object(
      'viewer', (select to_jsonb(p) from profiles p where p.id = v.viewer),
      'reaction', v.reaction, 'viewed_at', v.viewed_at
    ) order by v.viewed_at desc), '[]'::jsonb)
  from story_views v
  join stories s on s.id = v.story_id
  where v.story_id = p_story and s.author = auth.uid();
$$;

grant execute on function public.get_stories, public.view_story, public.get_story_viewers to authenticated;

-- ================================================================ lockdown
-- Only signed-in users may call these (Postgres grants EXECUTE to everyone by default).
revoke execute on function public.are_friends, public.can_see, public.post_json, public.get_feed,
  public.get_user_posts, public.get_comments, public.get_friendships, public.search_profiles,
  public.send_friend_request, public.respond_friend_request, public.remove_friendship,
  public.get_stories, public.view_story, public.get_story_viewers from public, anon;
grant execute on function public.are_friends, public.can_see, public.post_json, public.get_feed,
  public.get_user_posts, public.get_comments, public.get_friendships, public.search_profiles,
  public.send_friend_request, public.respond_friend_request, public.remove_friendship,
  public.get_stories, public.view_story, public.get_story_viewers to authenticated;

-- ================================================================ v3: avatars, categories, challenges

-- Profile photo + short bio.
alter table public.profiles add column if not exists avatar_url text;
alter table public.profiles add column if not exists bio text not null default '';
do $$ begin
  alter table public.profiles add constraint profiles_bio_len check (char_length(bio) <= 120);
exception when duplicate_object then null; end $$;

-- Posts about anything in life, not only food.
alter table public.posts add column if not exists category text not null default 'food';
alter table public.posts add column if not exists activity jsonb;
do $$ begin
  alter table public.posts add constraint posts_category_check
    check (category in ('food', 'workout', 'cardio', 'sleep', 'mind', 'milestone', 'life'));
exception when duplicate_object then null; end $$;

create or replace function public.post_json(p posts)
returns jsonb language sql stable security definer set search_path = public as $$
  select jsonb_build_object(
    'id', p.id, 'caption', p.caption, 'photo_path', p.photo_path, 'dish_name', p.dish_name,
    'emoji', p.emoji, 'kcal', p.kcal, 'protein', p.protein, 'recipe', p.recipe, 'created_at', p.created_at,
    'category', p.category, 'activity', p.activity,
    'author', (select to_jsonb(a) from profiles a where a.id = p.author),
    'reactions', coalesce((select jsonb_object_agg(emoji, n) from
        (select emoji, count(*) n from reactions r where r.post_id = p.id group by emoji) x), '{}'::jsonb),
    'my_reaction', (select emoji from reactions r where r.post_id = p.id and r.user_id = auth.uid()),
    'comment_count', (select count(*) from comments c where c.post_id = p.id)
  );
$$;

-- Avatars are public images (anyone signed in can see usernames anyway).
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('avatars', 'avatars', true, 2097152, array['image/jpeg', 'image/png', 'image/webp'])
on conflict (id) do nothing;
drop policy if exists "upload own avatar" on storage.objects;
create policy "upload own avatar" on storage.objects for insert to authenticated
  with check (bucket_id = 'avatars' and (storage.foldername(name))[1] = auth.uid()::text);
drop policy if exists "replace own avatar" on storage.objects;
create policy "replace own avatar" on storage.objects for update to authenticated
  using (bucket_id = 'avatars' and (storage.foldername(name))[1] = auth.uid()::text);
drop policy if exists "delete own avatar" on storage.objects;
create policy "delete own avatar" on storage.objects for delete to authenticated
  using (bucket_id = 'avatars' and (storage.foldername(name))[1] = auth.uid()::text);
drop policy if exists "read avatars" on storage.objects;
create policy "read avatars" on storage.objects for select to authenticated using (bucket_id = 'avatars');

-- Friend challenges: a daily check-in goal for N days.
create table if not exists public.challenges (
  id           uuid primary key default gen_random_uuid(),
  creator      uuid not null references public.profiles (id) on delete cascade,
  title        text not null check (char_length(title) between 2 and 60),
  emoji        text not null default '🏁',
  description  text not null default '' check (char_length(description) <= 200),
  days         int  not null check (days between 3 and 60),
  starts_on    date not null default current_date,
  created_at   timestamptz not null default now()
);

create table if not exists public.challenge_members (
  challenge_id uuid not null references public.challenges (id) on delete cascade,
  user_id      uuid not null references public.profiles (id) on delete cascade,
  joined_at    timestamptz not null default now(),
  primary key (challenge_id, user_id)
);

create table if not exists public.challenge_checkins (
  challenge_id uuid not null references public.challenges (id) on delete cascade,
  user_id      uuid not null references public.profiles (id) on delete cascade,
  day          date not null,
  created_at   timestamptz not null default now(),
  primary key (challenge_id, user_id, day)
);

alter table public.challenges         enable row level security;
alter table public.challenge_members  enable row level security;
alter table public.challenge_checkins enable row level security;

drop policy if exists "delete own challenges" on public.challenges;
create policy "delete own challenges" on public.challenges for delete to authenticated using (creator = auth.uid());
drop policy if exists "see visible challenges" on public.challenges;
create policy "see visible challenges" on public.challenges for select to authenticated
  using (can_see(auth.uid(), creator)
         or exists (select 1 from challenge_members m where m.challenge_id = id and m.user_id = auth.uid()));
-- Members and check-ins are read and written only through the functions below.

create or replace function public.get_challenges()
returns jsonb language sql stable security definer set search_path = public as $$
  select coalesce(jsonb_agg(jsonb_build_object(
      'id', c.id, 'title', c.title, 'emoji', c.emoji, 'description', c.description, 'days', c.days,
      'starts_on', c.starts_on, 'created_at', c.created_at, 'today', current_date,
      'creator', (select to_jsonb(p) from profiles p where p.id = c.creator),
      'joined', exists (select 1 from challenge_members m where m.challenge_id = c.id and m.user_id = auth.uid()),
      'my_days', coalesce((select jsonb_agg(k.day order by k.day) from challenge_checkins k
                           where k.challenge_id = c.id and k.user_id = auth.uid()), '[]'::jsonb),
      'members', coalesce((select jsonb_agg(jsonb_build_object(
            'profile', to_jsonb(p),
            'checkins', (select count(*) from challenge_checkins k where k.challenge_id = c.id and k.user_id = m.user_id),
            'today', exists (select 1 from challenge_checkins k where k.challenge_id = c.id
                             and k.user_id = m.user_id and k.day = current_date)
          ) order by m.joined_at)
          from challenge_members m join profiles p on p.id = m.user_id
          where m.challenge_id = c.id), '[]'::jsonb)
    ) order by c.starts_on desc, c.created_at desc), '[]'::jsonb)
  from challenges c
  where (exists (select 1 from challenge_members m where m.challenge_id = c.id and m.user_id = auth.uid())
         or can_see(auth.uid(), c.creator))
    and c.starts_on + c.days > current_date - 30;  -- hide long-finished ones
$$;

create or replace function public.create_challenge(p_title text, p_emoji text, p_description text, p_days int)
returns uuid language plpgsql security definer set search_path = public as $$
declare
  new_id uuid;
begin
  if auth.uid() is null then raise exception 'invalid'; end if;
  insert into challenges (creator, title, emoji, description, days)
    values (auth.uid(), trim(p_title), coalesce(nullif(p_emoji, ''), '🏁'), coalesce(p_description, ''), p_days)
    returning id into new_id;
  insert into challenge_members (challenge_id, user_id) values (new_id, auth.uid());
  return new_id;
end;
$$;

create or replace function public.join_challenge(p_id uuid)
returns void language plpgsql security definer set search_path = public as $$
begin
  if not exists (select 1 from challenges c where c.id = p_id
                 and c.starts_on + c.days > current_date and can_see(auth.uid(), c.creator)) then
    raise exception 'This challenge is over or not shared with you.';
  end if;
  insert into challenge_members (challenge_id, user_id) values (p_id, auth.uid()) on conflict do nothing;
end;
$$;

create or replace function public.leave_challenge(p_id uuid)
returns void language sql security definer set search_path = public as $$
  delete from challenge_checkins where challenge_id = p_id and user_id = auth.uid();
  delete from challenge_members where challenge_id = p_id and user_id = auth.uid();
$$;

revoke execute on function public.get_challenges, public.create_challenge, public.join_challenge,
  public.leave_challenge, public.post_json from public, anon;
grant execute on function public.get_challenges, public.create_challenge, public.join_challenge,
  public.leave_challenge, public.post_json to authenticated;

-- ================================================================ v4: photo-proof check-ins

alter table public.challenge_checkins add column if not exists photo_path text;
alter table public.challenge_checkins add column if not exists note text not null default '';

-- Friends vote on each other's proof: approve (legit) or not.
create table if not exists public.checkin_votes (
  challenge_id uuid not null,
  user_id      uuid not null,
  day          date not null,
  voter        uuid not null references public.profiles (id) on delete cascade,
  approve      boolean not null,
  created_at   timestamptz not null default now(),
  primary key (challenge_id, user_id, day, voter),
  foreign key (challenge_id, user_id, day)
    references public.challenge_checkins (challenge_id, user_id, day) on delete cascade
);
alter table public.checkin_votes enable row level security;
-- Read and written only through the functions below.

-- A check-in counts unless more friends rejected it than approved it.
create or replace function public.checkin_counts(p_challenge uuid, p_user uuid, p_day date)
returns boolean language sql stable security definer set search_path = public as $$
  select coalesce(sum(case when approve then 1 else -1 end), 0) >= 0
  from checkin_votes v where v.challenge_id = p_challenge and v.user_id = p_user and v.day = p_day;
$$;

create or replace function public.get_challenges()
returns jsonb language sql stable security definer set search_path = public as $$
  select coalesce(jsonb_agg(jsonb_build_object(
      'id', c.id, 'title', c.title, 'emoji', c.emoji, 'description', c.description, 'days', c.days,
      'starts_on', c.starts_on, 'created_at', c.created_at, 'today', current_date,
      'creator', (select to_jsonb(p) from profiles p where p.id = c.creator),
      'joined', exists (select 1 from challenge_members m where m.challenge_id = c.id and m.user_id = auth.uid()),
      'my_days', coalesce((select jsonb_agg(k.day order by k.day) from challenge_checkins k
                           where k.challenge_id = c.id and k.user_id = auth.uid()), '[]'::jsonb),
      'my_checkins', coalesce((select jsonb_agg(jsonb_build_object(
            'day', k.day,
            'yes', (select count(*) from checkin_votes v where v.challenge_id = k.challenge_id
                    and v.user_id = k.user_id and v.day = k.day and v.approve),
            'no', (select count(*) from checkin_votes v where v.challenge_id = k.challenge_id
                   and v.user_id = k.user_id and v.day = k.day and not v.approve)
          ) order by k.day)
          from challenge_checkins k where k.challenge_id = c.id and k.user_id = auth.uid()), '[]'::jsonb),
      'to_review', (select count(*) from challenge_checkins k
                    where k.challenge_id = c.id and k.user_id <> auth.uid() and k.day >= current_date - 2
                      and not exists (select 1 from checkin_votes v where v.challenge_id = k.challenge_id
                                      and v.user_id = k.user_id and v.day = k.day and v.voter = auth.uid())),
      'members', coalesce((select jsonb_agg(jsonb_build_object(
            'profile', to_jsonb(p),
            'checkins', (select count(*) from challenge_checkins k where k.challenge_id = c.id
                         and k.user_id = m.user_id and checkin_counts(c.id, m.user_id, k.day)),
            'today', exists (select 1 from challenge_checkins k where k.challenge_id = c.id
                             and k.user_id = m.user_id and k.day = current_date)
          ) order by m.joined_at)
          from challenge_members m join profiles p on p.id = m.user_id
          where m.challenge_id = c.id), '[]'::jsonb)
    ) order by c.starts_on desc, c.created_at desc), '[]'::jsonb)
  from challenges c
  where (exists (select 1 from challenge_members m where m.challenge_id = c.id and m.user_id = auth.uid())
         or can_see(auth.uid(), c.creator))
    and c.starts_on + c.days > current_date - 30;
$$;

-- Check in with proof (or undo today's check-in).
drop function if exists public.challenge_check_in(uuid, boolean);
create or replace function public.challenge_check_in(p_id uuid, p_done boolean, p_photo_path text default null,
                                                     p_note text default '')
returns void language plpgsql security definer set search_path = public as $$
begin
  if not exists (select 1 from challenge_members m join challenges c on c.id = m.challenge_id
                 where m.challenge_id = p_id and m.user_id = auth.uid()
                   and current_date between c.starts_on and c.starts_on + c.days - 1) then
    raise exception 'Join the challenge first (or it has ended).';
  end if;
  if p_done then
    insert into challenge_checkins (challenge_id, user_id, day, photo_path, note)
    values (p_id, auth.uid(), current_date, p_photo_path, left(coalesce(p_note, ''), 140))
    on conflict (challenge_id, user_id, day)
      do update set photo_path = excluded.photo_path, note = excluded.note;
  else
    delete from challenge_checkins where challenge_id = p_id and user_id = auth.uid() and day = current_date;
  end if;
end;
$$;

-- Friends' recent proofs I haven't voted on yet (each shown once).
create or replace function public.get_checkins_to_review(p_id uuid)
returns jsonb language sql stable security definer set search_path = public as $$
  select coalesce(jsonb_agg(jsonb_build_object(
      'challenge_id', k.challenge_id, 'user_id', k.user_id, 'day', k.day,
      'photo_path', k.photo_path, 'note', k.note, 'created_at', k.created_at,
      'profile', (select to_jsonb(p) from profiles p where p.id = k.user_id)
    ) order by k.created_at desc), '[]'::jsonb)
  from challenge_checkins k
  where k.challenge_id = p_id and k.user_id <> auth.uid() and k.day >= current_date - 2
    and exists (select 1 from challenge_members m where m.challenge_id = p_id and m.user_id = auth.uid())
    and not exists (select 1 from checkin_votes v where v.challenge_id = k.challenge_id
                    and v.user_id = k.user_id and v.day = k.day and v.voter = auth.uid());
$$;

create or replace function public.vote_checkin(p_id uuid, p_user uuid, p_day date, p_approve boolean)
returns void language plpgsql security definer set search_path = public as $$
begin
  if p_user = auth.uid()
     or not exists (select 1 from challenge_members m where m.challenge_id = p_id and m.user_id = auth.uid()) then
    raise exception 'Only other members can verify a check-in.';
  end if;
  insert into checkin_votes (challenge_id, user_id, day, voter, approve)
  values (p_id, p_user, p_day, auth.uid(), p_approve)
  on conflict (challenge_id, user_id, day, voter) do update set approve = excluded.approve;
end;
$$;

-- Proof photos live at <user>/checkins/<challenge>/<day>.jpg in post-photos;
-- every member of that challenge may view them.
drop policy if exists "members see proofs" on storage.objects;
create policy "members see proofs" on storage.objects for select to authenticated
  using (bucket_id = 'post-photos'
    and (storage.foldername(name))[2] = 'checkins'
    and exists (select 1 from public.challenge_members m
                where m.challenge_id::text = (storage.foldername(name))[3] and m.user_id = auth.uid()));

revoke execute on function public.checkin_counts, public.get_challenges, public.challenge_check_in,
  public.get_checkins_to_review, public.vote_checkin from public, anon;
grant execute on function public.checkin_counts, public.get_challenges, public.challenge_check_in,
  public.get_checkins_to_review, public.vote_checkin to authenticated;
