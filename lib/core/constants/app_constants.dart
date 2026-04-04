class AppConstants {
  const AppConstants._();

  static const String aiProvider = String.fromEnvironment(
    'AI_PROVIDER',
    defaultValue: 'gemini',
  );

  static const String geminiApiKey = String.fromEnvironment('GEMINI_API_KEY');
  static const String geminiModel = String.fromEnvironment(
    'GEMINI_MODEL',
    defaultValue: 'gemini-2.0-flash',
  );

  static const String ollamaBaseUrl = String.fromEnvironment(
    'OLLAMA_BASE_URL',
    defaultValue: '',
  );
  static const String ollamaModel = String.fromEnvironment(
    'OLLAMA_MODEL',
    defaultValue: 'llama3.1:8b',
  );
}
