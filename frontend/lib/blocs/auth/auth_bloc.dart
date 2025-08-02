import 'dart:developer' as developer;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../services/api_service.dart';

// Events
abstract class AuthEvent extends Equatable {
  const AuthEvent();
 ///////////
  @override
  List<Object?> get props => [];
}

class CheckAuthStatus extends AuthEvent {}

class LoginRequested extends AuthEvent {
  final String username;
  final String password;

  const LoginRequested(this.username, this.password);

  @override
  List<Object?> get props => [username, password];
}

class ChangePasswordRequested extends AuthEvent {
  final String oldPassword;
  final String newPassword;

  const ChangePasswordRequested(this.oldPassword, this.newPassword);

  @override
  List<Object?> get props => [oldPassword, newPassword];
}

class LogoutRequested extends AuthEvent {}

// States
abstract class AuthState extends Equatable {
  const AuthState();

  @override
  List<Object?> get props => [];
}

class AuthInitial extends AuthState {}

class AuthUnauthenticated extends AuthState {}

class AuthLoading extends AuthState {}

class AuthAuthenticated extends AuthState {
  final String token;
  final bool passwordExpired;

  const AuthAuthenticated(this.token, {this.passwordExpired = false});

  @override
  List<Object?> get props => [token, passwordExpired];
}

class AuthError extends AuthState {
  final String message;

  const AuthError(this.message);

  @override
  List<Object?> get props => [message];
}

// Bloc
class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final ApiService apiService;

  AuthBloc({required this.apiService}) : super(AuthInitial()) {
    on<CheckAuthStatus>(_onCheckAuthStatus);
    on<LoginRequested>(_onLoginRequested);
    on<ChangePasswordRequested>(_onChangePasswordRequested);
    on<LogoutRequested>(_onLogoutRequested);

    // Check auth status when bloc is created
    add(CheckAuthStatus());
  }

  Future<void> _onCheckAuthStatus(
    CheckAuthStatus event,
    Emitter<AuthState> emit,
  ) async {
    developer.log('🔍 AUTH BLOC - Checking auth status');
    emit(AuthLoading());
    try {
      final token = await apiService.getStoredToken();
      developer.log('🎫 AUTH BLOC - Token from storage: ${token != null ? 'FOUND (${token.length} chars)' : 'NOT FOUND'}');
      
      if (token != null) {
        // Prima verifica se è un token di cambio password
        developer.log('🔄 AUTH BLOC - Checking if token is password change token');
        final isPasswordExpired = await apiService.isPasswordChangeToken();
        developer.log('⏰ AUTH BLOC - Is password expired token: $isPasswordExpired');
        
        if (isPasswordExpired) {
          // Se è un token di cambio password, l'utente è "autenticato" ma deve cambiare la password
          developer.log('✅ AUTH BLOC - Emitting authenticated with password expired');
          emit(AuthAuthenticated(token, passwordExpired: true));
        } else {
          // Altrimenti, valida il token normale
          developer.log('🔍 AUTH BLOC - Validating regular token');
          final isValid = await apiService.validateToken();
          developer.log('✅ AUTH BLOC - Token validation result: $isValid');
          
          if (isValid) {
            developer.log('✅ AUTH BLOC - Emitting authenticated (normal)');
            emit(AuthAuthenticated(token, passwordExpired: false));
          } else {
            developer.log('❌ AUTH BLOC - Token invalid, emitting unauthenticated');
            emit(AuthUnauthenticated());
          }
        }
      } else {
        developer.log('❌ AUTH BLOC - No token found, emitting unauthenticated');
        emit(AuthUnauthenticated());
      }
    } catch (e) {
      developer.log('💥 AUTH BLOC - Error checking auth status: $e');
      emit(AuthError(e.toString()));
    }
  }

  Future<void> _onLoginRequested(
    LoginRequested event,
    Emitter<AuthState> emit,
  ) async {
    developer.log('🚀 AUTH BLOC - Login requested for user: ${event.username}');
    emit(AuthLoading());
    try {
      final response = await apiService.login(event.username, event.password);
      developer.log('✅ AUTH BLOC - Login successful, passwordExpired: ${response.passwordExpired}');
      emit(AuthAuthenticated(response.token, passwordExpired: response.passwordExpired));
    } catch (e) {
      developer.log('❌ AUTH BLOC - Login failed: $e');
      emit(AuthError(e.toString()));
    }
  }

  Future<void> _onChangePasswordRequested(
    ChangePasswordRequested event,
    Emitter<AuthState> emit,
  ) async {
    developer.log('🔄 AUTH BLOC - Change password requested');
    developer.log('🔐 AUTH BLOC - Old password length: ${event.oldPassword.length}');
    developer.log('🔐 AUTH BLOC - New password length: ${event.newPassword.length}');
    
    emit(AuthLoading());
    try {
      final response = await apiService.changePassword(event.oldPassword, event.newPassword);
      developer.log('✅ AUTH BLOC - Password change successful');
      emit(AuthAuthenticated(response.token, passwordExpired: false));
    } catch (e) {
      developer.log('❌ AUTH BLOC - Password change failed: $e');
      emit(AuthError(e.toString()));
    }
  }

  Future<void> _onLogoutRequested(
    LogoutRequested event,
    Emitter<AuthState> emit,
  ) async {
    await apiService.deleteToken();
    emit(AuthUnauthenticated());
  }
} 
