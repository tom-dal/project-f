import 'dart:convert';
import 'package:http/http.dart' as http;

class ConfigService {
  static String? _apiUrl;
  
  static String get apiUrl {
    if (_apiUrl == null) {
      throw Exception('Configuration not loaded. Call ConfigService.loadConfig() first.');
    }
    return _apiUrl!;
  }
  
  static Future<void> loadConfig() async {
    try {
      // Carica il file config.json dalla root dell'app web
      final response = await http.get(Uri.parse('/config.json'));
      
      if (response.statusCode == 200) {
        final config = jsonDecode(response.body);
        _apiUrl = config['API_URL'] as String;
        
        // Log della configurazione caricata
        print('🔧 [CONFIG] Loaded API URL: $_apiUrl');
      } else {
        throw Exception('Failed to load config.json: ${response.statusCode}');
      }
    } catch (e) {
      // Fallback a URL di produzione se il caricamento fallisce
      _apiUrl = 'https://debt-collection-backend-latest.onrender.com';
      print('⚠️ [CONFIG] Failed to load config.json, using production fallback: $_apiUrl');
      print('⚠️ [CONFIG] Error: $e');
    }
  }
  
  static bool get isConfigLoaded => _apiUrl != null;
}
