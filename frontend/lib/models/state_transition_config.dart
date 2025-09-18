import 'case_state.dart';

class StateTransitionConfigModel {
  final String fromStateString;
  final String toStateString;
  int daysToTransition;

  StateTransitionConfigModel({
    required this.fromStateString,
    required this.toStateString,
    required this.daysToTransition,
  });

  factory StateTransitionConfigModel.fromJson(Map<String,dynamic> json){
    return StateTransitionConfigModel(
      fromStateString: json['fromState'] as String,
      toStateString: json['toState'] as String,
      daysToTransition: (json['daysToTransition'] as num).toInt(),
    );
  }

  Map<String,dynamic> toJson()=>{
    'fromState': fromStateString,
    'toState': toStateString,
    'daysToTransition': daysToTransition,
  };

  CaseState? get fromState => _parse(fromStateString);
  CaseState? get toState => _parse(toStateString);

  StateTransitionConfigModel copy()=> StateTransitionConfigModel(
    fromStateString: fromStateString,
    toStateString: toStateString,
    daysToTransition: daysToTransition,
  );

  static CaseState? _parse(String v){
    switch(v){
      case 'MESSA_IN_MORA_DA_FARE': return CaseState.messaInMoraDaFare;
      case 'MESSA_IN_MORA_INVIATA': return CaseState.messaInMoraInviata;
      case 'CONTESTAZIONE_DA_RISCONTRARE': return CaseState.contestazioneDaRiscontrare;
      case 'DEPOSITO_RICORSO': return CaseState.depositoRicorso;
      case 'DECRETO_INGIUNTIVO_DA_NOTIFICARE': return CaseState.decretoIngiuntivoDaNotificare;
      case 'DECRETO_INGIUNTIVO_NOTIFICATO': return CaseState.decretoIngiuntivoNotificato;
      case 'PRECETTO': return CaseState.precetto;
      case 'PIGNORAMENTO': return CaseState.pignoramento;
      case 'COMPLETATA': return CaseState.completata;
    }
    return null;
  }
}

