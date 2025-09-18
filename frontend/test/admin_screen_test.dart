import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:dio/dio.dart';

import 'package:project_f_frontend/blocs/state_transitions/state_transitions_bloc.dart';
import 'package:project_f_frontend/models/state_transition_config.dart';
import 'package:project_f_frontend/services/api_service.dart';
import 'package:project_f_frontend/screens/admin_screen.dart';

// Fake ApiService overriding only the required methods for this screen
class TestApiService extends ApiService {
  final List<StateTransitionConfigModel> _configs = [
    StateTransitionConfigModel(fromStateString: 'MESSA_IN_MORA_DA_FARE', toStateString: 'MESSA_IN_MORA_INVIATA', daysToTransition: 10),
    StateTransitionConfigModel(fromStateString: 'MESSA_IN_MORA_INVIATA', toStateString: 'CONTESTAZIONE_DA_RISCONTRARE', daysToTransition: 5),
    StateTransitionConfigModel(fromStateString: 'CONTESTAZIONE_DA_RISCONTRARE', toStateString: 'DEPOSITO_RICORSO', daysToTransition: 7),
  ];

  TestApiService(): super(Dio(BaseOptions(baseUrl: 'http://localhost')));

  @override
  Future<List<StateTransitionConfigModel>> getStateTransitions() async {
    await Future.delayed(const Duration(milliseconds: 50));
    return _configs.map((c)=>c.copy()).toList();
  }

  @override
  Future<List<StateTransitionConfigModel>> updateStateTransitions(List<StateTransitionConfigModel> list) async {
    await Future.delayed(const Duration(milliseconds: 50));
    _configs.clear();
    _configs.addAll(list.map((e)=>e.copy()));
    return _configs.map((c)=>c.copy()).toList();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Widget _buildTestWidget(ApiService apiService){
    return MaterialApp(
      home: BlocProvider(
        create: (_) => StateTransitionsBloc(apiService)..add(LoadStateTransitions()),
        child: const AdminScreen(),
      ),
    );
  }

  testWidgets('Carica configurazioni, modifica un valore e salva', (tester) async {
    final api = TestApiService();
    await tester.pumpWidget(_buildTestWidget(api));

    // Initial loading
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    // Let it load
    await tester.pumpAndSettle(const Duration(milliseconds: 300));

    // Header present with count
    expect(find.textContaining('Configurazioni'), findsOneWidget);

    // Find first TextField and change value
    final firstField = find.byType(TextField).first;
    expect(firstField, findsOneWidget);

    await tester.enterText(firstField, '11');
    await tester.pump(const Duration(milliseconds: 50));

    // Save button should now be enabled
    final saveButton = find.widgetWithText(FilledButton, 'Salva');
    expect(saveButton, findsOneWidget);
    // Tap save
    await tester.tap(saveButton);
    await tester.pump();

    // Show linear progress then success snackbar
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pumpAndSettle(const Duration(milliseconds: 600));

    // Snackbar message
    expect(find.text('Salvato'), findsOneWidget);
  });
}

