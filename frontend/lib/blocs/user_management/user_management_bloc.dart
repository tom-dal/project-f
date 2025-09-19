import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../services/api_service.dart';
import '../../models/user.dart';

// Events
abstract class UserManagementEvent extends Equatable { @override List<Object?> get props => []; }
class LoadUsers extends UserManagementEvent {}
class CreateUserRequested extends UserManagementEvent { final String username; final String password; final List<String> roles; final bool passwordExpired; CreateUserRequested({required this.username, required this.password, required this.roles, required this.passwordExpired}); @override List<Object?> get props => [username, roles, passwordExpired]; }
class UpdateUserRequested extends UserManagementEvent { final String id; final String username; final String? password; final List<String> roles; final bool passwordExpired; UpdateUserRequested({required this.id, required this.username, this.password, required this.roles, required this.passwordExpired}); @override List<Object?> get props => [id, username, roles, passwordExpired, password]; }
class DeleteUserRequested extends UserManagementEvent { final String id; DeleteUserRequested(this.id); @override List<Object?> get props => [id]; }
class ClearFeedback extends UserManagementEvent {}

// State
class UserManagementState extends Equatable {
  final bool loading; // caricamento lista iniziale
  final bool processing; // operazioni mutate (create/update/delete)
  final List<UserModel> users;
  final String? error;
  final String? successMessage;
  final String? currentUsername;
  const UserManagementState({this.loading=false, this.processing=false, this.users=const [], this.error, this.successMessage, this.currentUsername});
  UserManagementState copy({bool? loading, bool? processing, List<UserModel>? users, String? error, String? successMessage, String? currentUsername}) => UserManagementState(
    loading: loading ?? this.loading,
    processing: processing ?? this.processing,
    users: users ?? this.users,
    error: error,
    successMessage: successMessage,
    currentUsername: currentUsername ?? this.currentUsername,
  );
  @override List<Object?> get props => [loading, processing, users, error, successMessage, currentUsername];
}

class UserManagementBloc extends Bloc<UserManagementEvent, UserManagementState> {
  final ApiService apiService;
  UserManagementBloc(this.apiService): super(const UserManagementState(loading: true)){
    on<LoadUsers>(_onLoad);
    on<CreateUserRequested>(_onCreate);
    on<UpdateUserRequested>(_onUpdate);
    on<DeleteUserRequested>(_onDelete);
    on<ClearFeedback>((e,emit)=> emit(state.copy(error:null, successMessage:null)));
    add(LoadUsers());
  }

  Future<void> _onLoad(LoadUsers event, Emitter<UserManagementState> emit) async {
    emit(state.copy(loading: true, error: null, successMessage: null));
    try {
      final list = await apiService.getUsers();
      final currentUser = await apiService.getCurrentUsername();
      emit(state.copy(loading: false, users: list, currentUsername: currentUser));
    } catch (e){
      emit(state.copy(loading: false, error: e.toString()));
    }
  }

  Future<void> _onCreate(CreateUserRequested event, Emitter<UserManagementState> emit) async {
    emit(state.copy(processing: true, error: null, successMessage: null));
    try {
      final created = await apiService.createUser(username: event.username, password: event.password, roles: event.roles, passwordExpired: event.passwordExpired);
      final updated = List<UserModel>.from(state.users)..add(created);
      emit(state.copy(processing: false, users: updated, successMessage: 'Utente creato'));
    } catch(e){
      emit(state.copy(processing: false, error: e.toString()));
    }
  }

  Future<void> _onUpdate(UpdateUserRequested event, Emitter<UserManagementState> emit) async {
    emit(state.copy(processing: true, error: null, successMessage: null));
    try {
      final updatedUser = await apiService.updateUser(id: event.id, username: event.username, password: event.password, roles: event.roles, passwordExpired: event.passwordExpired);
      final updatedList = state.users.map((u)=> u.id == updatedUser.id ? updatedUser : u).toList();
      emit(state.copy(processing: false, users: updatedList, successMessage: 'Utente aggiornato'));
    } catch(e){
      emit(state.copy(processing: false, error: e.toString()));
    }
  }

  Future<void> _onDelete(DeleteUserRequested event, Emitter<UserManagementState> emit) async {
    emit(state.copy(processing: true, error: null, successMessage: null));
    try {
      await apiService.deleteUser(event.id);
      final updatedList = state.users.where((u)=> u.id != event.id).toList();
      emit(state.copy(processing: false, users: updatedList, successMessage: 'Utente eliminato'));
    } catch(e){
      emit(state.copy(processing: false, error: e.toString()));
    }
  }
}

