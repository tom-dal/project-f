import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:provider/provider.dart';
import 'package:flutter/foundation.dart';
import 'dart:async';
import 'dart:developer' as developer;
import 'screens/login_screen.dart';
import 'screens/dashboard_screen.dart';
import 'blocs/auth/auth_bloc.dart';
import 'blocs/debt_case/debt_case_bloc.dart';
import 'blocs/cases_summary/cases_summary_bloc.dart';
import 'services/api_service.dart';
import 'services/config_service.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Abilita i log per web in modalità debug
  if (kDebugMode && kIsWeb) {
    developer.log('Flutter Web Debug Mode - Logging enabled');
  }
  
  // Carica la configurazione dall'esterno
  await ConfigService.loadConfig();
  
  runApp(DebtCollectionApp());
}

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _checkInitialAuth();
  }

  Future<void> _checkInitialAuth() async {
    final apiService = context.read<ApiService>();
    final authBloc = context.read<AuthBloc>();
    
    final token = await apiService.getStoredToken();
    
    if (token == null) {
      authBloc.add(CheckAuthStatus());
      if (mounted) setState(() => _isLoading = false);
      return;
    }
    
    // Controlla se è un token di cambio password
    final isPasswordToken = await apiService.isPasswordChangeToken();
    
    if (isPasswordToken) {
      // Se è un token di cambio password, emetti lo stato non autenticato
      // così il login screen mostrerà il dialog di cambio password
      authBloc.add(CheckAuthStatus());
    } else {
      // Valida il token normale
      final isValid = await apiService.validateToken();
      authBloc.add(CheckAuthStatus());
    }
    
    if (mounted) setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, state) {
        if (state is AuthAuthenticated && !state.passwordExpired) {
          // Solo se autenticato E la password non è scaduta, mostra la dashboard
          return MultiBlocProvider(
            providers: [
              BlocProvider(
                create: (context) => DebtCaseBloc(
                  context.read<ApiService>(),
                ),
              ),
              BlocProvider(
                create: (context) => CasesSummaryBloc(
                  context.read<ApiService>(),
                )..add(LoadCasesSummary()),
              ),
            ],
            child: const DashboardScreen(),
          );
        }
        
        // In tutti gli altri casi (non autenticato, password scaduta, errore), mostra login
        return const LoginScreen();
      },
    );
  }
}

class DebtCollectionApp extends StatelessWidget {
  final ApiService apiService; // USER PREFERENCE: Injection per testability
  DebtCollectionApp({super.key, ApiService? apiService}) : apiService = apiService ?? ApiService();

  @override
  Widget build(BuildContext context) {
    return Provider<ApiService>.value(
      value: apiService,
      child: BlocProvider(
        create: (context) => AuthBloc(
          apiService: apiService,
        ),
        child: MaterialApp(
          title: 'Gestione Recupero Crediti',
          locale: const Locale('it','IT'), // USER PREFERENCE: forzato italiano
          localizationsDelegates: [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [
            Locale('it'),
            Locale('en'),
          ],
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(
              seedColor: Colors.blue,
              primary: Colors.blue,
              secondary: Colors.orange,
            ),
            useMaterial3: true,
            appBarTheme: const AppBarTheme(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
            ),
          ),
          home: const AuthWrapper(),
        ),
      ),
    );
  }
}
