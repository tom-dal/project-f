import 'dart:developer' as developer;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../blocs/auth/auth_bloc.dart';

class ChangePasswordDialog extends StatefulWidget {
  ChangePasswordDialog({super.key});

  @override
  State<ChangePasswordDialog> createState() => _ChangePasswordDialogState();
}

class _ChangePasswordDialogState extends State<ChangePasswordDialog> {
  final _formKey = GlobalKey<FormState>();
  final _oldPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _oldPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _changePassword() async {
    developer.log('🔄 PASSWORD DIALOG - Change password initiated');
    
    if (!_formKey.currentState!.validate()) {
      developer.log('❌ PASSWORD DIALOG - Form validation failed');
      return;
    }

    developer.log('✅ PASSWORD DIALOG - Form validation passed');
    developer.log('🔐 PASSWORD DIALOG - Old password length: ${_oldPasswordController.text.length}');
    developer.log('🔐 PASSWORD DIALOG - New password length: ${_newPasswordController.text.length}');

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    developer.log('🚀 PASSWORD DIALOG - Dispatching ChangePasswordRequested event');
    context.read<AuthBloc>().add(ChangePasswordRequested(
      _oldPasswordController.text,
      _newPasswordController.text,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthBloc, AuthState>(
      listener: (context, state) {
        developer.log('🔄 PASSWORD DIALOG - AuthBloc state changed: ${state.runtimeType}');
        
        if (state is AuthAuthenticated && !state.passwordExpired) {
          // Password changed successfully
          developer.log('✅ PASSWORD DIALOG - Password change successful');
          setState(() {
            _isLoading = false;
          });
          Navigator.of(context).pop(true);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Password cambiata con successo!'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 3),
            ),
          );
        } else if (state is AuthError) {
          developer.log('❌ PASSWORD DIALOG - Password change error: ${state.message}');
          setState(() {
            _isLoading = false;
            _errorMessage = state.message;
          });
        } else if (state is AuthUnauthenticated) {
          // Se l'utente viene disconnesso durante il cambio password
          developer.log('❌ PASSWORD DIALOG - User unauthenticated during password change');
          setState(() {
            _isLoading = false;
            _errorMessage = 'Sessione scaduta. Rieffettua il login.';
          });
          Navigator.of(context).pop(false);
        } else if (state is AuthLoading) {
          developer.log('⏳ PASSWORD DIALOG - Auth loading state');
        }
      },
      child: AlertDialog(
        title: const Text('Cambio Password Richiesto'),
        content: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'La tua password è scaduta. Devi cambiarla per continuare.',
                style: TextStyle(color: Colors.red),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _oldPasswordController,
                decoration: const InputDecoration(
                  labelText: 'Password Corrente',
                  border: OutlineInputBorder(),
                ),
                obscureText: true,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Inserisci la password corrente';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _newPasswordController,
                decoration: const InputDecoration(
                  labelText: 'Nuova Password',
                  border: OutlineInputBorder(),
                  helperText: 'Min 8 caratteri, 1 maiuscola, 1 numero, 1 carattere speciale',
                  helperMaxLines: 2,
                ),
                obscureText: true,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Inserisci una nuova password';
                  }
                  if (value.length < 8) {
                    return 'La password deve essere di almeno 8 caratteri';
                  }
                  if (!value.contains(RegExp(r'[A-Z]'))) {
                    return 'La password deve contenere almeno una lettera maiuscola';
                  }
                  if (!value.contains(RegExp(r'[0-9]'))) {
                    return 'La password deve contenere almeno un numero';
                  }
                  if (!value.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'))) {
                    return 'La password deve contenere almeno un carattere speciale';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _confirmPasswordController,
                decoration: const InputDecoration(
                  labelText: 'Conferma Nuova Password',
                  border: OutlineInputBorder(),
                ),
                obscureText: true,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Conferma la nuova password';
                  }
                  if (value != _newPasswordController.text) {
                    return 'Le password non corrispondono';
                  }
                  return null;
                },
              ),
              if (_errorMessage != null) ...[
                const SizedBox(height: 16),
                Text(
                  _errorMessage!,
                  style: const TextStyle(color: Colors.red),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: _isLoading ? null : () {
              // Conferma di uscita se l'utente prova a annullare
              showDialog(
                context: context,
                builder: (BuildContext context) {
                  return AlertDialog(
                    title: const Text('Conferma'),
                    content: const Text(
                      'La tua password è scaduta e deve essere cambiata per continuare. '
                      'Sei sicuro di voler annullare? Verrai disconnesso.',
                    ),
                    actions: [
                      TextButton(
                        child: const Text('Rimani'),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                      TextButton(
                        child: const Text('Esci'),
                        onPressed: () {
                          Navigator.of(context).pop(); // Chiudi dialog conferma
                          Navigator.of(context).pop(false); // Chiudi dialog cambio password
                        },
                      ),
                    ],
                  );
                },
              );
            },
            child: const Text('Annulla'),
          ),
          ElevatedButton(
            onPressed: _isLoading ? null : _changePassword,
            child: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Cambia Password'),
          ),
        ],
      ),
    );
  }
}
