import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../blocs/state_transitions/state_transitions_bloc.dart';
import '../models/state_transition_config.dart';
import '../models/case_state.dart'; // Import for label getter

/// Screen to manage state transition configuration
class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});
  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  final Map<String, TextEditingController> _controllers = {};
  final Map<String, String?> _errors = {}; // fromStateString -> error message
  bool _wasSaving = false; // track previous saving state
  bool _initialLoaded = false; // avoid showing 'Salvato' on first load

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
        title: const Text('Pannello di amministrazione'),
        actions: [
          BlocBuilder<StateTransitionsBloc, StateTransitionsState>(
            builder: (context, state) {
              if(state is StateTransitionsLoaded){
                final canSave = state.dirty && !state.saving && !_hasLocalErrors();
                final canReset = (state.dirty || _hasLocalErrors()) && !state.saving;
                // NOTE: _wasSaving is updated in builder AFTER listener uses previous value
                _wasSaving = state.saving;
                return Row(
                  children: [
                    if(canReset)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: FilledButton.icon(
                          onPressed: () {
                            setState(() { _errors.clear(); });
                            context.read<StateTransitionsBloc>().add(ResetStateTransitions());
                          },
                          icon: const Icon(Icons.restart_alt, size: 18, ),
                          label: const Text('Reimposta'),
                        ),
                      ),
                    Padding(
                      padding: const EdgeInsets.only(right: 8, left: 4),
                      child: FilledButton.icon(
                        onPressed: canSave ? () => context.read<StateTransitionsBloc>().add(SaveStateTransitions()) : null,
                        icon: state.saving
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(Colors.white)),
                              )
                            : const Icon(Icons.save),
                        label: const Text('Salva'),
                      ),
                    ),
                  ],
                );
              }
              return const SizedBox.shrink();
            },
          ),
        ],
      ),
      body: BlocConsumer<StateTransitionsBloc, StateTransitionsState>(
        listenWhen: (p,c)=> c is StateTransitionsLoaded || c is StateTransitionsError,
        listener: (context, state) {
          if(state is StateTransitionsLoaded){
            if(!_initialLoaded){
              _initialLoaded = true; // skip snack on first successful load
              return;
            }
            if(state.error != null){
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(state.error!), backgroundColor: Colors.red.withAlpha(200)),
              );
            } else if(_wasSaving && !state.saving && !state.dirty && state.error == null){
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: const Text('Salvato'), backgroundColor: Colors.green.withAlpha(200), duration: const Duration(seconds: 1)),
              );
            }
          } else if(state is StateTransitionsError){
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.message), backgroundColor: Colors.red.withAlpha(200)),
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
          Text('Configurazione transizioni', style: const TextStyle(fontWeight: FontWeight.bold)),
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
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Colonna sinistra: cards compatte
        Expanded(
          flex: 0,
          child: Container(
            margin: const EdgeInsets.only(left: 32, top: 8, bottom: 8),
            width: 650, // Regolabile
            child: ListView.separated(
              shrinkWrap: true,
              physics: const AlwaysScrollableScrollPhysics(),
              itemCount: state.current.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
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
            ),
          ),
        ),
        // Colonna destra: placeholder
        Expanded(
          child: Container(
            margin: const EdgeInsets.only(left: 24, top: 8, right: 32, bottom: 8),
            decoration: BoxDecoration(
              color: Colors.grey.withAlpha(40),
              borderRadius: BorderRadius.circular(12),
            ),
            height: double.infinity,
            child: const Center(
              child: Text('Placeholder', style: TextStyle(color: Colors.grey, fontSize: 18)),
            ),
          ),
        ),
      ],
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

  // Column layout constants
  static const double _fromColWidth = 210;
  static const double _arrowColWidth = 32;
  static const double _toColWidth = 210;
  static const double _daysEditorWidth = 120; // ridotto
  static const double _daysFieldInnerWidth = 50; // ridotto

  Color? _background(){
    if(error != null){
      return Colors.red.withAlpha(20);
    }
    if(modified){
      return Colors.amber.withAlpha(30);
    }
    return null;
  }

  void _changeDays(BuildContext context, int delta) {
    final raw = controller.text.trim();
    final current = int.tryParse(raw) ?? 1;
    final next = (current + delta).clamp(1, 9999);
    if (next != current) {
      controller.text = next.toString();
      onChanged(next.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final fromLabel = cfg.fromState?.label ?? cfg.fromStateString;
    final toLabel = cfg.toState?.label ?? cfg.toStateString;
    final raw = controller.text.trim();
    final value = int.tryParse(raw) ?? 1;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10), // ridotto
      decoration: BoxDecoration(
        color: _background(),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: error!=null ? Colors.red : (modified ? Colors.amber : Colors.grey.withAlpha(80))),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: _fromColWidth,
            child: Text(fromLabel, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w500)),
          ),
          SizedBox(
            width: _arrowColWidth,
            child: const Center(child: Icon(Icons.arrow_forward, size: 20, color: Colors.grey)),
          ),
          SizedBox(
            width: _toColWidth,
            child: Text(toLabel, overflow: TextOverflow.ellipsis),
          ),
          SizedBox(
            width: _daysEditorWidth,
            child: IntrinsicWidth(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  IconButton(
                    padding: EdgeInsets.zero,
                    iconSize: 18,
                    icon: const Icon(Icons.remove),
                    tooltip: 'Diminuisci',
                    onPressed: enabled && error == null && value > 1 ? () => _changeDays(context, -1) : null,
                    visualDensity: VisualDensity.compact,
                    constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                  ),
                  SizedBox(
                    width: _daysFieldInnerWidth,
                    child: TextField(
                      controller: controller,
                      enabled: enabled,
                      textAlign: TextAlign.center,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: InputDecoration(
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
                        labelText: 'Giorni',
                        labelStyle: const TextStyle(fontSize: 10),
                        errorText: error,
                      ),
                      onChanged: onChanged,
                    ),
                  ),
                  IconButton(
                    padding: EdgeInsets.zero,
                    iconSize: 18,
                    icon: const Icon(Icons.add),
                    tooltip: 'Aumenta',
                    onPressed: enabled && error == null ? () => _changeDays(context, 1) : null,
                    visualDensity: VisualDensity.compact,
                    constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                  ),
                ],
              ),
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
