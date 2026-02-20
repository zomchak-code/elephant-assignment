class AppConfig {
  static const supabaseUrl = String.fromEnvironment("SUPABASE_URL", defaultValue: "");
  static const supabaseAnonKey = String.fromEnvironment("SUPABASE_ANON_KEY", defaultValue: "");
  static const backendBaseUrl = String.fromEnvironment("BACKEND_BASE_URL", defaultValue: "");

  static void validate() {
    if (supabaseUrl.isEmpty || supabaseAnonKey.isEmpty || backendBaseUrl.isEmpty) {
      throw StateError(
        "Missing config. Provide --dart-define SUPABASE_URL, SUPABASE_ANON_KEY, BACKEND_BASE_URL",
      );
    }
  }
}

