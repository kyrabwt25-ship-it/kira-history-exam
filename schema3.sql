-- شغّله بعد schema.sql و schema2.sql (النسخة 3: معلمون + فودافون كاش + إعلانات + مطوّر تلقائي)
alter table profiles add column if not exists account_type text not null default 'student';
alter table plans add column if not exists kind text not null default 's';
alter table payments add column if not exists from_number text;
alter table payments add column if not exists tx text;

create table announcements(id bigserial primary key, text text not null, created_at timestamptz default now());
alter table announcements enable row level security;

-- باقات المعلمين: ضعف الحدود ونموذج أقوى (الأسعار تضاعفها بالأمر الموجود في README بعد تحديد أسعار الطلاب)
insert into plans(id,name,model,daily_messages,daily_images,max_tokens,style_rule,sort,kind) values
('tfree','Teacher Free','claude-sonnet-5-5',20,3,800,'أجب بإيجاز مفيد للمعلم مع أبرز النقاط العملية، واذكر أن باقات المعلمين المدفوعة تعطي تفصيلًا كاملًا.',10,'t'),
('tplus','Teacher Plus','claude-opus-5-5',120,30,3000,'قدّم إجابات احترافية مفصلة بضعف التفصيل المعتاد مع أمثلة وطرق تدريس وأساليب تقويم.',11,'t'),
('tpro','Teacher Pro','claude-opus-5-5',300,100,4000,'تحليل عميق ومواد تعليمية كاملة جاهزة للاستخدام في الفصل.',12,'t'),
('tultra','Teacher Ultra','claude-opus-5-5',800,300,5000,'أعلى جودة: مواد تعليمية متكاملة وتحقق من الدقة وتنويع للمستويات.',13,'t');

-- المطوّر: يصبح مديرًا تلقائيًا عند التسجيل ببريده (فعّل Confirm email في Supabase!)
create or replace function handle_new_user() returns trigger language plpgsql security definer set search_path=public as $$
begin
  insert into profiles(id,email,role) values(new.id,new.email,
    case when lower(new.email)='kyrabwt22@gmail.com' then 'admin' else 'user' end);
  return new;
end $$;
update profiles set role='admin' where lower(email)='kyrabwt22@gmail.com';

-- الحل المباشر هو الافتراضي
update settings set value = value || ' عندما يطلب الطالب حلّ سؤال فحلّه بالكامل مباشرة مع الخطوات ولا تطلب منه أن يحلّه بنفسه، إلا إذا اختار وضع المعلم.' where key='persona';

-- بعد تحديد أسعار باقات الطلاب شغّل هذا لمضاعفتها للمعلمين:
-- update plans t set price_weekly=s.price_weekly*2, price_monthly=s.price_monthly*2, price_yearly=s.price_yearly*2
--   from plans s where t.id='t'||s.id and s.id in ('plus','pro','ultra');
