// ============================================================
// حط بيانات مشروع Supabase بتاعك هنا (Project Settings > API)
// ============================================================
const SUPABASE_URL = "PUT_YOUR_SUPABASE_URL_HERE";       // مثال: https://xxxxx.supabase.co
const SUPABASE_ANON_KEY = "PUT_YOUR_SUPABASE_ANON_KEY_HERE";

const supabaseClient = window.supabase.createClient(SUPABASE_URL, SUPABASE_ANON_KEY);

// ---- أدوات الجلسة المحلية (بدل باسورد حقيقي) ----
function saveSession(student) {
  localStorage.setItem("mha_student", JSON.stringify(student));
}
function getSession() {
  const raw = localStorage.getItem("mha_student");
  return raw ? JSON.parse(raw) : null;
}
function clearSession() {
  localStorage.removeItem("mha_student");
}
function requireSession() {
  const s = getSession();
  if (!s) window.location.href = "index.html";
  return s;
}

// ---- نظام المستويات (زي الألعاب) ----
// المستويات بتتحمّل من قاعدة البيانات (المعلم بيعدّلها من لوحة التحكم)،
// والقايمة دي احتياطي بس لو التحميل فشل
const DEFAULT_LEVELS = [
  { min: 0,    name: "مستكشف مبتدئ",   emoji: "🌱" },
  { min: 50,   name: "طالب مجتهد",     emoji: "📘" },
  { min: 150,  name: "نجم صاعد",       emoji: "⭐" },
  { min: 300,  name: "بطل الشرح",      emoji: "🔥" },
  { min: 500,  name: "محترف المنهج",   emoji: "🏆" },
  { min: 800,  name: "أسطورة الأكاديمية", emoji: "👑" },
  { min: 1200, name: "عبقري اللغة",    emoji: "💎" },
  { min: 2000, name: "صاروخ العلم",    emoji: "🚀" },
];
let LEVELS = DEFAULT_LEVELS;

async function loadLevels() {
  try {
    const { data, error } = await supabaseClient
      .from("levels").select("name, emoji, min_points").order("min_points");
    if (!error && data && data.length) {
      LEVELS = data.map(l => ({ min: l.min_points, name: l.name, emoji: l.emoji || "⭐" }));
    }
  } catch (e) { /* نستخدم المستويات الافتراضية */ }
}

function getLevelInfo(points) {
  points = points || 0;
  let levelIndex = 0;
  for (let i = 0; i < LEVELS.length; i++) {
    if (points >= LEVELS[i].min) levelIndex = i;
  }
  const level = LEVELS[levelIndex];
  const next = LEVELS[levelIndex + 1] || null;
  const progressPercent = next
    ? Math.min(100, Math.round(((points - level.min) / (next.min - level.min)) * 100))
    : 100;
  return {
    levelNumber: levelIndex + 1,
    name: level.name,
    emoji: level.emoji,
    nextName: next ? next.name : null,
    pointsToNext: next ? next.min - points : 0,
    progressPercent
  };
}
