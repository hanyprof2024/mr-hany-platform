// ============================================================
// حط بيانات مشروع Supabase بتاعك هنا (Project Settings > API)
// ============================================================
const SUPABASE_URL = "https://kiwtoolwyanqrxpkwxhs.supabase.co";       // مثال: https://xxxxx.supabase.co
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
