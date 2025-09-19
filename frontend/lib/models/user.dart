import 'package:equatable/equatable.dart';

class UserModel extends Equatable {
  final String id;
  final String username;
  final List<String> roles;
  final bool passwordExpired;
  const UserModel({required this.id, required this.username, required this.roles, required this.passwordExpired});
  factory UserModel.fromJson(Map<String,dynamic> json){
    return UserModel(
      id: json['id']?.toString() ?? '',
      username: json['username'] ?? '',
      roles: (json['roles'] as List?)?.map((e)=> e.toString()).toList() ?? const [],
      passwordExpired: json['passwordExpired'] == true,
    );
  }
  Map<String,dynamic> toJson()=> {
    'id': id,
    'username': username,
    'roles': roles,
    'passwordExpired': passwordExpired,
  };
  UserModel copyWith({String? id, String? username, List<String>? roles, bool? passwordExpired})=> UserModel(
    id: id ?? this.id,
    username: username ?? this.username,
    roles: roles ?? this.roles,
    passwordExpired: passwordExpired ?? this.passwordExpired,
  );
  @override
  List<Object?> get props => [id, username, roles, passwordExpired];
}

class EditingUserDraft extends Equatable {
  final String? id; // null -> create
  final String username;
  final String password; // empty if unchanged in update
  final List<String> roles; // at least one
  final bool passwordExpired;
  const EditingUserDraft({this.id, required this.username, required this.password, required this.roles, required this.passwordExpired});
  bool get isCreate => id == null;
  EditingUserDraft copyWith({String? id, String? username, String? password, List<String>? roles, bool? passwordExpired}) => EditingUserDraft(
    id: id ?? this.id,
    username: username ?? this.username,
    password: password ?? this.password,
    roles: roles ?? this.roles,
    passwordExpired: passwordExpired ?? this.passwordExpired,
  );
  @override
  List<Object?> get props => [id, username, password, roles, passwordExpired];
}

