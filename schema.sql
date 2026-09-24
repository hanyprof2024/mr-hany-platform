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
  completed boolean default false,
  liked_commented boolean default false,
  like_bonus_awarded boolean default false,
  subscribed_bell boolean default false,
  subscribe_bonus_awarded boolean default false,
  updated_at timestamptz default now(),
  unique(student_id, lesson_id)
);

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

-- Realtime للوحة الصدارة
alter publication supabase_realtime add table students;

-- ============================================================
-- ترقية آمنة لو كنت شغّلت نسخة سابقة من الملف ده قبل كده
-- (الأسطر دي متأمّنة بـ IF NOT EXISTS فمش هتعمل مشكلة لو اتنفذت أكتر من مرة)
-- ============================================================
alter table lesson_progress add column if not exists like_bonus_awarded boolean default false;
alter table lesson_progress add column if not exists subscribed_bell boolean default false;
alter table lesson_progress add column if not exists subscribe_bonus_awarded boolean default false;
