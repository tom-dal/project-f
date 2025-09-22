import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:provider/provider.dart';
import '../blocs/auth/auth_bloc.dart';
import '../blocs/debt_case/debt_case_bloc.dart';
import '../services/api_service.dart';
import '../widgets/change_password_dialog.dart';
import 'dashboard_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Check if already authenticated and password is expired
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkPasswordExpired();
    });
  }

  Future<void> _checkPasswordExpired() async {
    final apiService = context.read<ApiService>();
    final token = await apiService.getStoredToken();
    if (token != null) {
      final isPasswordToken = await apiService.isPasswordChangeToken();
      if (isPasswordToken) {
        _showChangePasswordDialog();
      }
    }
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _showChangePasswordDialog() async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => ChangePasswordDialog(),
    );

    if (result == true && mounted) {
      // Password changed successfully, navigate to dashboard
      _navigateToDashboard();
    } else if (result == false && mounted) {
      // User cancelled or failed, logout
      context.read<AuthBloc>().add(LogoutRequested());
    }
  }

  void _navigateToDashboard() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      // Blocca la navigazione se la password è scaduta
      final authState = context.read<AuthBloc>().state;
      if (authState is AuthAuthenticated && authState.passwordExpired) {
        // Non navigare e non creare il bloc delle pratiche
        return;
      }
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => BlocProvider(
            create: (context) => DebtCaseBloc(
              context.read<ApiService>(),
            ),
            child: const DashboardScreen(),
          ),
        ),
      );
    });
  }

  void _onLoginPressed() {
    if (_formKey.currentState!.validate()) {
      context.read<AuthBloc>().add(
            LoginRequested(
              _usernameController.text,
              _passwordController.text,
            ),
          );
    }
  }

  void _handleLoginError(String error) {
    String message = error;
    if (error.toLowerCase().contains('credentials have expired')) {
      message = 'Le tue credenziali sono scadute. Per favore, contatta l\'amministratore per reimpostare la password.';
    } else if (error.contains('Invalid credentials')) {
      message = 'Username o password non validi.';
    } else if (error.toLowerCase().contains('dioexception')) {
      message = 'Errore di rete o server non raggiungibile. Riprova più tardi.';
    } else if (error.isEmpty) {
      message = 'Errore sconosciuto. Riprova.';
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Theme.of(context).colorScheme.error,
        duration: const Duration(seconds: 5),
        action: error.toLowerCase().contains('credentials have expired')
            ? SnackBarAction(
                label: 'Contatta Admin',
                onPressed: () {
                },
                textColor: Colors.white,
              )
            : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: BlocListener<AuthBloc, AuthState>(
        listener: (context, state) {
          if (state is AuthError) {
            _handleLoginError(state.message);
          } else if (state is AuthAuthenticated) {
            if (state.passwordExpired) {
              // Mostra il dialog per cambio password
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) _showChangePasswordDialog();
              });
            } else {
              // Naviga alla dashboard
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) _navigateToDashboard();
              });
            }
          }
        },
        child: Center(
          child: SizedBox(
            width: 600,
            child: Card(
              margin: const EdgeInsets.all(32),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Gestione Recupero Crediti',
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                      const SizedBox(height: 32),
                      TextFormField(
                        controller: _usernameController,
                        decoration: const InputDecoration(
                          labelText: 'Username',
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Inserisci il tuo username';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _passwordController,
                        decoration: const InputDecoration(
                          labelText: 'Password',
                          border: OutlineInputBorder(),
                        ),
                        obscureText: true,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter your password';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 24),
                      BlocBuilder<AuthBloc, AuthState>(
                        builder: (context, state) {
                          return ElevatedButton(
                            onPressed: state is AuthLoading ? null : _onLoginPressed,
                            style: ElevatedButton.styleFrom(
                              minimumSize: const Size.fromHeight(50),
                            ),
                            child: state is AuthLoading
                                ? const CircularProgressIndicator()
                                : const Text('Login'),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
} 