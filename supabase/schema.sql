-- NOVA SHOP schema. Apply to the NEW NOVA SHOP Supabase project only.
create table if not exists public.shop_admins (
  user_id uuid primary key references auth.users(id) on delete cascade
);
create table if not exists public.shop_products (
  id bigint generated always as identity primary key,
  name text not null check (length(trim(name)) between 1 and 160),
  category text not null default 'Бусад',
  price_mnt integer not null check (price_mnt >= 0),
  image_url text,
  stock integer not null default 0 check (stock >= 0),
  active boolean not null default true,
  created_at timestamptz not null default now()
);
alter table public.shop_admins enable row level security;
alter table public.shop_products enable row level security;
revoke all on public.shop_admins from anon, authenticated;
grant select on public.shop_admins to authenticated;
grant select on public.shop_products to anon, authenticated;
grant insert, update, delete on public.shop_products to authenticated;
create policy "admins read own membership" on public.shop_admins
  for select to authenticated using (user_id = (select auth.uid()));
create policy "public read active products" on public.shop_products
  for select to anon, authenticated
  using (active = true or exists (select 1 from public.shop_admins a where a.user_id = (select auth.uid())));
create policy "admins add products" on public.shop_products
  for insert to authenticated with check (exists (select 1 from public.shop_admins a where a.user_id = (select auth.uid())));
create policy "admins update products" on public.shop_products
  for update to authenticated
  using (exists (select 1 from public.shop_admins a where a.user_id = (select auth.uid())))
  with check (exists (select 1 from public.shop_admins a where a.user_id = (select auth.uid())));
create policy "admins delete products" on public.shop_products
  for delete to authenticated using (exists (select 1 from public.shop_admins a where a.user_id = (select auth.uid())));
-- Bootstrap admin only from Supabase SQL Editor after signing up:
-- insert into public.shop_admins(user_id) values ('YOUR_AUTH_USER_UUID');
