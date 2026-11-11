import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:trabalho_final/main.dart';
import 'package:trabalho_final/models/user_profile.dart';
import 'package:trabalho_final/services/database_service.dart';
import 'package:trabalho_final/state/app_state.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('Fase 1: Central de Demonstração (Demo Hub) e Gerenciamento de Estado', () {
    late DatabaseService dbService;
    late AppState appState;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      dbService = DatabaseService.instance;
      await dbService.initializeForTest(inMemoryDatabasePath);
      appState = AppState(dbService: dbService);
      await appState.initialize();
    });

    test('AppState: gerencia showDemoQuickBar, toggleDemoQuickBar e hasActiveSimulations', () async {
      expect(appState.showDemoQuickBar, isTrue);
      expect(appState.hasActiveSimulations, isFalse);

      // Simulação de falha de rede AM-12
      appState.toggleSimulateNetworkFailure(true);
      expect(appState.simulateNetworkFailure, isTrue);
      expect(appState.hasActiveSimulations, isTrue);

      appState.toggleSimulateNetworkFailure(false);
      expect(appState.hasActiveSimulations, isFalse);

      // Simulação de conflito AM-04
      appState.toggleSimulateConflictOnNextSync(true);
      expect(appState.simulateConflictOnNextSync, isTrue);
      expect(appState.hasActiveSimulations, isTrue);

      appState.toggleSimulateConflictOnNextSync(false);
      expect(appState.hasActiveSimulations, isFalse);

      // Toggle Demo Quick Bar
      var notified = false;
      appState.addListener(() => notified = true);
      await appState.toggleDemoQuickBar();
      expect(appState.showDemoQuickBar, isFalse);
      expect(notified, isTrue);

      // Persistência em SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool(AppState.prefShowDemoQuickBarKey), isFalse);

      // Reinicializa e verifica restauração da preferência
      final stateRestored = AppState(dbService: dbService);
      await stateRestored.initialize();
      expect(stateRestored.showDemoQuickBar, isFalse);

      // Alterna de volta para true
      await stateRestored.toggleDemoQuickBar();
      expect(stateRestored.showDemoQuickBar, isTrue);
    });

    test('AppState: resetDatabaseAndReload restaura o banco de dados sem erros', () async {
      await appState.quickLoginAsRole(UserRole.admin);
      await appState.resetDatabaseAndReload();
      expect(appState.initError, isNull);
      expect(appState.projects.length, equals(2));
      expect(appState.properties.length, equals(4));
    });

    testWidgets('Demo Hub: Abertura do BottomSheet, 4 Cards e Ações Interativas', (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      // Login como Admin
      await tester.runAsync(() async {
        await appState.quickLoginAsRole(UserRole.admin);
      });

      await tester.pumpWidget(MudaPsaApp(appState: appState));
      await tester.pumpAndSettle();

      // 1. Verifica presença do botão Demo Mode no AppBar
      final demoHubBtn = find.byKey(const Key('demo_hub_appbar_button'));
      expect(demoHubBtn, findsOneWidget);
      expect(find.byTooltip('Central de Demonstracao (AM-01 a AM-12)'), findsOneWidget);

      // Verifica que a barra rápida horizontal está visível inicialmente
      expect(find.textContaining('MODO DEMONSTRAÇÃO:'), findsOneWidget);

      // Testa feedback visual dos chips na barra rápida
      final onlineChip = find.byKey(const Key('demo_toggle_online'));
      await tester.ensureVisible(onlineChip);
      await tester.tap(onlineChip);
      await tester.pumpAndSettle();
      expect(find.textContaining('Modo OFFLINE ativado'), findsOneWidget);
      expect(appState.isOnline, isFalse);

      await tester.tap(onlineChip);
      await tester.pumpAndSettle();
      expect(find.textContaining('Modo ONLINE restabelecido'), findsOneWidget);
      expect(appState.isOnline, isTrue);

      final netFailChip = find.byKey(const Key('demo_toggle_net_fail'));
      await tester.ensureVisible(netFailChip);
      await tester.tap(netFailChip);
      await tester.pumpAndSettle();
      expect(find.textContaining('Simulação de Falha de Rede (HTTP 503 - AM-12) ATIVA'), findsOneWidget);
      expect(appState.simulateNetworkFailure, isTrue);
      expect(appState.hasActiveSimulations, isTrue);

      // Com simulação ativa, o botão Demo Hub no AppBar deve exibir Badge
      expect(find.descendant(of: demoHubBtn, matching: find.byType(Badge)), findsOneWidget);

      // Desativa simulação de rede
      await tester.ensureVisible(netFailChip);
      await tester.tap(netFailChip);
      await tester.pumpAndSettle();
      expect(appState.simulateNetworkFailure, isFalse);

      // 2. Abre a Central de Demonstração (Modal Bottom Sheet)
      await tester.tap(demoHubBtn);
      await tester.pumpAndSettle();

      // Verifica cabeçalho e os primeiros cards
      expect(find.text('Central de Demonstração'), findsOneWidget);
      expect(find.text('Conectividade & Simulações de Campo'), findsOneWidget);
      expect(find.text('Controle de Perfis & Sigilo (AM-01)'), findsOneWidget);

      // Card A: Conectividade & Simulações de Campo
      // Testa switch online/offline no bottom sheet
      final sheetOnlineSwitch = find.byKey(const Key('demo_hub_switch_online'));
      await tester.ensureVisible(sheetOnlineSwitch);
      await tester.tap(sheetOnlineSwitch);
      await tester.pumpAndSettle();
      expect(appState.isOnline, isFalse);

      // Testa switch de conflito de sincronização AM-04
      final sheetConflictSwitch = find.byKey(const Key('demo_hub_switch_conflict'));
      await tester.ensureVisible(sheetConflictSwitch);
      await tester.tap(sheetConflictSwitch);
      await tester.pumpAndSettle();
      expect(appState.simulateConflictOnNextSync, isTrue);
      expect(appState.hasActiveSimulations, isTrue);
      expect(find.textContaining('Simulação de Conflito (AM-04) ATIVA'), findsOneWidget);

      // Card B: Controle de Perfis & Sigilo (AM-01)
      // Alterna perfil para Técnico
      final tecnicoChip = find.byKey(const Key('demo_hub_role_tecnico'));
      await tester.ensureVisible(tecnicoChip);
      await tester.tap(tecnicoChip);
      await tester.pump();
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 50));
      });
      await tester.pumpAndSettle();
      expect(appState.currentUser?.role, equals(UserRole.tecnico));

      // Abre JWT Inspector Dialog a partir do Demo Hub
      final jwtBtn = find.byKey(const Key('demo_hub_jwt_inspector_button'));
      await tester.ensureVisible(jwtBtn);
      await tester.tap(jwtBtn);
      await tester.pumpAndSettle();

      expect(find.text('Sessão JWT & Permissões (AM-01)'), findsOneWidget);
      expect(find.text('Token JWT Assinado (HMAC-SHA256):'), findsOneWidget);
      // Fecha o dialog
      await tester.tap(find.text('Fechar'));
      await tester.pumpAndSettle();

      // Card C: Ações Rápidas de Avaliação
      final acoesTitle = find.text('Ações Rápidas de Avaliação');
      await tester.ensureVisible(acoesTitle);
      expect(acoesTitle, findsOneWidget);

      final syncNowBtn = find.byKey(const Key('demo_hub_sync_now_button'));
      await tester.ensureVisible(syncNowBtn);
      await tester.tap(syncNowBtn);
      await tester.pump();
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 350));
      });
      await tester.pumpAndSettle();
      expect(find.textContaining('Processo de sincronização da fila iniciado'), findsOneWidget);

      final resetDbBtn = find.byKey(const Key('demo_hub_reset_db_button'));
      await tester.ensureVisible(resetDbBtn);
      await tester.tap(resetDbBtn);
      for (var i = 0; i < 25; i++) {
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
        await tester.pump(const Duration(milliseconds: 50));
      }
      expect(find.textContaining('Banco SQLite reiniciado com sucesso'), findsOneWidget);

      // Card D: Preferência de Exibição
      final prefTitle = find.text('Preferência de Exibição');
      await tester.ensureVisible(prefTitle);
      expect(prefTitle, findsOneWidget);

      final quickBarToggle = find.byKey(const Key('demo_hub_toggle_quick_bar'));
      await tester.ensureVisible(quickBarToggle);
      await tester.tap(quickBarToggle);
      await tester.pump();
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 50));
      });
      await tester.pumpAndSettle();

      expect(appState.showDemoQuickBar, isFalse);

      // Fecha o bottom sheet tocando no botão fechar
      final closeBtn = find.byTooltip('Fechar');
      await tester.tap(closeBtn);
      await tester.pumpAndSettle();

      // Verifica que a barra rápida horizontal agora está oculta no topo da tela!
      expect(find.textContaining('MODO DEMONSTRAÇÃO:'), findsNothing);

      // Reabre Demo Hub e reativa a barra rápida
      await tester.tap(demoHubBtn);
      await tester.pumpAndSettle();

      final reenableToggle = find.byKey(const Key('demo_hub_toggle_quick_bar'));
      await tester.scrollUntilVisible(reenableToggle, 200,
          scrollable: find.byType(Scrollable).last);
      await tester.tap(reenableToggle);
      await tester.pump();
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 50));
      });
      await tester.pumpAndSettle();

      expect(appState.showDemoQuickBar, isTrue);

      await tester.tap(find.byTooltip('Fechar'));
      await tester.pumpAndSettle();

      // Barra rápida horizontal deve estar visível novamente
      expect(find.textContaining('MODO DEMONSTRAÇÃO:'), findsOneWidget);
    });
  });
}
