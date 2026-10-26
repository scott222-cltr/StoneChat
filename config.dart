/// Add your Supabase project values here after creating a project at supabase.com.
/// Keep the anon/publishable key in the client; NEVER put a service_role key here.
class AppConfig {
  static const supabaseUrl = 'https://YOUR_PROJECT_ID.supabase.co';
  static const supabaseAnonKey = 'YOUR_SUPABASE_ANON_OR_PUBLISHABLE_KEY';

  static bool get isConfigured =>
      !supabaseUrl.contains('YOUR_PROJECT_ID') &&
      !supabaseAnonKey.contains('YOUR_SUPABASE');
}
