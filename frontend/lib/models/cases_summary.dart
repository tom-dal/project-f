class CasesSummary {
  final int totalActiveCases;
  final int dueToday;
  final int dueNext7Days;
  final Map<String, int> states; // raw enum names from backend

  CasesSummary({
    required this.totalActiveCases,
    required this.dueToday,
    required this.dueNext7Days,
    required this.states,
  });

  factory CasesSummary.fromJson(Map<String, dynamic> json) {
    final rawStates = (json['states'] as Map<String, dynamic>?) ?? {};
    final mapped = <String, int>{};
    rawStates.forEach((k, v) {
      mapped[k] = (v as num).toInt();
    });
    return CasesSummary(
      totalActiveCases: (json['totalActiveCases'] as num?)?.toInt() ?? 0,
      dueToday: (json['dueToday'] as num?)?.toInt() ?? 0,
      dueNext7Days: (json['dueNext7Days'] as num?)?.toInt() ?? 0,
      states: mapped,
    );
  }

  static const Map<String, String> readableStateNames = {
    'MESSA_IN_MORA_DA_FARE': 'Messa in mora da fare',
    'MESSA_IN_MORA_INVIATA': 'Messa in mora inviata',
    'DEPOSITO_RICORSO': 'Deposito ricorso',
    'DECRETO_INGIUNTIVO_DA_NOTIFICARE': 'Decreto ingiuntivo da notificare',
    'DECRETO_INGIUNTIVO_NOTIFICATO': 'Decreto ingiuntivo notificato',
    'CONTESTAZIONE_DA_RISCONTRARE': 'Contestazione da riscontrare',
    'PIGNORAMENTO': 'Pignoramento',
    'PRECETTO': 'Precetto',
  };

  String readableStateLabel(String raw) => readableStateNames[raw] ?? raw;
}

