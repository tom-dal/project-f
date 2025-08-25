import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/auth.dart';
import '../models/debt_case.dart';
import '../models/case_state.dart';
import '../models/hateoas_response.dart';
import 'config_service.dart';
import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:convert';
import 'dart:developer' as developer;

class ApiService {
  // URL del backend - caricato dinamicamente da config.json
  static String get baseUrl => ConfigService.apiUrl;
  static const String _tokenKey = 'auth_token';
  final Dio _dio;
  final FlutterSecureStorage? _secureStorage;
  SharedPreferences? _sharedPrefs;
  final _authStateController = StreamController<bool>.broadcast();
  final _passwordExpiredController = StreamController<bool>.broadcast();
  bool _passwordChangeRequired = false;

  Stream<bool> get authStateStream => _authStateController.stream;
  Stream<bool> get passwordExpiredStream => _passwordExpiredController.stream;
  
  bool get passwordChangeRequired => _passwordChangeRequired;

  // Helper method to convert CaseState enum to JSON value
  String _caseStateToJson(CaseState state) {
    switch (state) {
      case CaseState.messaInMoraDaFare:
        return 'MESSA_IN_MORA_DA_FARE';
      case CaseState.messaInMoraInviata:
        return 'MESSA_IN_MORA_INVIATA';
      case CaseState.contestazioneDaRiscontrare:
        return 'CONTESTAZIONE_DA_RISCONTRARE';
      case CaseState.depositoRicorso:
        return 'DEPOSITO_RICORSO';
      case CaseState.decretoIngiuntivoDaNotificare:
        return 'DECRETO_INGIUNTIVO_DA_NOTIFICARE';
      case CaseState.decretoIngiuntivoNotificato:
        return 'DECRETO_INGIUNTIVO_NOTIFICATO';
      case CaseState.precetto:
        return 'PRECETTO';
      case CaseState.pignoramento:
        return 'PIGNORAMENTO';
      case CaseState.completata:
        return 'COMPLETATA';
    }
  }

  // Utility method for logging
  void _log(String message, {bool isError = false}) {
    // Forza i log sempre attivi per web, anche in release mode
    if (kIsWeb) {
      if (isError) {
        print('🔴 [API ERROR] $message');
      } else {
        print('🔵 [API] $message');
      }
    }
    developer.log(message, name: 'ApiService');
  }

  ApiService()
      : _dio = Dio(BaseOptions(
          baseUrl: baseUrl,
          contentType: 'application/json',
          validateStatus: (status) => true, // Accept all status codes for proper error handling
          headers: {
            'Accept': 'application/json',
          },
        )),
        _secureStorage = kIsWeb ? null : const FlutterSecureStorage() {
    _initStorage();
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        // Don't add token to login requests
        if (!options.path.contains('/auth/login')) {
          final token = await getStoredToken();
          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
            _log('Token added to request: ${token.substring(0, 20)}...');
          } else {
            _log('No token found for request!', isError: true);
          }
        }
        _log('📤 Request: ${options.method} ${options.path}');
        _log('📋 Headers: ${options.headers}');
        if (options.data != null) {
          _log('📦 Body: ${options.data}');
        }
        return handler.next(options);
      },
      onResponse: (response, handler) {
        _log('📥 Response Status: ${response.statusCode}');
        _log('📄 Response Headers: ${response.headers}');
        _log('📦 Response Body: ${response.data}');

        if (response.statusCode == 401) {
          _handle401Response(response, handler);
          return;
        }

        return handler.next(response);
      },
      onError: (DioException e, handler) {
        _log('❌ Error: ${e.message}', isError: true);
        _log('❌ Error Response: ${e.response?.data}', isError: true);
        _log('❌ Error Status: ${e.response?.statusCode}', isError: true);
        _log('❌ Error Headers: ${e.response?.headers}', isError: true);
        
        if (e.response?.statusCode == 401) {
          _handle401Error(e, handler);
          return;
        }
        
        if (e.response?.statusCode == 403) {
          return handler.reject(
            DioException(
              requestOptions: e.requestOptions,
              error: 'Access denied. Please check your credentials.',
              response: e.response,
            ),
          );
        }
        return handler.next(e);
      },
    ));
    _dio.interceptors.add(
      LogInterceptor(
        request: true,
        responseHeader: true,
        responseBody: true,
        requestBody: true,
        error: true,
        logPrint: (message) => developer.log('$message'),
      ),
    );
  }

  void _handle401Response(Response response, ResponseInterceptorHandler handler) async {
    if (response.data is Map && 
        (response.data['error'] == 'CredentialsExpiredException' ||
         response.data['message']?.toString().toLowerCase().contains('credentials have expired') == true)) {
      _handleCredentialsExpired();
      return handler.reject(
        DioException(
          requestOptions: response.requestOptions,
          response: response,
          error: 'Your credentials have expired. Please log in again.',
        ),
      );
    }
    
    // Per altri tipi di 401, verifica se è un token di cambio password
    await _handleUnauthorizedSafely(response.requestOptions.path);
    return handler.reject(
      DioException(
        requestOptions: response.requestOptions,
        response: response,
        error: 'Unauthorized',
      ),
    );
  }

  void _handle401Error(DioException e, ErrorInterceptorHandler handler) async {
    await _handleUnauthorizedSafely(e.requestOptions.path);
    return handler.next(e);
  }

  Future<void> _handleUnauthorizedSafely(String requestPath) async {
    // Non rimuovere il token se:
    // 1. È un token di cambio password E
    // 2. L'errore 401 NON proviene dall'endpoint di cambio password
    final isChangeToken = await isPasswordChangeToken();
    if (isChangeToken && !requestPath.contains('/auth/change-password')) {
      developer.log('Password change token detected, 401 from non-change-password endpoint - keeping token');
      return;
    }
    
    // In tutti gli altri casi, rimuovi il token
    await deleteToken();
    _authStateController.add(false);
    _passwordExpiredController.add(false);
    developer.log('Token removed due to 401 error from: $requestPath');
  }

  void _handleUnauthorized() async {
    // Metodo legacy mantenuto per compatibilità, ma migliorato
    await _handleUnauthorizedSafely('unknown');
  }

  void _handleCredentialsExpired() async {
    await deleteToken();
    _authStateController.add(false);
    _passwordExpiredController.add(false);
    // You might want to show a specific dialog or notification to the user
    // This will be handled in the UI layer
  }

  Future<void> _initStorage() async {
    if (kIsWeb) {
      _sharedPrefs = await SharedPreferences.getInstance();
      developer.log('Initialized SharedPreferences for web');
    }
  }

  void dispose() {
    _authStateController.close();
    _passwordExpiredController.close();
  }

  Future<String?> getStoredToken() async {
    if (kIsWeb) {
      await _initStorageIfNeeded();
      final token = _sharedPrefs?.getString(_tokenKey);
      developer.log('Retrieving token from SharedPreferences: ${token != null ? 'Found' : 'Not found'}');
      return token;
    } else {
      final token = await _secureStorage?.read(key: _tokenKey);
      developer.log('Retrieving token from SecureStorage: ${token != null ? 'Found' : 'Not found'}');
      return token;
    }
  }

  Future<void> _initStorageIfNeeded() async {
    if (kIsWeb && _sharedPrefs == null) {
      _sharedPrefs = await SharedPreferences.getInstance();
    }
  }

  Future<void> saveToken(String token) async {
    developer.log('Saving token to storage');
    if (kIsWeb) {
      await _initStorageIfNeeded();
      await _sharedPrefs?.setString(_tokenKey, token);
      developer.log('Token saved to SharedPreferences');
    } else {
      await _secureStorage?.write(key: _tokenKey, value: token);
      developer.log('Token saved to SecureStorage');
    }
  }

  Future<void> deleteToken() async {
    if (kIsWeb) {
      await _initStorageIfNeeded();
      await _sharedPrefs?.remove(_tokenKey);
      developer.log('Token removed from SharedPreferences');
    } else {
      await _secureStorage?.delete(key: _tokenKey);
      developer.log('Token removed from SecureStorage');
    }
  }

  Future<bool> validateToken() async {
    try {
      final token = await getStoredToken();
      _log('🔍 Validating token: ${token != null ? 'Present (${token.substring(0, 20)}...)' : 'Missing'}');
      if (token == null) return false;
      
      // Un token di cambio password è valido per l'autenticazione, ma solo per il cambio password
      final isPasswordToken = await isPasswordChangeToken();
      if (isPasswordToken) {
        _log('🔑 Token is a password change token, considering it valid for password change');
        _authStateController.add(true);
        _passwordExpiredController.add(true);
        return true;
      }

      _log('🌐 Making validation request to: $baseUrl/auth/validate');
      final response = await _dio.get(
        '/auth/validate',
        options: Options(
          headers: {
            'Authorization': 'Bearer $token',
          },
        ),
      );

      _log('✅ Token validation response: ${response.statusCode}');
      final isValid = response.statusCode == 200;
      
      // Notify listeners about the authentication state
      _authStateController.add(isValid);
      if (isValid) {
        _passwordExpiredController.add(false);
      }
      
      return isValid;
    } catch (e) {
      _log('❌ Error validating token: $e', isError: true);
      _authStateController.add(false);
      return false;
    }
  }

  // Controlla se il token corrente è un token di cambio password
  Future<bool> isPasswordChangeToken() async {
    try {
      final token = await getStoredToken();
      if (token == null) return false;
      
      // Decodifica del payload del token JWT (seconda parte)
      try {
        final parts = token.split('.');
        if (parts.length != 3) return false;
        
        // Decodifica la parte payload (base64url) in una stringa
        String normalized = parts[1];
        // Aggiungi padding se necessario
        while (normalized.length % 4 != 0) {
          normalized += '=';
        }
        
        final decodedPayload = utf8.decode(base64Url.decode(normalized));
        final payloadMap = jsonDecode(decodedPayload);
        
        // Verifica se è un token di cambio password
        final isPasswordChange = payloadMap['password_change'] == true;
        
        developer.log('Token JWT decoded: $payloadMap');
        developer.log('Is password change token: $isPasswordChange');
        
        return isPasswordChange;
      } catch (e) {
        developer.log('Error decoding JWT: $e');
        return false;
      }
    } catch (e) {
      developer.log('Error checking password change token: $e');
      return false;
    }
  }

  Future<AuthResponse> login(String username, String password) async {
    try {
      developer.log('Attempting login for user: $username');
      final response = await _dio.post(
        '/auth/login',
        data: AuthRequest(username: username, password: password).toJson(),
        options: Options(
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
          validateStatus: (status) => true,
        ),
      );
      
      developer.log('Response status: ${response.statusCode}');
      developer.log('Response data: ${response.data}');
      
      if (response.statusCode == 200) {
        final authResponse = AuthResponse.fromJson(response.data);
        await saveToken(authResponse.token);
        _passwordChangeRequired = authResponse.passwordExpired;
        _authStateController.add(true);
        _passwordExpiredController.add(authResponse.passwordExpired);
        developer.log('Login successful, password expired: ${authResponse.passwordExpired}');
        return authResponse;
      } else {
        developer.log('Login failed with status: ${response.statusCode}');
        if (response.data is Map) {
          if (response.data['error'] == 'CredentialsExpiredException' ||
              response.data['message']?.toString().toLowerCase().contains('credentials have expired') == true) {
            throw 'Your credentials have expired. Please contact your administrator.';
          }
          throw response.data['message'] ?? 'Authentication failed';
        }
        throw 'Authentication failed';
      }
    } on DioException catch (e) {
      developer.log('DioException during login: ${e.message}');
      developer.log('DioException type: ${e.type}');
      developer.log('DioException response: ${e.response?.data}');
      
      if (e.response?.statusCode == 403) {
        throw 'Invalid credentials';
      } else if (e.type == DioExceptionType.connectionError) {
        throw 'Connection error. Please check your internet connection.';
      } else {
        throw e.message ?? 'An error occurred during login';
      }
    } catch (e) {
      developer.log('Unexpected error during login: $e');
      throw 'An unexpected error occurred';
    }
  }

  Future<AuthResponse> changePassword(String oldPassword, String newPassword) async {
    try {
      final token = await getStoredToken();
      _log('🔑 Change password - Token: ${token != null ? 'Present (${token.substring(0, 20)}...)' : 'Missing'}');
      if (token == null) {
        throw 'Sessione scaduta. Effettua nuovamente il login.';
      }

      // Verifica che sia effettivamente un token di cambio password o un token valido
      final isPasswordToken = await isPasswordChangeToken();
      _log('🔍 Token verification - isPasswordToken: $isPasswordToken');
      if (!isPasswordToken) {
        // Se non è un token di cambio password, verifica che sia almeno valido
        final isValid = await validateToken();
        _log('🔍 Token validation - isValid: $isValid');
        if (!isValid) {
          throw 'Sessione scaduta. Effettua nuovamente il login.';
        }
      }
      
      _log('🔄 Attempting password change - Token type: ${isPasswordToken ? 'Password Change' : 'Regular'}');
      _log('🌐 Making request to: $baseUrl/auth/change-password');
      
      final response = await _dio.post(
        '/auth/change-password',
        data: ChangePasswordRequest(
          oldPassword: oldPassword,
          newPassword: newPassword,
        ).toJson(),
        options: Options(
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
          validateStatus: (status) => true,
        ),
      );
      
      _log('📥 Change password response status: ${response.statusCode}');
      _log('📦 Change password response data: ${response.data}');

      if (response.statusCode == 200) {
        final authResponse = AuthResponse.fromJson(response.data);
        await saveToken(authResponse.token);
        _passwordChangeRequired = false;
        _authStateController.add(true);
        _passwordExpiredController.add(false);
        _log('✅ Password change successful, new token saved');
        return authResponse;
      } else {
        _log('❌ Password change failed with status: ${response.statusCode}', isError: true);
        
        // Gestione errori più specifica
        if (response.statusCode == 401) {
          _log('🚫 401 Unauthorized - Token may be expired or invalid', isError: true);
          await deleteToken();
          _authStateController.add(false);
          _passwordExpiredController.add(false);
          throw 'Sessione scaduta o token non valido. Effettua nuovamente il login.';
        }
        
        if (response.statusCode == 403) {
          throw 'Password corrente non valida.';
        }
        
        if (response.statusCode == 400 && response.data is Map) {
          final message = response.data['message'] ?? response.data['error'] ?? 'Richiesta non valida';
          throw message;
        }
        
        if (response.data is Map) {
          throw response.data['message'] ?? 'Errore durante il cambio password';
        }
        throw 'Errore durante il cambio password';
      }
    } on DioException catch (e) {
      developer.log('DioException during password change: ${e.message}');
      developer.log('DioException type: ${e.type}');
      developer.log('DioException response: ${e.response?.data}');
      developer.log('DioException status: ${e.response?.statusCode}');
      
      if (e.response?.statusCode == 401) {
        await deleteToken();
        _authStateController.add(false);
        _passwordExpiredController.add(false);
        throw 'Sessione scaduta o token non valido. Effettua nuovamente il login.';
      } else if (e.response?.statusCode == 403) {
        throw 'Password corrente non valida';
      } else if (e.response?.statusCode == 400) {
        if (e.response?.data is Map) {
          final message = e.response?.data['message'] ?? e.response?.data['error'] ?? 'Richiesta non valida';
          throw message;
        }
        throw 'I dati forniti non sono validi';
      } else if (e.type == DioExceptionType.connectionError) {
        throw 'Errore di connessione. Verifica la tua connessione internet.';
      } else {
        throw e.message ?? 'Errore durante il cambio password';
      }
    } catch (e) {
      if (e is String) {
        rethrow;
      }
      developer.log('Unexpected error during password change: $e');
      throw 'Errore imprevisto durante il cambio password';
    }
  }

  Future<DebtCase> createDebtCase({
    required String debtorName,
    required CaseState initialState,
    DateTime? lastStateDate,
    required double amount,
  }) async {
    try {
      _log('🔨 Creating debt case - Name: $debtorName, State: $initialState, Amount: $amount');
      
      final response = await _dio.post(
        '/cases',
        data: {
          'debtorName': debtorName,
          'initialState': _caseStateToJson(initialState),
          if (lastStateDate != null) 'lastStateDate': lastStateDate.toIso8601String(),
          'amount': amount,
        },
        options: Options(
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
          validateStatus: (status) => true,
        ),
      );

      _log('📥 Create debt case response: ${response.statusCode}');
      _log('📦 Create debt case data: ${response.data}');

      if (response.statusCode == 200) {
        return DebtCase.fromJson(response.data);
      } else {
        _log('❌ Create debt case failed with status: ${response.statusCode}', isError: true);
        if (response.data is Map) {
          throw response.data['message'] ?? 'Failed to create debt case';
        }
        throw 'Failed to create debt case';
      }
    } on DioException catch (e) {
      _log('❌ DioException during create debt case: ${e.message}', isError: true);
      _log('❌ Response: ${e.response?.data}', isError: true);
      
      if (e.response?.statusCode == 400 && e.response?.data is Map) {
        final message = e.response?.data['message'] ?? e.response?.data['error'] ?? 'Invalid request';
        throw message;
      } else if (e.response?.statusCode == 401) {
        await _handleUnauthorizedSafely('/cases');
        throw 'Sessione scaduta. Effettua nuovamente il login.';
      } else if (e.type == DioExceptionType.connectionError) {
        throw 'Errore di connessione. Verifica la tua connessione internet.';
      } else {
        throw e.message ?? 'Errore durante la creazione del caso';
      }
    } catch (e) {
      if (e is String) {
        rethrow;
      }
      _log('❌ Unexpected error during create debt case: $e', isError: true);
      throw 'Errore imprevisto durante la creazione del caso';
    }
  }

  /// Get all debt cases with pagination support
  /// Returns paginated response with HATEOAS format
  /// USER PREFERENCE: Filtro active=true nascosto, sempre applicato automaticamente
  Future<HateoasPaginatedResponse<DebtCase>> getAllCasesPaginated({
    int page = 0,
    int size = 20,
    String? sort,
    String? debtorName,
    CaseState? state,
    double? minAmount,
    double? maxAmount,
    bool? hasInstallmentPlan,
    bool? paid,
    bool? ongoingNegotiations,
  }) async {
    try {
      _log('🔍 Getting paginated cases - Page: $page, Size: $size (Active filter: hidden)');

      final queryParams = <String, dynamic>{
        'page': page,
        'size': size,
        // USER PREFERENCE: Filtro nascosto - mostra sempre solo pratiche attive
        'active': true,
      };
      
      if (sort != null) queryParams['sort'] = sort;
      if (debtorName != null) queryParams['debtorName'] = debtorName;
      if (state != null) queryParams['state'] = _caseStateToJson(state);
      if (minAmount != null) queryParams['minAmount'] = minAmount;
      if (maxAmount != null) queryParams['maxAmount'] = maxAmount;
      if (hasInstallmentPlan != null) queryParams['hasInstallmentPlan'] = hasInstallmentPlan;
      if (paid != null) queryParams['paid'] = paid;
      if (ongoingNegotiations != null) queryParams['ongoingNegotiations'] = ongoingNegotiations;

      final response = await _dio.get(
        '/cases',
        queryParameters: queryParams,
        options: Options(
          headers: {
            'Accept': 'application/hal+json',
          },
          validateStatus: (status) => true,
        ),
      );

      _log('📥 Get cases response: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        final paginatedResponse = HateoasPaginatedResponse<DebtCase>.fromJson(
          response.data,
          (json) => DebtCase.fromJson(json as Map<String, dynamic>),
        );
        _log('✅ Got ${paginatedResponse.page.totalElements} total cases');
        return paginatedResponse;
      } else {
        _log('❌ Get cases failed with status: ${response.statusCode}', isError: true);
        if (response.statusCode == 401) {
          await _handleUnauthorizedSafely('/cases');
          throw 'Sessione scaduta. Effettua nuovamente il login.';
        }
        if (response.data is Map) {
          throw response.data['message'] ?? 'Failed to fetch cases';
        }
        throw 'Failed to fetch cases';
      }
    } on DioException catch (e) {
      _log('❌ DioException during get cases: ${e.message}', isError: true);
      
      if (e.response?.statusCode == 401) {
        await _handleUnauthorizedSafely('/cases');
        throw 'Sessione scaduta. Effettua nuovamente il login.';
      } else if (e.type == DioExceptionType.connectionError) {
        throw 'Errore di connessione. Verifica la tua connessione internet.';
      } else {
        throw e.message ?? 'Errore durante il recupero dei casi';
      }
    } catch (e) {
      if (e is String) {
        rethrow;
      }
      _log('❌ Unexpected error during get cases: $e', isError: true);
      throw 'Errore imprevisto durante il recupero dei casi';
    }
  }

  /// Get all debt cases as a simple list (for backward compatibility)
  /// Fetches all pages and returns a flat list
  Future<List<DebtCase>> getAllCases() async {
    try {
      // Start with first page
      final firstPage = await getAllCasesPaginated(page: 0, size: 100);
      
      // Extract cases from HATEOAS structure
      List<DebtCase> allCases = firstPage.getItems('cases', (json) => DebtCase.fromJson(json));
      
      // If there are more pages, fetch them
      int currentPage = 0;
      final totalPages = firstPage.page.totalPages;
      
      while (currentPage + 1 < totalPages) {
        currentPage++;
        final nextPage = await getAllCasesPaginated(page: currentPage, size: 100);
        final moreCases = nextPage.getItems('cases', (json) => DebtCase.fromJson(json));
        allCases.addAll(moreCases);
      }
      
      return allCases;
    } catch (e) {
      rethrow;
    }
  }

  Future<DebtCase> updateDebtCase({
    required DebtCase debtCase,
    String? debtorName,
    double? owedAmount,
    CaseState? currentState,
    DateTime? nextDeadlineDate,
    bool? ongoingNegotiations,
    bool? hasInstallmentPlan,
    bool? paid,
    String? notes,
    bool? clearNotes,
  }) async {
    try {
      _log('🔄 Updating debt case ${debtCase.id}');

      // Use HATEOAS link if available, otherwise fallback to manual URL construction
      final updateUrl = debtCase.links?.update?.href ?? '/cases/${debtCase.id}';

      final data = <String, dynamic>{};
      
      if (debtorName != null) data['debtorName'] = debtorName;
      if (owedAmount != null) data['owedAmount'] = owedAmount;
      if (currentState != null) data['currentState'] = _caseStateToJson(currentState);
      if (nextDeadlineDate != null) data['nextDeadlineDate'] = nextDeadlineDate.toIso8601String();
      if (ongoingNegotiations != null) data['ongoingNegotiations'] = ongoingNegotiations;
      if (hasInstallmentPlan != null) data['hasInstallmentPlan'] = hasInstallmentPlan;
      if (paid != null) data['paid'] = paid;
      if (notes != null) data['notes'] = notes;
      if (clearNotes != null) data['clearNotes'] = clearNotes;

      final response = await _dio.put(
        updateUrl,
        data: data,
        options: Options(
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
          validateStatus: (status) => true,
        ),
      );

      _log('📥 Update debt case response: ${response.statusCode}');

      if (response.statusCode == 200) {
        return DebtCase.fromJson(response.data);
      } else {
        _log('❌ Update debt case failed with status: ${response.statusCode}', isError: true);
        if (response.statusCode == 401) {
          await _handleUnauthorizedSafely(updateUrl);
          throw 'Sessione scaduta. Effettua nuovamente il login.';
        }
        if (response.data is Map) {
          throw response.data['message'] ?? 'Failed to update debt case';
        }
        throw 'Failed to update debt case';
      }
    } on DioException catch (e) {
      _log('❌ DioException during update debt case: ${e.message}', isError: true);
      
      if (e.response?.statusCode == 401) {
        await _handleUnauthorizedSafely('/cases/${debtCase.id}');
        throw 'Sessione scaduta. Effettua nuovamente il login.';
      } else if (e.response?.statusCode == 400 && e.response?.data is Map) {
        final message = e.response?.data['message'] ?? e.response?.data['error'] ?? 'Invalid request';
        throw message;
      } else if (e.type == DioExceptionType.connectionError) {
        throw 'Errore di connessione. Verifica la tua connessione internet.';
      } else {
        throw e.message ?? 'Errore durante l\'aggiornamento del caso';
      }
    } catch (e) {
      if (e is String) {
        rethrow;
      }
      _log('❌ Unexpected error during update debt case: $e', isError: true);
      throw 'Errore imprevisto durante l\'aggiornamento del caso';
    }
  }

  Future<void> deleteDebtCase(DebtCase debtCase) async {
    try {
      _log('🗑️ Deleting debt case ${debtCase.id}');

      // Use HATEOAS link if available, otherwise fallback to manual URL construction
      final deleteUrl = debtCase.links?.delete?.href ?? '/cases/${debtCase.id}';

      final response = await _dio.delete(
        deleteUrl,
        options: Options(
          validateStatus: (status) => true,
        ),
      );

      _log('📥 Delete debt case response: ${response.statusCode}');

      if (response.statusCode == 204 || response.statusCode == 200) {
        _log('✅ Debt case deleted successfully');
      } else {
        _log('❌ Delete debt case failed with status: ${response.statusCode}', isError: true);
        if (response.statusCode == 401) {
          await _handleUnauthorizedSafely(deleteUrl);
          throw 'Sessione scaduta. Effettua nuovamente il login.';
        }
        if (response.data is Map) {
          throw response.data['message'] ?? 'Failed to delete debt case';
        }
        throw 'Failed to delete debt case';
      }
    } on DioException catch (e) {
      _log('❌ DioException during delete debt case: ${e.message}', isError: true);
      
      if (e.response?.statusCode == 401) {
        await _handleUnauthorizedSafely('/cases/${debtCase.id}');
        throw 'Sessione scaduta. Effettua nuovamente il login.';
      } else if (e.response?.statusCode == 404) {
        throw 'Caso non trovato';
      } else if (e.type == DioExceptionType.connectionError) {
        throw 'Errore di connessione. Verifica la tua connessione internet.';
      } else {
        throw e.message ?? 'Errore durante la cancellazione del caso';
      }
    } catch (e) {
      if (e is String) {
        rethrow;
      }
      _log('❌ Unexpected error during delete debt case: $e', isError: true);
      throw 'Errore imprevisto durante la cancellazione del caso';
    }
  }

  /// Register a payment for a debt case
  Future<Map<String, dynamic>> registerPayment({
    required int caseId,
    required double amount,
    DateTime? paymentDate,
  }) async {
    try {
      _log('💰 Registering payment for case $caseId - Amount: $amount');
      
      final response = await _dio.post(
        '/cases/$caseId/payments',
        data: {
          'amount': amount,
          if (paymentDate != null) 'paymentDate': paymentDate.toIso8601String(),
        },
        options: Options(
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
          validateStatus: (status) => true,
        ),
      );

      _log('📥 Register payment response: ${response.statusCode}');

      if (response.statusCode == 200) {
        return response.data as Map<String, dynamic>;
      } else {
        _log('❌ Register payment failed with status: ${response.statusCode}', isError: true);
        if (response.statusCode == 401) {
          await _handleUnauthorizedSafely('/cases/$caseId/payments');
          throw 'Sessione scaduta. Effettua nuovamente il login.';
        }
        if (response.data is Map) {
          throw response.data['message'] ?? 'Failed to register payment';
        }
        throw 'Failed to register payment';
      }
    } on DioException catch (e) {
      _log('❌ DioException during register payment: ${e.message}', isError: true);
      
      if (e.response?.statusCode == 401) {
        await _handleUnauthorizedSafely('/cases/$caseId/payments');
        throw 'Sessione scaduta. Effettua nuovamente il login.';
      } else if (e.response?.statusCode == 400 && e.response?.data is Map) {
        final message = e.response?.data['message'] ?? e.response?.data['error'] ?? 'Invalid request';
        throw message;
      } else if (e.type == DioExceptionType.connectionError) {
        throw 'Errore di connessione. Verifica la tua connessione internet.';
      } else {
        throw e.message ?? 'Errore durante la registrazione del pagamento';
      }
    } catch (e) {
      if (e is String) {
        rethrow;
      }
      _log('❌ Unexpected error during register payment: $e', isError: true);
      throw 'Errore imprevisto durante la registrazione del pagamento';
    }
  }

  Future<List<DebtCase>> getCasesByState(CaseState state) async {
    try {
      _log('📋 Getting cases by state: $state');
      
      final response = await _dio.get(
        '/cases',
        queryParameters: {
          'state': _caseStateToJson(state),
        },
        options: Options(
          headers: {
            'Accept': 'application/json',
          },
        ),
      );

      if (response.statusCode == 200) {
        final hateoasResponse = HateoasPaginatedResponse<DebtCase>.fromJson(
          response.data as Map<String, dynamic>,
          (json) => DebtCase.fromJson(json as Map<String, dynamic>),
        );
        return hateoasResponse.getItems('cases', (json) => DebtCase.fromJson(json as Map<String, dynamic>));
      } else if (response.statusCode == 401) {
        await _handleUnauthorizedSafely('/cases');
        throw Exception('Authentication required');
      }
      throw Exception('Failed to get cases by state: ${response.statusCode}');
    } catch (e) {
      _log('❌ Error getting cases by state: $e', isError: true);
      rethrow;
    }
  }

  Future<List<DebtCase>> getCasesByDeadline(DateTime before) async {
    try {
      _log('📅 Getting cases by deadline before: $before');
      
      final response = await _dio.get(
        '/cases',
        queryParameters: {
          'deadlineBefore': before.toIso8601String(),
        },
        options: Options(
          headers: {
            'Accept': 'application/json',
          },
        ),
      );

      if (response.statusCode == 200) {
        final hateoasResponse = HateoasPaginatedResponse<DebtCase>.fromJson(
          response.data as Map<String, dynamic>,
          (json) => DebtCase.fromJson(json as Map<String, dynamic>),
        );
        return hateoasResponse.getItems('cases', (json) => DebtCase.fromJson(json as Map<String, dynamic>));
      } else if (response.statusCode == 401) {
        await _handleUnauthorizedSafely('/cases');
        throw Exception('Authentication required');
      }
      throw Exception('Failed to get cases by deadline: ${response.statusCode}');
    } catch (e) {
      _log('❌ Error getting cases by deadline: $e', isError: true);
      rethrow;
    }
  }

  Future<void> updateState({
    required String id, // CUSTOM IMPLEMENTATION: Changed from int to String for MongoDB ObjectId compatibility
    DateTime? completionDate,
    String? notes,
  }) async {
    try {
      _log('🔄 Updating case state for ID: $id');
      
      final data = <String, dynamic>{};
      if (completionDate != null) data['completionDate'] = completionDate.toIso8601String();
      if (notes != null) data['notes'] = notes;

      final response = await _dio.put(
        '/cases/$id/state',
        data: data,
        options: Options(
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
        ),
      );

      if (response.statusCode == 200) {
        _log('✅ Case state updated successfully');
      } else if (response.statusCode == 401) {
        await _handleUnauthorizedSafely('/cases/$id/state');
        throw Exception('Authentication required');
      } else {
        throw Exception('Failed to update case state: ${response.statusCode}');
      }
    } catch (e) {
      _log('❌ Error updating case state: $e', isError: true);
      rethrow;
    }
  }

  /// Creates an installment plan for a debt case
  ///
  /// Parameters:
  /// - [caseId]: The ID of the debt case
  /// - [numberOfInstallments]: Number of installments in the plan
  /// - [firstInstallmentDate]: Date of the first installment (yyyy-MM-dd format)
  /// - [monthlyAmount]: Amount for each installment
  ///
  /// Returns: Map with installment plan details
  Future<Map<String, dynamic>> createInstallmentPlan({
    required int caseId,
    required int numberOfInstallments,
    required String firstInstallmentDate,
    required double monthlyAmount,
  }) async {
    try {
      _log('🏗️ Creating installment plan for case $caseId');
      _log('📋 Plan details: $numberOfInstallments installments, first date: $firstInstallmentDate, amount: $monthlyAmount');

      final response = await _dio.post(
        '/cases/$caseId/installment-plan',
        data: {
          'numberOfInstallments': numberOfInstallments,
          'firstInstallmentDate': firstInstallmentDate,
          'monthlyAmount': monthlyAmount,
        },
        options: Options(
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
          validateStatus: (status) => true,
        ),
      );

      _log('📥 Installment plan response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        _log('✅ Installment plan created successfully');
        return response.data as Map<String, dynamic>;
      } else {
        _log('❌ Failed to create installment plan: ${response.statusCode}', isError: true);
        if (response.data is Map) {
          throw response.data['message'] ?? 'Failed to create installment plan';
        }
        throw 'Failed to create installment plan';
      }
    } on DioException catch (e) {
      _log('❌ DioException creating installment plan: ${e.message}', isError: true);
      if (e.response?.statusCode == 400) {
        if (e.response?.data is Map) {
          throw e.response!.data['message'] ?? 'Invalid installment plan data';
        }
        throw 'Invalid installment plan data';
      } else if (e.response?.statusCode == 404) {
        throw 'Debt case not found';
      } else if (e.type == DioExceptionType.connectionError) {
        throw 'Connection error. Please check your internet connection.';
      } else {
        throw e.message ?? 'An error occurred while creating installment plan';
      }
    } catch (e) {
      _log('❌ Unexpected error creating installment plan: $e', isError: true);
      throw 'An unexpected error occurred';
    }
  }

  /// Registers a payment for a specific installment
  ///
  /// Parameters:
  /// - [caseId]: The ID of the debt case
  /// - [installmentId]: The ID of the installment
  /// - [amount]: Payment amount
  /// - [paymentDate]: Date of payment (yyyy-MM-dd format)
  ///
  /// Returns: Map with payment details
  Future<Map<String, dynamic>> registerInstallmentPayment({
    required int caseId,
    required int installmentId,
    required double amount,
    required String paymentDate,
  }) async {
    try {
      _log('💰 Registering payment for installment $installmentId in case $caseId');
      _log('💵 Payment details: amount: $amount, date: $paymentDate');

      final response = await _dio.post(
        '/cases/$caseId/installments/$installmentId/payments',
        data: {
          'amount': amount,
          'paymentDate': paymentDate,
        },
        options: Options(
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
          validateStatus: (status) => true,
        ),
      );

      _log('📥 Payment registration response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        _log('✅ Payment registered successfully');
        return response.data as Map<String, dynamic>;
      } else {
        _log('❌ Failed to register payment: ${response.statusCode}', isError: true);
        if (response.data is Map) {
          throw response.data['message'] ?? 'Failed to register payment';
        }
        throw 'Failed to register payment';
      }
    } on DioException catch (e) {
      _log('❌ DioException registering payment: ${e.message}', isError: true);
      if (e.response?.statusCode == 400) {
        if (e.response?.data is Map) {
          throw e.response!.data['message'] ?? 'Invalid payment data';
        }
        throw 'Invalid payment data';
      } else if (e.response?.statusCode == 404) {
        throw 'Debt case or installment not found';
      } else if (e.type == DioExceptionType.connectionError) {
        throw 'Connection error. Please check your internet connection.';
      } else {
        throw e.message ?? 'An error occurred while registering payment';
      }
    } catch (e) {
      _log('❌ Unexpected error registering payment: $e', isError: true);
      throw 'An unexpected error occurred';
    }
  }
}
