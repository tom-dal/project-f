import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:provider/provider.dart';
import '../blocs/user_management/user_management_bloc.dart';
import '../models/user.dart';
import '../services/api_service.dart';

class UserManagementPanel extends StatelessWidget {
  const UserManagementPanel({super.key});
  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => UserManagementBloc(context.read<ApiService>()),
      child: const _UserPanelBody(),
    );
  }
}

class _UserPanelBody extends StatelessWidget {
  const _UserPanelBody();
  @override
  Widget build(BuildContext context) {
    return BlocConsumer<UserManagementBloc, UserManagementState>(
      listenWhen: (p,c)=> p.error!=c.error || p.successMessage!=c.successMessage,
      listener: (context,state){
        if(state.error!=null){
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(state.error!), backgroundColor: Colors.red.withAlpha(200)),
          );
          context.read<UserManagementBloc>().add(ClearFeedback());
        } else if(state.successMessage!=null){
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(state.successMessage!), backgroundColor: Colors.green.withAlpha(200), duration: const Duration(seconds: 1)),
          );
          context.read<UserManagementBloc>().add(ClearFeedback());
        }
      },
      builder: (context,state){
        if(state.loading){
          return const Center(child: CircularProgressIndicator());
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Header(processing: state.processing),
            const Divider(height:1),
            Expanded(
              child: state.users.isEmpty
                ? const Center(child: Text('Nessun utente'))
                : ListView.separated(
                    padding: const EdgeInsets.all(12),
                    itemBuilder: (ctx,i){
                      final u = state.users[i];
                      final isSelf = u.username == state.currentUsername;
                      return _UserRow(user: u, isSelf: isSelf);
                    },
                    separatorBuilder: (_,__)=> const SizedBox(height:8),
                    itemCount: state.users.length,
                  ),
            ),
            if(state.processing) const LinearProgressIndicator(minHeight:3),
          ],
        );
      },
    );
  }
}

class _Header extends StatelessWidget {
  final bool processing;
  const _Header({required this.processing});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal:16, vertical:12),
      child: Row(
        children: [
          const Expanded(child: Text('Gestione utenti', style: TextStyle(fontWeight: FontWeight.bold))),
          FilledButton.icon(
            onPressed: processing ? null : () => _showUserDialog(context),
            icon: const Icon(Icons.person_add),
            label: const Text('Nuovo utente'),
          ),
        ],
      ),
    );
  }
}

class _UserRow extends StatelessWidget {
  final UserModel user; final bool isSelf;
  const _UserRow({required this.user, required this.isSelf});
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.withAlpha(80)),
      ),
      padding: const EdgeInsets.symmetric(horizontal:12, vertical:10),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children:[
                  Text(user.username, style: const TextStyle(fontWeight: FontWeight.w600)),
                  if(isSelf) Padding(padding: const EdgeInsets.only(left:6), child: Container(padding: const EdgeInsets.symmetric(horizontal:6, vertical:2), decoration: BoxDecoration(color: Colors.blue.withAlpha(40), borderRadius: BorderRadius.circular(8)), child: const Text('Tu', style: TextStyle(fontSize:10))))
                ]),
                const SizedBox(height:4),
                Wrap(spacing:6, runSpacing:4,
                  children: [
                    Text('Ruoli: ', style: TextStyle(fontSize:12, color: Colors.grey[700])),
                    for(final r in user.roles)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal:6, vertical:2),
                        decoration: BoxDecoration(color: r=='ADMIN'? Colors.orange.withAlpha(50): Colors.green.withAlpha(50), borderRadius: BorderRadius.circular(12)),
                        child: Text(r, style: TextStyle(fontSize:11, color: r=='ADMIN'? Colors.orange[900]: Colors.green[900])),
                      ),
                    if(user.passwordExpired)
                      Container(padding: const EdgeInsets.symmetric(horizontal:6, vertical:2), decoration: BoxDecoration(color: Colors.red.withAlpha(40), borderRadius: BorderRadius.circular(12)), child: const Text('Password scaduta', style: TextStyle(fontSize:11, color: Colors.red)))
                  ],
                ),
              ],
            ),
          ),
          Offstage(
            offstage: !isSelf && user.roles.contains('ADMIN'),
            child: IconButton(
              tooltip: 'Modifica',
              icon: const Icon(Icons.edit),
              onPressed: () => _showUserDialog(context, existing: user),
            ),
          ),
          Offstage(
            offstage: isSelf || user.roles.contains('ADMIN'),
            child: IconButton(
              tooltip: isSelf? 'Non puoi eliminare te stesso' : 'Elimina',
              icon: Icon(Icons.delete, color: isSelf? Colors.grey: Colors.red),
              onPressed: isSelf? null : () async {
                final confirmed = await showDialog<bool>(context: context, builder: (ctx)=> AlertDialog(
                  title: const Text('Conferma eliminazione'),
                  content: Text('Eliminare l\'utente "${user.username}"?'),
                  actions: [
                    TextButton(onPressed: ()=> Navigator.pop(ctx,false), child: const Text('Annulla')),
                    FilledButton(onPressed: ()=> Navigator.pop(ctx,true), child: const Text('Elimina')),
                  ],
                ));
                if(confirmed == true){ context.read<UserManagementBloc>().add(DeleteUserRequested(user.id)); }
              },
            ),
          ),
        ],
      ),
    );
  }
}

void _showUserDialog(BuildContext context, {UserModel? existing}) {
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (dialogCtx){
      return BlocProvider.value(
        value: context.read<UserManagementBloc>(),
        child: _UserDialog(existing: existing),
      );
    }
  );
}

class _UserDialog extends StatefulWidget {
  final UserModel? existing;
  const _UserDialog({this.existing});
  @override
  State<_UserDialog> createState() => _UserDialogState();
}

class _UserDialogState extends State<_UserDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _usernameCtrl;
  late TextEditingController _passwordCtrl;
  bool _changePassword = false;
  bool _passwordExpired = false;
  final List<String> _allRoles = const ['ADMIN','USER'];
  late List<String> _selectedRoles;

  @override
  void initState() {
    super.initState();
    final ex = widget.existing;
    _usernameCtrl = TextEditingController(text: ex?.username ?? '');
    _passwordCtrl = TextEditingController();
    _passwordExpired = ex?.passwordExpired ?? false;
    _selectedRoles = List<String>.from(ex?.roles ?? ['USER']);
  }

  @override
  void dispose() {
    _usernameCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  void _submit(){
    if(!_formKey.currentState!.validate()) return;
    final bloc = context.read<UserManagementBloc>();
    final username = _usernameCtrl.text.trim();
    final password = widget.existing == null ? _passwordCtrl.text : (_changePassword ? _passwordCtrl.text : null);
    if(widget.existing == null){
      bloc.add(CreateUserRequested(username: username, password: password ?? '', roles: _selectedRoles, passwordExpired: _passwordExpired));
    } else {
      bloc.add(UpdateUserRequested(id: widget.existing!.id, username: username, password: password, roles: _selectedRoles, passwordExpired: _passwordExpired));
    }
  }

  @override
  Widget build(BuildContext context) {
    final processing = context.watch<UserManagementBloc>().state.processing;
    return BlocListener<UserManagementBloc, UserManagementState>(
      listenWhen: (p,c)=> p.processing && !c.processing,
      listener: (context,state){ if(state.error==null){ Navigator.of(context).pop(); } },
      child: AlertDialog(
        title: Text(widget.existing==null? 'Nuovo utente' : 'Modifica utente'),
        content: SizedBox(
          width: 420,
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: _usernameCtrl,
                    decoration: const InputDecoration(labelText: 'Username'),
                    validator: (v){ if(v==null || v.trim().isEmpty) return 'Obbligatorio'; if(v.trim().length<3) return 'Min 3 caratteri'; return null; },
                    enabled: !processing,
                  ),
                  const SizedBox(height:12),
                  if(widget.existing==null) ...[
                    TextFormField(
                      controller: _passwordCtrl,
                      decoration: const InputDecoration(labelText: 'Password'),
                      obscureText: true,
                      validator: (v){
                        if(v==null || v.isEmpty) return 'Obbligatoria';
                        if(v.length<8) return 'Minimo 8 caratteri';
                        if(!RegExp(r'[A-Z]').hasMatch(v)) return 'Almeno una maiuscola';
                        if(!RegExp(r'[0-9]').hasMatch(v)) return 'Almeno un numero';
                        if(!RegExp(r'[!@#\$%^&*(),.?":{}|<>_\-]').hasMatch(v)) return 'Almeno un carattere speciale';
                        return null;
                      },
                      enabled: !processing,
                    ),
                  ] else ...[
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Modifica password'),
                      value: _changePassword,
                      onChanged: processing ? null : (val){ setState(()=>_changePassword = val); },
                    ),
                    if(_changePassword)
                      TextFormField(
                        controller: _passwordCtrl,
                        decoration: const InputDecoration(labelText: 'Nuova password'),
                        obscureText: true,
                        validator: (v){
                          if(!_changePassword) return null;
                          if(v==null || v.isEmpty) return 'Obbligatoria';
                          if(v.length<8) return 'Minimo 8 caratteri';
                          if(!RegExp(r'[A-Z]').hasMatch(v)) return 'Almeno una maiuscola';
                          if(!RegExp(r'[0-9]').hasMatch(v)) return 'Almeno un numero';
                          if(!RegExp(r'[!@#\$%^&*(),.?":{}|<>_\-]').hasMatch(v)) return 'Almeno un carattere speciale';
                          return null;
                        },
                        enabled: !processing,
                      ),
                  ],
                  const SizedBox(height:12),
                  Align(alignment: Alignment.centerLeft, child: Text('Ruoli', style: TextStyle(color: Colors.grey[700], fontWeight: FontWeight.w500))),
                  const SizedBox(height:4),
                  Wrap(spacing:8, runSpacing:4,
                    children: _allRoles.map((r){
                      final selected = _selectedRoles.contains(r) || _selectedRoles.contains('ADMIN');
                      return FilterChip(
                        label: Text(r),
                        selected: selected,
                        onSelected: processing ? null : (val){
                          setState((){
                            if(val){ if(!_selectedRoles.contains(r)) _selectedRoles.add(r); }
                            else { _selectedRoles.remove(r); if(_selectedRoles.isEmpty) _selectedRoles.add(r); }
                          });
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height:12),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Password scaduta'),
                    value: _passwordExpired,
                    onChanged: processing ? null : (val)=> setState(()=> _passwordExpired = val),
                  ),
                ],
              ),
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: processing ? null : ()=> Navigator.of(context).pop(), child: const Text('Annulla')),
            FilledButton(
            onPressed: processing ? null : _submit,
            child: processing ? const SizedBox(width:16,height:16,child:CircularProgressIndicator(strokeWidth:2)) : const Text('Salva'),
          ),
        ],
      ),
    );
  }
}
