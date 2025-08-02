import 'dart:developer' as developer;
import 'package:flutter/foundation.dart';

class AppLogger {
  static void log(String message, {String? name, Object? error, StackTrace? stackTrace}) {
    if (kDebugMode) {
      if (kIsWeb) {
        // Per web, usa sia developer.log che print per assicurarti che appaia
        developer.log(message, name: name ?? 'Flutter', error: error, stackTrace: stackTrace);
        // Aggiungi anche print per web come fallback
        print('[${name ?? 'Flutter'}] $message');
        if (error != null) {
          print('[${name ?? 'Flutter'}] Error: $error');
        }
      } else {
        // Per altre piattaforme usa solo developer.log
        developer.log(message, name: name ?? 'Flutter', error: error, stackTrace: stackTrace);
      }
    }
  }

  static void info(String message) {
    log(message, name: 'INFO');
  }

  static void warning(String message) {
    log(message, name: 'WARNING');
  }

  static void error(String message, {Object? error, StackTrace? stackTrace}) {
    log(message, name: 'ERROR', error: error, stackTrace: stackTrace);
  }

  static void debug(String message) {
    log(message, name: 'DEBUG');
  }
}
