import 'package:json_annotation/json_annotation.dart';

enum CaseState {
  @JsonValue('MESSA_IN_MORA_DA_FARE')
  messaInMoraDaFare,
  @JsonValue('MESSA_IN_MORA_INVIATA')
  messaInMoraInviata,
  @JsonValue('CONTESTAZIONE_DA_RISCONTRARE')
  contestazioneDaRiscontrare,
  @JsonValue('DEPOSITO_RICORSO')
  depositoRicorso,
  @JsonValue('DECRETO_INGIUNTIVO_DA_NOTIFICARE')
  decretoIngiuntivoDaNotificare,
  @JsonValue('DECRETO_INGIUNTIVO_NOTIFICATO')
  decretoIngiuntivoNotificato,
  @JsonValue('PRECETTO')
  precetto,
  @JsonValue('PIGNORAMENTO')
  pignoramento,
  @JsonValue('COMPLETATA')
  completata,
}

extension CaseStateLabel on CaseState {
  String get label {
    switch (this) {
      case CaseState.messaInMoraDaFare:
        return 'Messa in Mora da Fare';
      case CaseState.messaInMoraInviata:
        return 'Messa in Mora Inviata';
      case CaseState.contestazioneDaRiscontrare:
        return 'Contestazione da Riscontrare';
      case CaseState.depositoRicorso:
        return 'Deposito Ricorso';
      case CaseState.decretoIngiuntivoDaNotificare:
        return 'DI da Notificare';
      case CaseState.decretoIngiuntivoNotificato:
        return 'DI Notificato';
      case CaseState.precetto:
        return 'Precetto';
      case CaseState.pignoramento:
        return 'Pignoramento';
      case CaseState.completata:
        return 'Completata';
    }
  }
}
