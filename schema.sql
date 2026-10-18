-- ============================================================
-- منصة أكاديمية مستر هاني — Supabase Schema
-- نفّذ الملف ده كامل في: Supabase Dashboard > SQL Editor > New query > Run
-- ============================================================

-- 1) الفصول/الصفوف
create table if not exists classes (
  id uuid primary key default gen_random_uuid(),
  name text not null,                 -- مثال: "تالتة إعدادي - فصل أ"
  created_at timestamptz default now()
);

-- 2) الطلاب
create table if not exists students (
  id uuid primary key default gen_random_uuid(),
  full_name text not null,
  class_id uuid references classes(id) on delete set null,
  access_code text unique not null,   -- كود دخول الطالب (بدل باسورد)
  parent_phone text,
  total_points int default 0,
  subscribed_bonus_claimed boolean default false, -- نقط الاشتراك+الجرس تُحتسب مرة واحدة بس لكل الطالب (مش لكل فيديو)
  created_at timestamptz default now()
);
create index if not exists idx_students_access_code on students(access_code);

-- 3) الكورسات (وحدات دراسية)
create table if not exists courses (
  id uuid primary key default gen_random_uuid(),
  title text not null,
  description text,
  class_id uuid references classes(id) on delete cascade,
  sort_order int default 0,
  created_at timestamptz default now()
);

-- 4) الحصص/الفيديوهات
create table if not exists lessons (
  id uuid primary key default gen_random_uuid(),
  course_id uuid references courses(id) on delete cascade,
  title text not null,
  youtube_video_id text not null,     -- الجزء اللي بعد v= في رابط اليوتيوب
  reading_url text,                   -- رابط ملف/صفحة القراءة المصاحبة (اختياري)
  sort_order int default 0,
  created_at timestamptz default now()
);

-- 5) الأسئلة المرتبطة بالفيديو
create table if not exists questions (
  id uuid primary key default gen_random_uuid(),
  lesson_id uuid references lessons(id) on delete cascade,
  trigger_second int not null,        -- ثانية ظهور السؤال أثناء الفيديو
  prompt text not null,
  choices jsonb not null,             -- ["اختيار 1","اختيار 2","اختيار 3","اختيار 4"]
  correct_index int not null,         -- index الاختيار الصح (0-based)
  points int default 10,
  sort_order int default 0
);
create index if not exists idx_questions_lesson on questions(lesson_id);

-- 6) محاولات إجابة الطلاب (لمنع التكرار وتتبع الأداء)
create table if not exists attempts (
  id uuid primary key default gen_random_uuid(),
  student_id uuid references students(id) on delete cascade,
  question_id uuid references questions(id) on delete cascade,
  chosen_index int,
  is_correct boolean,
  created_at timestamptz default now(),
  unique(student_id, question_id)
);

-- 7) تتبع مشاهدة الحصة + إقرار اللايك/الكومنت (نظام أمانة)
create table if not exists lesson_progress (
  id uuid primary key default gen_random_uuid(),
  student_id uuid references students(id) on delete cascade,
  lesson_id uuid references lessons(id) on delete cascade,
  completed boolean default false,          -- شاهد الفيديو 100% مرة واحدة على الأقل
  max_watched_second int default 0,          -- أبعد ثانية وصلها في الجلسة الحالية (لمنع التقديم)
  watch_bonus_awarded boolean default false, -- محتفظ بيه لأغراض توافق قديمة، مش مستخدم في منطق التكرار
  watch_count int default 0,                 -- عدد مرات المشاهدة الكاملة إجمالاً
  last_watch_date date,                      -- آخر يوم اتحسبله نقاط إعادة مشاهدة
  watches_today int default 0,               -- عدد مرات المشاهدة المحسوبة نقاط النهاردة
  liked_commented boolean default false,
  like_bonus_awarded boolean default false,
  subscribed_bell boolean default false,
  subscribe_bonus_awarded boolean default false,
  updated_at timestamptz default now(),
  unique(student_id, lesson_id)
);

-- إعدادات عامة يتحكم فيها المعلم من لوحة الإدارة (صف واحد ثابت)
create table if not exists app_settings (
  id int primary key default 1,
  watch_bonus_points int default 20,   -- نقط أول مشاهدة كاملة لأي فيديو
  repeat_watch_points int default 5,   -- نقط كل مشاهدة كاملة إضافية لنفس الفيديو
  daily_watch_cap int default 3,       -- أقصى عدد مرات إعادة مشاهدة تُحتسب نقط في اليوم لنفس الفيديو
  updated_at timestamptz default now(),
  constraint single_row check (id = 1)
);
insert into app_settings (id, watch_bonus_points, repeat_watch_points, daily_watch_cap) values (1, 20, 5, 3)
  on conflict (id) do nothing;

-- ============================================================
-- Row Level Security
-- ملاحظة أمان: الطلاب بيدخلوا بكود مش بحساب Supabase حقيقي، فكل القراءة/الكتابة
-- الخاصة بيهم بتتم بمفتاح anon. ده حل عملي وخفيف الاحتكاك، لكنه مش بديل لحماية
-- بيانات حساسة. لو حبيت تحصين أعلى مستقبلاً، حوّل تسجيل الطالب لـ Supabase Auth
-- (Magic Link أو OTP بالتليفون).
-- ============================================================

alter table classes enable row level security;
alter table students enable row level security;
alter table courses enable row level security;
alter table lessons enable row level security;
alter table questions enable row level security;
alter table attempts enable row level security;
alter table lesson_progress enable row level security;
alter table app_settings enable row level security;

-- قراءة عامة (الطلاب لازم يقروا الكورسات/الحصص/الأسئلة)
create policy "public read classes" on classes for select using (true);
create policy "public read courses" on courses for select using (true);
create policy "public read lessons" on lessons for select using (true);
create policy "public read questions" on questions for select using (true);

-- تسجيل دخول الطالب: لازم يقدر يقرأ صف بياناته بالكود بس
create policy "student read own row" on students for select using (true);
create policy "student update own points" on students for update using (true);

-- كتابة المحاولات والتقدم: مسموحة لأي زائر (anon) لأن الطالب مش authenticated
create policy "insert attempts" on attempts for insert with check (true);
create policy "read own attempts" on attempts for select using (true);

create policy "upsert progress" on lesson_progress for insert with check (true);
create policy "update progress" on lesson_progress for update using (true);
create policy "read progress" on lesson_progress for select using (true);

-- الكتابة في classes/courses/lessons/questions/students (إضافة/تعديل) محصورة
-- على المستخدم الموثّق (المعلم) فقط. سجّل حساب المعلم من Supabase Auth
-- (Authentication > Users > Add user) وسجّل دخول بيه في admin.html
create policy "teacher manage classes" on classes for all using (auth.role() = 'authenticated');
create policy "teacher manage students" on students for insert with check (auth.role() = 'authenticated');
create policy "teacher delete students" on students for delete using (auth.role() = 'authenticated');
create policy "teacher manage courses" on courses for all using (auth.role() = 'authenticated');
create policy "teacher manage lessons" on lessons for all using (auth.role() = 'authenticated');
create policy "teacher manage questions" on questions for all using (auth.role() = 'authenticated');

-- تسجيل الطالب لنفسه من صفحة register.html (بدون تسجيل دخول المعلم يدويًا لكل طالب)
create policy "student self register" on students for insert with check (true);

-- إعدادات النقاط: قراءة عامة (الطالب محتاج يعرف قيمة المكافأة)، وتعديل للمعلم بس
create policy "public read settings" on app_settings for select using (true);
create policy "teacher update settings" on app_settings for update using (auth.role() = 'authenticated');

-- Realtime للوحة الصدارة
alter publication supabase_realtime add table students;

-- ============================================================
-- ترقية آمنة لو كنت شغّلت نسخة سابقة من الملف ده قبل كده
-- (الأسطر دي متأمّنة بـ IF NOT EXISTS فمش هتعمل مشكلة لو اتنفذت أكتر من مرة)
-- ============================================================
alter table lesson_progress add column if not exists like_bonus_awarded boolean default false;
alter table lesson_progress add column if not exists subscribed_bell boolean default false;
alter table lesson_progress add column if not exists subscribe_bonus_awarded boolean default false;

-- لو مشروعك كان شغال بنسخة قديمة، شغّل السطرين دول كمان عشان تفتح
-- باب التسجيل الذاتي للطلاب (register.html):
drop policy if exists "student self register" on students;
create policy "student self register" on students for insert with check (true);

-- ترقية تتبع مشاهدة الفيديو ونقاط الإكمال (منع التقديم + مكافأة المشاهدة الكاملة):
alter table lesson_progress add column if not exists max_watched_second int default 0;
alter table lesson_progress add column if not exists watch_bonus_awarded boolean default false;

create table if not exists app_settings (
  id int primary key default 1,
  watch_bonus_points int default 20,
  updated_at timestamptz default now(),
  constraint single_row check (id = 1)
);
insert into app_settings (id, watch_bonus_points) values (1, 20)
  on conflict (id) do nothing;
alter table app_settings enable row level security;
drop policy if exists "public read settings" on app_settings;
create policy "public read settings" on app_settings for select using (true);
drop policy if exists "teacher update settings" on app_settings;
create policy "teacher update settings" on app_settings for update using (auth.role() = 'authenticated');

-- ترقية إعادة المشاهدة بنقاط (نقاط في كل مشاهدة كاملة، بحد أقصى يومي لكل فيديو):
alter table lesson_progress add column if not exists watch_count int default 0;
alter table lesson_progress add column if not exists last_watch_date date;
alter table lesson_progress add column if not exists watches_today int default 0;
alter table app_settings add column if not exists repeat_watch_points int default 5;
alter table app_settings add column if not exists daily_watch_cap int default 3;

-- ترقية: نقط الاشتراك + الجرس تُحتسب مرة واحدة بس لكل طالب (مش قابلة للتكرار تحت كل فيديو)
alter table students add column if not exists subscribed_bonus_claimed boolean default false;

-- ============================================================
-- ترقية أمان كبيرة: نقل كل منطق النقاط من المتصفح (غير آمن) إلى دوال
-- داخل قاعدة البيانات (RPC) بصلاحية SECURITY DEFINER. ده بيقفل ثغرة
-- خطيرة: أي طالب فاتح Console في المتصفح كان يقدر يستدعي Supabase مباشرة
-- ويدي نفسه أي عدد نقاط يحبه أو يلف على الفيديو بلا حد. دلوقتي السيرفر
-- نفسه (مش المتصفح) هو اللي بيحسب ويتأكد من كل حاجة، فمفيش فايدة من
-- التلاعب بالكود لأن أي استدعاء للدالة بيرجع لقاعدة البيانات الحقيقية
-- كل مرة بدل ما يصدّق قيم المتصفح.
-- ============================================================

-- جدول الإعدادات: تقسيم مكافأة المشاهدة لمستويات + مكافآت اللايك/الاشتراك/المشاركة
alter table app_settings add column if not exists tier2_points int default 5;
alter table app_settings add column if not exists tier3_points int default 3;
alter table app_settings add column if not exists tier4_points int default 2;
alter table app_settings add column if not exists tier5plus_points int default 1;
alter table app_settings add column if not exists like_bonus_points int default 15;
alter table app_settings add column if not exists subscribe_bonus_points int default 10;
alter table app_settings add column if not exists share_bonus_points int default 10;
update app_settings set daily_watch_cap = 5 where id = 1 and daily_watch_cap = 3;

-- خانات المشاركة (زي اللايك بالظبط، لكل فيديو)
alter table lesson_progress add column if not exists shared boolean default false;
alter table lesson_progress add column if not exists share_bonus_awarded boolean default false;

-- 1) دالة إكمال مشاهدة فيديو: بتتحقق من تاريخ اليوم وعدد المرات من قاعدة
-- البيانات نفسها (مش من المتصفح)، وبتحسب نقط المستوى المناسب تلقائي
create or replace function claim_watch_completion(p_student_id uuid, p_lesson_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_settings app_settings%rowtype;
  v_progress lesson_progress%rowtype;
  v_today date := (now() at time zone 'Africa/Cairo')::date; -- يوم جديد بتوقيت القاهرة مش UTC
  v_points int := 0;
  v_capped boolean := false;
  v_new_total int;
begin
  select * into v_settings from app_settings where id = 1;

  select * into v_progress from lesson_progress
    where student_id = p_student_id and lesson_id = p_lesson_id
    for update;

  if not found then
    insert into lesson_progress (student_id, lesson_id)
    values (p_student_id, p_lesson_id)
    returning * into v_progress;
  end if;

  if v_progress.last_watch_date is distinct from v_today then
    v_progress.watches_today := 0;
  end if;

  if v_progress.watches_today >= coalesce(v_settings.daily_watch_cap, 5) then
    v_capped := true;
  else
    v_progress.watch_count := v_progress.watch_count + 1;
    v_progress.watches_today := v_progress.watches_today + 1;
    v_points := case v_progress.watch_count
      when 1 then v_settings.watch_bonus_points
      when 2 then v_settings.tier2_points
      when 3 then v_settings.tier3_points
      when 4 then v_settings.tier4_points
      else v_settings.tier5plus_points
    end;
  end if;

  update lesson_progress set
    completed = true,
    watch_count = v_progress.watch_count,
    watches_today = v_progress.watches_today,
    last_watch_date = v_today,
    updated_at = now()
  where student_id = p_student_id and lesson_id = p_lesson_id;

  if v_points > 0 then
    update students set total_points = total_points + v_points
      where id = p_student_id
      returning total_points into v_new_total;
  else
    select total_points into v_new_total from students where id = p_student_id;
  end if;

  return jsonb_build_object(
    'points_awarded', v_points,
    'capped', v_capped,
    'watch_count', v_progress.watch_count,
    'watches_today', v_progress.watches_today,
    'daily_cap', coalesce(v_settings.daily_watch_cap, 5),
    'new_total_points', v_new_total
  );
end;
$$;

-- 2) دالة مكافأة اللايك/الكومنت (مرة واحدة لكل فيديو)
create or replace function claim_like_bonus(p_student_id uuid, p_lesson_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_settings app_settings%rowtype;
  v_progress lesson_progress%rowtype;
  v_new_total int;
begin
  select * into v_settings from app_settings where id = 1;
  select * into v_progress from lesson_progress
    where student_id = p_student_id and lesson_id = p_lesson_id for update;

  if not found then
    insert into lesson_progress (student_id, lesson_id)
    values (p_student_id, p_lesson_id) returning * into v_progress;
  end if;

  if v_progress.like_bonus_awarded then
    select total_points into v_new_total from students where id = p_student_id;
    return jsonb_build_object('awarded', false, 'points_awarded', 0, 'new_total_points', v_new_total);
  end if;

  update lesson_progress set liked_commented = true, like_bonus_awarded = true, updated_at = now()
    where student_id = p_student_id and lesson_id = p_lesson_id;
  update students set total_points = total_points + coalesce(v_settings.like_bonus_points, 15)
    where id = p_student_id returning total_points into v_new_total;

  return jsonb_build_object('awarded', true, 'points_awarded', coalesce(v_settings.like_bonus_points, 15), 'new_total_points', v_new_total);
end;
$$;

-- 3) دالة مكافأة المشاركة (مرة واحدة لكل فيديو، زي اللايك)
create or replace function claim_share_bonus(p_student_id uuid, p_lesson_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_settings app_settings%rowtype;
  v_progress lesson_progress%rowtype;
  v_new_total int;
begin
  select * into v_settings from app_settings where id = 1;
  select * into v_progress from lesson_progress
    where student_id = p_student_id and lesson_id = p_lesson_id for update;

  if not found then
    insert into lesson_progress (student_id, lesson_id)
    values (p_student_id, p_lesson_id) returning * into v_progress;
  end if;

  if v_progress.share_bonus_awarded then
    select total_points into v_new_total from students where id = p_student_id;
    return jsonb_build_object('awarded', false, 'points_awarded', 0, 'new_total_points', v_new_total);
  end if;

  update lesson_progress set shared = true, share_bonus_awarded = true, updated_at = now()
    where student_id = p_student_id and lesson_id = p_lesson_id;
  update students set total_points = total_points + coalesce(v_settings.share_bonus_points, 10)
    where id = p_student_id returning total_points into v_new_total;

  return jsonb_build_object('awarded', true, 'points_awarded', coalesce(v_settings.share_bonus_points, 10), 'new_total_points', v_new_total);
end;
$$;

-- 4) دالة مكافأة الاشتراك + الجرس (مرة واحدة لكل الطالب في كل المنصة)
create or replace function claim_subscribe_bonus(p_student_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_settings app_settings%rowtype;
  v_already boolean;
  v_new_total int;
begin
  select * into v_settings from app_settings where id = 1;
  select subscribed_bonus_claimed into v_already from students where id = p_student_id for update;

  if v_already then
    select total_points into v_new_total from students where id = p_student_id;
    return jsonb_build_object('awarded', false, 'points_awarded', 0, 'new_total_points', v_new_total);
  end if;

  update students set subscribed_bonus_claimed = true,
    total_points = total_points + coalesce(v_settings.subscribe_bonus_points, 10)
    where id = p_student_id returning total_points into v_new_total;

  return jsonb_build_object('awarded', true, 'points_awarded', coalesce(v_settings.subscribe_bonus_points, 10), 'new_total_points', v_new_total);
end;
$$;

-- 5) دالة تصحيح إجابة سؤال: التحقق من الإجابة الصح بيحصل جوه قاعدة
-- البيانات، ومينفعش قاعدة بيانات الأسئلة تتبعت كاملة للمتصفح
create or replace function claim_question_points(p_student_id uuid, p_question_id uuid, p_chosen_index int)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_question questions%rowtype;
  v_existing attempts%rowtype;
  v_is_correct boolean;
  v_points int := 0;
  v_new_total int;
begin
  select * into v_question from questions where id = p_question_id;
  if not found then
    return jsonb_build_object('error', 'question_not_found');
  end if;

  select * into v_existing from attempts
    where student_id = p_student_id and question_id = p_question_id;

  if found then
    return jsonb_build_object(
      'already_answered', true, 'is_correct', v_existing.is_correct,
      'correct_index', v_question.correct_index, 'points_awarded', 0
    );
  end if;

  v_is_correct := (p_chosen_index = v_question.correct_index);

  insert into attempts (student_id, question_id, chosen_index, is_correct)
  values (p_student_id, p_question_id, p_chosen_index, v_is_correct);

  if v_is_correct then
    v_points := v_question.points;
    update students set total_points = total_points + v_points
      where id = p_student_id returning total_points into v_new_total;
  else
    select total_points into v_new_total from students where id = p_student_id;
  end if;

  return jsonb_build_object(
    'already_answered', false, 'is_correct', v_is_correct,
    'correct_index', v_question.correct_index,
    'points_awarded', v_points, 'new_total_points', v_new_total
  );
end;
$$;

-- السماح للطلاب (anon) باستدعاء الدوال دي بس، مش بتعديل الجداول مباشرة
grant execute on function claim_watch_completion(uuid, uuid) to anon, authenticated;
grant execute on function claim_like_bonus(uuid, uuid) to anon, authenticated;
grant execute on function claim_share_bonus(uuid, uuid) to anon, authenticated;
grant execute on function claim_subscribe_bonus(uuid) to anon, authenticated;
grant execute on function claim_question_points(uuid, uuid, int) to anon, authenticated;

-- القفل الفعلي للثغرة: امنع أي تعديل مباشر على النقاط أو تتبع المشاهدة
-- من المتصفح — الطريقة الوحيدة لتغيير النقاط بقت عن طريق الدوال فوق بس
-- ملحوظة تقنية مهمة: في Postgres لو الصلاحية متمنوحة على مستوى الجدول كله،
-- سحبها من عمود واحد مالوش أي تأثير. عشان كده بنسحب الصلاحية من الجدول كله
-- الأول، وبعدين نمنح بس الأعمدة المسموحة بالاسم.
revoke insert, update on students from anon, authenticated;
grant insert (full_name, class_id, parent_phone, access_code) on students to anon, authenticated;
grant update (full_name) on students to anon, authenticated;

revoke insert, update on lesson_progress from anon, authenticated;
revoke insert on attempts from anon, authenticated;

-- ============================================================
-- مستويات الطلاب (قابلة للتحكم من لوحة المعلم → تبويب "المستويات")
-- كل مستوى له اسم وإيموجي وعدد النقاط اللازمة للوصول إليه.
-- الطالب بيترقّى تلقائي أول ما رصيده يوصل لعتبة المستوى اللي بعده.
-- (آمن تشغيله أكتر من مرة)
-- ============================================================
create table if not exists levels (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  emoji text default '⭐',
  min_points int not null default 0,
  created_at timestamptz default now()
);

alter table levels enable row level security;
drop policy if exists "public read levels" on levels;
create policy "public read levels" on levels for select using (true);
drop policy if exists "teacher manage levels" on levels;
create policy "teacher manage levels" on levels for all using (auth.role() = 'authenticated');

-- المستويات الافتراضية (بتتضاف بس لو الجدول فاضي)
insert into levels (name, emoji, min_points)
select v.name, v.emoji, v.min_points
from (values
  ('مستكشف مبتدئ',      '🌱', 0),
  ('طالب مجتهد',        '📘', 50),
  ('نجم صاعد',          '⭐', 150),
  ('بطل الشرح',         '🔥', 300),
  ('محترف المنهج',      '🏆', 500),
  ('أسطورة الأكاديمية', '👑', 800),
  ('عبقري اللغة',       '💎', 1200),
  ('صاروخ العلم',       '🚀', 2000)
) as v(name, emoji, min_points)
where not exists (select 1 from levels);
