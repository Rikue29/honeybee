-- Create a table to store community content metadata
create table public.community_content (
    id uuid default uuid_generate_v4() primary key,
    poi_id uuid references points_of_interest(id) on delete cascade,
    user_id uuid references auth.users(id) on delete cascade,
    content_type text not null check (content_type in ('photo', 'video')),
    storage_path text not null,
    title text,
    description text,
    likes_count integer default 0,
    created_at timestamp with time zone default timezone('utc'::text, now()) not null,
    updated_at timestamp with time zone default timezone('utc'::text, now()) not null
);

-- Enable RLS on community_content table
alter table public.community_content enable row level security;

-- Create policies for community_content table
create policy "Community content is viewable by everyone"
on public.community_content for select
to public
using (true);

create policy "Users can insert their own content"
on public.community_content for insert
to authenticated
with check (auth.uid() = user_id);

create policy "Users can update their own content"
on public.community_content for update
to authenticated
using (auth.uid() = user_id)
with check (auth.uid() = user_id);

create policy "Users can delete their own content"
on public.community_content for delete
to authenticated
using (auth.uid() = user_id);

-- Create a table for likes
create table public.community_content_likes (
    content_id uuid references community_content(id) on delete cascade,
    user_id uuid references auth.users(id) on delete cascade,
    created_at timestamp with time zone default timezone('utc'::text, now()) not null,
    primary key (content_id, user_id)
);

-- Enable RLS on likes table
alter table public.community_content_likes enable row level security;

-- Create policies for likes table
create policy "Users can view all likes"
on public.community_content_likes for select
to public
using (true);

create policy "Users can insert their own likes"
on public.community_content_likes for insert
to authenticated
with check (auth.uid() = user_id);

create policy "Users can delete their own likes"
on public.community_content_likes for delete
to authenticated
using (auth.uid() = user_id);

-- Create function to update likes count
create or replace function public.handle_community_content_likes()
returns trigger
language plpgsql
security definer
as $$
begin
  if (TG_OP = 'INSERT') then
    update public.community_content
    set likes_count = likes_count + 1
    where id = NEW.content_id;
    return NEW;
  elsif (TG_OP = 'DELETE') then
    update public.community_content
    set likes_count = likes_count - 1
    where id = OLD.content_id;
    return OLD;
  end if;
  return null;
end;
$$;

-- Create trigger for likes
create trigger on_community_content_like
  after insert or delete
  on public.community_content_likes
  for each row
  execute function public.handle_community_content_likes(); 