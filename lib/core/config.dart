/// Credenciales públicas del proyecto Supabase, inyectadas al compilar:
///   flutter run --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...
/// La anon key es pública por diseño (la protección real es RLS), pero NUNCA
/// pongas aquí la service_role key.
class AppConfig {
  static const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');
  static const mapsApiKey = String.fromEnvironment('MAPS_API_KEY');

  /// true: toda cuenta debe activar la verificación en dos pasos para entrar.
  /// Ponlo en false mientras pruebas para no configurar el autenticador cada vez.
  static const exigirDosPasos = true;

  static bool get isConfigured =>
      supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;
}
