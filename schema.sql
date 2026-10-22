-- شغّل هذا الملف كاملًا في Supabase > SQL Editor

create table plans(
  id text primary key, name text not null, model text not null,
  daily_messages int not null, daily_images int not null, max_tokens int not null,
  style_rule text not null default '', sort int not null default 0,
  price_weekly numeric default 0, price_monthly numeric default 0, price_yearly numeric default 0
);
insert into plans(id,name,model,daily_messages,daily_images,max_tokens,style_rule,sort) values
('free','Free','claude-haiku-5-5',20,3,500,'أجب باختصار شديد وبدون حلول معقدة أو تفصيل طويل. وإن احتاج السؤال شرحًا أعمق فاذكر أن باقات KIRA المدفوعة تعطي شرحًا كاملًا.',0),
('plus','Plus','claude-sonnet-5-5',100,15,1500,'اشرح بالتفصيل مع خطوات الحل.',1),
('pro','Pro','claude-opus-5-5',300,50,3000,'قدّم تحليلًا عميقًا وحلولًا كاملة للمسائل الصعبة.',2),
('ultra','Ultra','claude-opus-5-5',1000,150,4000,'أعلى جودة: تحليل معمّق وأمثلة وتحقق من الحل.',3);

create table profiles(
  id uuid primary key references auth.users on delete cascade,
  email text, plan_id text not null default 'free' references plans(id),
  plan_expires_at timestamptz, role text not null default 'user',
  created_at timestamptz default now()
);
create table usage(
  user_id uuid references auth.users on delete cascade, day date,
  messages int not null default 0, images int not null default 0,
  primary key(user_id, day)
);

alter table plans enable row level security;
alter table profiles enable row level security;
alter table usage enable row level security;
create policy "plans readable" on plans for select using (true);
create policy "own profile" on profiles for select using (auth.uid() = id);
create policy "own usage" on usage for select using (auth.uid() = user_id);

-- إنشاء ملف المستخدم تلقائيًا عند التسجيل
create function handle_new_user() returns trigger language plpgsql security definer set search_path=public as $$
begin insert into profiles(id,email) values(new.id,new.email); return new; end $$;
create trigger on_auth_user_created after insert on auth.users
for each row execute function handle_new_user();

-- عدّاد الاستخدام اليومي (ذرّي وآمن)
create function bump_usage(p_user uuid, p_images int, p_max_msgs int, p_max_imgs int)
returns text language plpgsql security definer set search_path=public as $$
declare r usage;
begin
  insert into usage(user_id, day) values(p_user, current_date) on conflict do nothing;
  select * into r from usage where user_id=p_user and day=current_date for update;
  if r.messages >= p_max_msgs then return 'messages'; end if;
  if p_images > 0 and r.images + p_images > p_max_imgs then return 'images'; end if;
  update usage set messages=messages+1, images=images+p_images where user_id=p_user and day=current_date;
  return 'ok';
end $$;
revoke execute on function bump_usage from public, anon, authenticated;
grant execute on function bump_usage to service_role;
