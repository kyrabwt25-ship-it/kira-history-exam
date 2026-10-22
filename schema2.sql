-- شغّله بعد schema.sql (إضافات النسخة 2: الإدارة + الدفع + المناهج)
alter table profiles add column if not exists banned boolean not null default false;

create table settings(key text primary key, value text not null default '');
insert into settings values
 ('persona','أنت KIRA AI، مساعد تعليمي للطلبة. تكلّم بلغة الطالب (العربية افتراضيًا) وبأسلوب يناسب عمره: بسيط ومرح لرياض الأطفال والابتدائي، ومفصّل أكثر للثانوي والجامعة. كن دقيقًا، وإن لم تتأكد قل ذلك، ولا تخترع مراجع أو أرقام صفحات. المحتوى مناسب للأطفال دائمًا. عند إرسال صورة حلّلها واشرح ما فيها أو حلّ المسألة.'),
 ('maintenance','');

create table payments(
  id uuid primary key default gen_random_uuid(),
  user_id uuid references profiles(id) on delete cascade,
  plan_id text references plans(id),
  period text check (period in ('weekly','monthly','yearly')),
  amount numeric default 0, status text not null default 'pending',
  method text, created_at timestamptz default now(), paid_at timestamptz);

create table documents(id bigserial primary key, title text not null, level text, subject text, created_at timestamptz default now());
create table chunks(
  id bigserial primary key, doc_id bigint references documents(id) on delete cascade,
  page int, content text not null, level text, subject text,
  tsv tsvector generated always as (to_tsvector('simple', content)) stored);
create index chunks_tsv on chunks using gin(tsv);

alter table settings enable row level security;
alter table payments enable row level security;
alter table documents enable row level security;
alter table chunks enable row level security;
-- بدون سياسات: الوصول من الخادم (service_role) فقط

create function search_chunks(p_query text, p_level text, p_subject text, p_n int)
returns table(title text, page int, content text) language sql stable security definer set search_path=public as $$
  select d.title, c.page, c.content from chunks c join documents d on d.id=c.doc_id
  where c.tsv @@ to_tsquery('simple', p_query)
    and (c.level is null or c.level=p_level) and (c.subject is null or c.subject=p_subject)
  order by ts_rank(c.tsv, to_tsquery('simple', p_query)) desc limit p_n $$;
revoke execute on function search_chunks from public, anon, authenticated;
grant execute on function search_chunks to service_role;

-- أنشئ نفسك مديرًا (غيّر البريد):
-- update profiles set role='admin' where email='you@example.com';
