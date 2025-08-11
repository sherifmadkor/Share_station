// lib/config/api_config.dart

class ApiConfig {
  // RAWG Video Games Database API Configuration
  // Get your free API key from: https://rawg.io/apidocs
  // 
  // Steps to get API key:
  // 1. Go to https://rawg.io/apidocs
  // 2. Click "Get API Key" 
  // 3. Create an account
  // 4. Get your API key from the dashboard
  // 5. Replace 'YOUR_RAWG_API_KEY' below with your actual key
  
  static const String rawgApiKey = 'ba52d1f784c24f14896f868967ba0375';
  static const String rawgBaseUrl = 'https://api.rawg.io/api';
  
  // Platform IDs for RAWG API
  static const int playStation4Id = 18;
  static const int playStation5Id = 187;
  
  // API rate limits
  static const int apiRateLimit = 5000; // requests per month for free tier
  static const Duration apiTimeout = Duration(seconds: 10);
  
  // Validate API key
  static bool get isApiKeyValid => rawgApiKey != 'ba52d1f784c24f14896f868967ba0375' && rawgApiKey.isNotEmpty;
  
  // Error messages
  static const String apiKeyNotSetMessage = 
    'RAWG API key is not configured. Please set your API key in lib/config/api_config.dart';
  
  static const String apiKeyInvalidMessage = 
    'Invalid RAWG API key. Please check your API key in lib/config/api_config.dart';
}