// Vorlage für die Zugangsdaten zu Supabase.
//
// 1. Diese Datei nach lib/config.dart kopieren.
// 2. Werte aus dem Supabase-Dashboard eintragen:
//    Project Settings → API → Project URL bzw. "anon public" Key.
//
// lib/config.dart steht in .gitignore und wird nie committet.

class AppConfig {
  static const supabaseUrl = 'https://DEIN-PROJEKT.supabase.co';
  static const supabaseAnonKey = 'DEIN-ANON-KEY';
}
