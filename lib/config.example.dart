// Vorlage für die Zugangsdaten zu Supabase.
//
// 1. Diese Datei nach lib/config.dart kopieren.
// 2. Werte aus dem Supabase-Dashboard eintragen:
//    Project Settings → API Keys: Project URL und der "anon public" Key
//    (oder der neue "publishable" Key, beginnt mit sb_publishable_).
//    NIEMALS den "service_role"/"secret" Key verwenden!
//
// lib/config.dart steht in .gitignore und wird nie committet.

class AppConfig {
  static const supabaseUrl = 'https://DEIN-PROJEKT.supabase.co';
  static const supabaseAnonKey = 'DEIN-ANON-KEY';
}
