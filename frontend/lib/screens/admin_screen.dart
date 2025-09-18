import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../blocs/state_transitions/state_transitions_bloc.dart';
import '../models/state_transition_config.dart';

/// Screen to manage state transition configuration
class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});
  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  final Map<String, TextEditingController> _controllers = {};
  final Map<String, String?> _errors = {}; // fromStateString -> error message

  @override
  void dispose() {
    for (final c in _controllers.values) { c.dispose(); }
    super.dispose();
  }

  void _syncControllers(List<StateTransitionConfigModel> list){
    // Create or update controllers only if value differs from text to avoid cursor jump
    for(final cfg in list){
      final key = cfg.fromStateString;
      final valueString = cfg.daysToTransition.toString();
      if(!_controllers.containsKey(key)){
        _controllers[key] = TextEditingController(text: valueString);
      } else if(_controllers[key]!.text != valueString){
        _controllers[key]!.text = valueString;
      }
    }
    // Remove controllers for removed entries (unlikely but safe)
    final existingKeys = list.map((e)=>e.fromStateString).toSet();
    final toRemove = _controllers.keys.where((k)=>!existingKeys.contains(k)).toList();
    for(final k in toRemove){ _controllers.remove(k)?.dispose(); }
  }

  bool _hasLocalErrors()=> _errors.values.any((e)=> e != null && e.isNotEmpty);

  void _onChanged(String fromState, String raw, StateTransitionsLoaded state){
    String? error;
    if(raw.trim().isEmpty){
      error = 'Obbligatorio';
    } else {
      final v = int.tryParse(raw);
      if(v == null){
        error = 'Numero non valido';
      } else if(v <= 0){
        error = 'Deve essere > 0';
      } else {
        // valid -> dispatch if changed
        final currentModel = state.current.firstWhere((c)=>c.fromStateString == fromState);
        if(currentModel.daysToTransition != v){
          context.read<StateTransitionsBloc>().add(EditStateTransitionDays(fromState, v));
        }
      }
    }
    setState(()=> _errors[fromState] = error);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Configurazione Transizioni Stati'),
        actions: [
          IconButton(
            tooltip: 'Ricarica',
            onPressed: () => context.read<StateTransitionsBloc>().add(RefreshStateTransitions()),
            icon: const Icon(Icons.refresh),
          ),
          IconButton(
            tooltip: 'Chiudi',
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close),
          ),
        ],
      ),
      body: BlocConsumer<StateTransitionsBloc, StateTransitionsState>(
        listenWhen: (p,c)=> c is StateTransitionsLoaded || c is StateTransitionsError,
        listener: (context, state) {
          if(state is StateTransitionsLoaded && state.error != null){
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.error!), backgroundColor: Colors.red.withAlpha(200)),
            );
          } else if(state is StateTransitionsLoaded && !state.dirty && !state.saving){
            // After successful save (dirty becomes false)
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: const Text('Salvato'), backgroundColor: Colors.green.withAlpha(200), duration: const Duration(seconds: 1)),
            );
          }
        },
        builder: (context, state) {
          if(state is StateTransitionsLoading || state is StateTransitionsInitial){
            return const Center(child: CircularProgressIndicator());
          }
          if(state is StateTransitionsError){
            return _buildError(state.message);
          }
          if(state is StateTransitionsLoaded){
            _syncControllers(state.current);
            return Column(
              children: [
                if(state.saving) const LinearProgressIndicator(minHeight: 3),
                _buildHeaderBar(state),
                const Divider(height: 1),
                Expanded(child: _buildList(state)),
                const Divider(height: 1),
                _buildActionsBar(state),
              ],
            );
          }
          return const SizedBox.shrink();
        },
      ),
    );
  }

  Widget _buildError(String message){
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, size: 48, color: Colors.red),
          const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 16),
          OutlinedButton(
            onPressed: () => context.read<StateTransitionsBloc>().add(LoadStateTransitions()),
            child: const Text('Riprova'),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderBar(StateTransitionsLoaded state){
    final dirty = state.dirty;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      alignment: Alignment.centerLeft,
      child: Row(
        children: [
          Text('Configurazioni (${state.current.length})', style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(width: 16),
          if(dirty) const _DirtyBadge(),
        ],
      ),
    );
  }

  Widget _buildList(StateTransitionsLoaded state){
    if(state.current.isEmpty){
      return const Center(child: Text('Nessuna configurazione'));
    }
    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: state.current.length,
      separatorBuilder: (_, __) => const SizedBox(height: 4),
      itemBuilder: (context, index){
        final cfg = state.current[index];
        final original = state.original.firstWhere((o)=>o.fromStateString == cfg.fromStateString);
        final modified = original.daysToTransition != cfg.daysToTransition;
        final controller = _controllers[cfg.fromStateString]!;
        final error = _errors[cfg.fromStateString];
        return _ConfigRow(
          cfg: cfg,
          controller: controller,
          modified: modified,
          error: error,
          enabled: !state.saving,
          onChanged: (val)=> _onChanged(cfg.fromStateString, val, state),
        );
      },
    );
  }

  Widget _buildActionsBar(StateTransitionsLoaded state){
    final bloc = context.read<StateTransitionsBloc>();
    final dirty = state.dirty;
    final disabled = state.saving || _hasLocalErrors();
    return Container(
      padding: const EdgeInsets.fromLTRB(16,8,16,16),
      child: Row(
        children: [
          OutlinedButton(
            onPressed: state.saving ? null : () => bloc.add(RefreshStateTransitions()),
            child: const Text('Ricarica'),
          ),
          const SizedBox(width: 8),
          OutlinedButton(
            onPressed: (!dirty || state.saving) ? null : () => bloc.add(ResetStateTransitions()),
            child: const Text('Annulla modifiche'),
          ),
          const SizedBox(width: 8),
          OutlinedButton(
            onPressed: state.saving ? null : () => Navigator.of(context).pop(),
            child: const Text('Chiudi'),
          ),
          const Spacer(),
          FilledButton.icon(
            onPressed: (!dirty || disabled) ? null : () => bloc.add(SaveStateTransitions()),
            icon: const Icon(Icons.save),
            label: const Text('Salva'),
          ),
        ],
      ),
    );
  }
}

class _ConfigRow extends StatelessWidget {
  final StateTransitionConfigModel cfg;
  final TextEditingController controller;
  final bool modified;
  final bool enabled;
  final String? error;
  final ValueChanged<String> onChanged;
  const _ConfigRow({required this.cfg, required this.controller, required this.modified, required this.enabled, required this.error, required this.onChanged});

  Color? _background(){
    if(error != null){
      return Colors.red.withAlpha(20);
    }
    if(modified){
      return Colors.amber.withAlpha(30);
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: _background(),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: error!=null ? Colors.red : (modified ? Colors.amber : Colors.grey.withAlpha(80))),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(cfg.fromStateString, style: const TextStyle(fontWeight: FontWeight.w500)),
          ),
          Expanded(
            flex: 2,
            child: Text(cfg.toStateString),
          ),
          Expanded(
            flex: 2,
            child: TextField(
              controller: controller,
              enabled: enabled,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: InputDecoration(
                labelText: 'Giorni',
                isDense: true,
                errorText: error,
              ),
              onChanged: onChanged,
            ),
          ),
          const SizedBox(width: 8),
          if(modified) const Icon(Icons.edit, size: 18, color: Colors.amber),
          if(error!=null) const Icon(Icons.warning_amber_rounded, size: 18, color: Colors.red),
        ],
      ),
    );
  }
}

class _DirtyBadge extends StatelessWidget {
  const _DirtyBadge();
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.amber.withAlpha(180),
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Text('Modifiche non salvate', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
    );
  }
}

