import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:trabalho_final/main.dart';
import 'package:trabalho_final/models/user_profile.dart';
import 'package:trabalho_final/services/database_service.dart';
import 'package:trabalho_final/state/app_state.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  group('Verificação Integrada: Central de Demonstração (Demo Hub) e Validações de Formulário', () {
    late DatabaseService dbService;
    late AppState appState;

    Future<void> initTestState() async {
      SharedPreferences.setMockInitialValues({});
      dbService = DatabaseService.instance;
      await dbService.initializeForTest(inMemoryDatabasePath);
      appState = AppState(dbService: dbService);
      await appState.initialize();
    }

    testWidgets('1. Hub modal abre e contém opções de demonstração completas (AM-01 a AM-12)',
        (WidgetTester tester) async {
      await tester.runAsync(() async {
        await initTestState();
        await appState.quickLoginAsRole(UserRole.admin);
      });

      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(MudaPsaApp(appState: appState));
      await tester.pumpAndSettle();

      // Botão do AppBar para Central de Demonstração
      final demoHubBtn = find.byKey(const Key('demo_hub_appbar_button'));
      expect(demoHubBtn, findsOneWidget);

      // Abre a Central de Demonstração (Modal BottomSheet)
      await tester.tap(demoHubBtn);
      await tester.pumpAndSettle();

      // 1.1 Título do Hub e Interruptor Mestre
      expect(find.text('Central de Demonstração'), findsOneWidget);
      expect(find.byKey(const Key('demo_hub_master_switch')), findsOneWidget);

      // 1.2 Card A: Conectividade & Simulações de Campo
      expect(find.text('Conectividade & Simulações de Campo'), findsOneWidget);
      expect(find.byKey(const Key('demo_hub_switch_online')), findsOneWidget);
      expect(find.byKey(const Key('demo_hub_switch_net_fail')), findsOneWidget);
      expect(find.byKey(const Key('demo_hub_switch_conflict')), findsOneWidget);

      // 1.3 Card B: Controle de Perfis & Sigilo (AM-01)
      expect(find.text('Controle de Perfis & Sigilo (AM-01)'), findsOneWidget);
      expect(find.byKey(const Key('demo_hub_role_admin')), findsOneWidget);
      expect(find.byKey(const Key('demo_hub_role_tecnico')), findsOneWidget);
      expect(find.byKey(const Key('demo_hub_role_empresa')), findsOneWidget);
      expect(find.byKey(const Key('demo_hub_jwt_inspector_button')), findsOneWidget);

      // 1.4 Card C: Ações Rápidas de Avaliação
      final acoesCard = find.text('Ações Rápidas de Avaliação');
      await tester.ensureVisible(acoesCard);
      expect(acoesCard, findsOneWidget);
      expect(find.byKey(const Key('demo_hub_sync_now_button')), findsOneWidget);
      expect(find.byKey(const Key('demo_hub_reset_db_button')), findsOneWidget);

      // 1.5 Card D: Preferência de Exibição
      final prefCard = find.text('Preferência de Exibição');
      await tester.ensureVisible(prefCard);
      expect(prefCard, findsOneWidget);
      expect(find.byKey(const Key('demo_hub_toggle_quick_bar')), findsOneWidget);

      // Fecha modal do Hub
      final closeBtn = find.byTooltip('Fechar');
      await tester.tap(closeBtn);
      await tester.pumpAndSettle();
    });

    testWidgets('2. showDemoQuickBar alterna visibilidade da barra rápida superior',
        (WidgetTester tester) async {
      await tester.runAsync(() async {
        await initTestState();
        await appState.quickLoginAsRole(UserRole.admin);
        appState.toggleDemoMode(true);
      });

      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(MudaPsaApp(appState: appState));
      await tester.pumpAndSettle();

      // Inicialmente visível (padrão true)
      expect(appState.showDemoQuickBar, isTrue);
      expect(find.textContaining('MODO DEMONSTRAÇÃO:'), findsOneWidget);

      // Abre Hub e desativa a barra rápida
      final demoHubBtn = find.byKey(const Key('demo_hub_appbar_button'));
      await tester.tap(demoHubBtn);
      await tester.pumpAndSettle();

      final toggleQuickBar = find.byKey(const Key('demo_hub_toggle_quick_bar'));
      await tester.ensureVisible(toggleQuickBar);
      await tester.tap(toggleQuickBar);
      await tester.pump();
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
      await tester.pumpAndSettle();

      expect(appState.showDemoQuickBar, isFalse);

      // Fecha o modal
      await tester.tap(find.byTooltip('Fechar'));
      await tester.pumpAndSettle();

      // A barra rápida agora está OCULTA no topo
      expect(find.textContaining('MODO DEMONSTRAÇÃO:'), findsNothing);

      // Alterna via AppState para true novamente e valida reaparecimento
      await tester.runAsync(() async {
        await appState.toggleDemoQuickBar();
      });
      await tester.pumpAndSettle();

      expect(appState.showDemoQuickBar, isTrue);
      expect(find.textContaining('MODO DEMONSTRAÇÃO:'), findsOneWidget);
    });

    testWidgets('3. Validação de formulário bloqueia envio sem GPS/foto e exibe mensagens de feedback',
        (WidgetTester tester) async {
      await tester.runAsync(() async {
        await initTestState();
        await appState.quickLoginAsRole(UserRole.tecnico);
        appState.toggleDemoMode(true);
      });

      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(MudaPsaApp(appState: appState));
      await tester.pumpAndSettle();

      // Navega para aba Nova Coleta
      await tester.tap(find.byKey(const Key('nav_destination_field_collection')));
      await tester.pumpAndSettle();

      // Sem capturar GPS e sem foto, tenta submeter
      final submitBtn = find.byKey(const Key('submit_field_form_button'));
      await tester.ensureVisible(submitBtn);
      await tester.tap(submitBtn);
      await tester.pumpAndSettle();

      // Verifica que a validação bloqueia e exibe SnackBar de aviso (vermelho)
      expect(find.byType(SnackBar), findsOneWidget);
      expect(find.byIcon(Icons.warning_amber_rounded), findsWidgets);
      expect(
        find.descendant(
          of: find.byType(SnackBar),
          matching: find.textContaining('Preencha os campos obrigatórios:'),
        ),
        findsOneWidget,
      );

      // Verifica exibição dos banners visuais de validação faltante
      expect(find.byKey(const Key('field_form_validation_error_banner')), findsOneWidget);
      expect(find.byKey(const Key('gps_validation_banner')), findsOneWidget);
      expect(find.byKey(const Key('photo_validation_banner')), findsOneWidget);

      // Agora realiza a captura do GPS
      final gpsBtn = find.byKey(const Key('capture_gps_button'));
      await tester.ensureVisible(gpsBtn);
      await tester.runAsync(() async {
        await tester.tap(gpsBtn);
        await Future<void>.delayed(const Duration(milliseconds: 100));
      });
      await tester.pumpAndSettle();

      // Verifica SnackBar de confirmação do GPS
      expect(find.textContaining('Coordenadas GPS capturadas:'), findsOneWidget);

      // Agora captura foto de demonstração
      final photoDemoBtn = find.byKey(const Key('capture_demo_photo_button'));
      await tester.ensureVisible(photoDemoBtn);
      await tester.tap(photoDemoBtn);
      await tester.pumpAndSettle();

      // Verifica SnackBar de confirmação da foto
      expect(find.text('Foto georreferenciada carimbada com sucesso!'), findsOneWidget);

      // Garante que o parecer técnico está preenchido
      await tester.enterText(
        find.byKey(const Key('input_technical_notes')),
        'Vistoria técnica de campo concluída com validações completas.',
      );
      await tester.pumpAndSettle();

      // Submete novamente agora que GPS e foto foram preenchidos
      await tester.ensureVisible(submitBtn);
      await tester.runAsync(() async {
        await tester.tap(submitBtn);
        await Future<void>.delayed(const Duration(milliseconds: 100));
      });
      await tester.pumpAndSettle();

      // Validação passou com sucesso! Deve exibir SnackBar de sucesso verde com botão VER NA FILA
      expect(find.byType(SnackBar), findsOneWidget);
      expect(find.byIcon(Icons.check_circle_rounded), findsWidgets);
      expect(find.textContaining('Coleta registrada com sucesso na fila local!'), findsOneWidget);
      expect(find.text('VER NA FILA'), findsOneWidget);

      // Aguarda descarte de timers
      await tester.runAsync(() => Future<void>.delayed(const Duration(seconds: 5)));
      await tester.pumpAndSettle();
    });
  });
}
