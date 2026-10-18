// ============================================================
// بيانات مشروع Supabase بتاعك (مفتاح anon عام بطبيعته ومش سري)
// ملاحظة: الملف ده جاهز بمفاتيحك، فمتغيّرش فيه حاجة
// ============================================================
const SUPABASE_URL = "https://kiwtoolwyanqrxpkwxhs.supabase.co";
const SUPABASE_ANON_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imtpd3Rvb2x3eWFucXJ4cGt3eGhzIiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTAxOTcwMjUsImV4cCI6MjEwNTc3MzAyNX0.8HJ-n-7Zyf_Kns3nDYu9taaRY_nBZCd1ho1O5scWqTE";

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
