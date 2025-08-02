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
