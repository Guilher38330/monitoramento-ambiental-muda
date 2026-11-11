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
  SharedPreferences.setMockInitialValues({});

  group('Fase 2 — Mensagens de Validação e Feedback Abrangente', () {
    late DatabaseService dbService;
    late AppState appState;

    Future<void> initTestState() async {
      dbService = DatabaseService.instance;
      await dbService.initializeForTest(inMemoryDatabasePath);
      appState = AppState(dbService: dbService);
      await appState.initialize();
    }

    testWidgets('Login: feedback imediato de validação e SnackBar de falha de autenticação',
        (WidgetTester tester) async {
      await tester.runAsync(() async {
        await initTestState();
      });

      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(MudaPsaApp(appState: appState));
      await tester.pumpAndSettle();

      // Digita e-mail inválido (sem @ ou ponto)
      await tester.enterText(
        find.byKey(const Key('login_email_field')),
        'email_invalido',
      );
      await tester.pumpAndSettle();
      expect(find.text('Informe um e-mail válido.'), findsOneWidget);

      // Digita senha curta (< 6 caracteres)
      await tester.enterText(
        find.byKey(const Key('login_password_field')),
        '123',
      );
      await tester.pumpAndSettle();
      expect(
        find.text('A senha deve conter no mínimo 6 caracteres.'),
        findsOneWidget,
      );

      // Corrige campos com formato válido, mas credenciais erradas
      await tester.enterText(
        find.byKey(const Key('login_email_field')),
        'usuario@inexistente.com.br',
      );
      await tester.enterText(
        find.byKey(const Key('login_password_field')),
        '654321',
      );
      await tester.pumpAndSettle();

      // Submete formulário com credenciais inválidas
      await tester.runAsync(() async {
        await tester.tap(find.byKey(const Key('login_submit_button')));
        await Future<void>.delayed(const Duration(milliseconds: 100));
      });
      await tester.pumpAndSettle();

      // Verifica exibição do SnackBar de erro com ícone de erro e cor vermelha
      expect(find.byType(SnackBar), findsOneWidget);
      expect(find.byIcon(Icons.error_outline_rounded), findsWidgets);

      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
    });

    testWidgets('Formulário de Campo: validação com SnackBar de aviso, banners de destaque e confirmações',
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

      // Navega para aba Nova Coleta / Formulário de Campo
      await tester.tap(find.byKey(const Key('nav_destination_field_collection')));
      await tester.pumpAndSettle();

      // Limpa parecer técnico para forçar erro de validação
      await tester.enterText(find.byKey(const Key('input_technical_notes')), '');
      await tester.pumpAndSettle();

      // Tenta submeter formulário incompleto
      final submitBtn = find.byKey(const Key('submit_field_form_button'));
      await tester.ensureVisible(submitBtn);
      await tester.tap(submitBtn);
      await tester.pumpAndSettle();

      // Verifica exibição do SnackBar de aviso
      expect(find.byType(SnackBar), findsOneWidget);
      expect(find.byIcon(Icons.warning_amber_rounded), findsWidgets);
      expect(
        find.descendant(
          of: find.byType(SnackBar),
          matching: find.textContaining('Preencha os campos obrigatórios:'),
        ),
        findsOneWidget,
      );

      // Verifica banners de validação
      expect(find.byKey(const Key('field_form_validation_error_banner')), findsOneWidget);
      expect(find.byKey(const Key('gps_validation_banner')), findsOneWidget);
      expect(find.byKey(const Key('photo_validation_banner')), findsOneWidget);

      // Captura coordenadas GPS e verifica SnackBar de confirmação
      final gpsBtn = find.byKey(const Key('capture_gps_button'));
      await tester.ensureVisible(gpsBtn);
      await tester.runAsync(() async {
        await tester.tap(gpsBtn);
        await Future<void>.delayed(const Duration(milliseconds: 100));
      });
      await tester.pumpAndSettle();
      expect(find.textContaining('Coordenadas GPS capturadas:'), findsOneWidget);

      // Captura Foto de Demonstração e verifica SnackBar de confirmação
      final photoDemoBtn = find.byKey(const Key('capture_demo_photo_button'));
      await tester.ensureVisible(photoDemoBtn);
      await tester.tap(photoDemoBtn);
      await tester.pumpAndSettle();
      expect(find.text('Foto georreferenciada carimbada com sucesso!'), findsOneWidget);

      // Preenche parecer técnico
      await tester.enterText(
        find.byKey(const Key('input_technical_notes')),
        'Observações técnicas detalhadas da parcela e nascente.',
      );
      await tester.pumpAndSettle();

      // Submete formulário com sucesso
      await tester.ensureVisible(submitBtn);
      await tester.runAsync(() async {
        await tester.tap(submitBtn);
        await Future<void>.delayed(const Duration(milliseconds: 100));
      });
      await tester.pumpAndSettle();

      // Verifica SnackBar de sucesso com ação 'VER NA FILA'
      expect(find.byType(SnackBar), findsOneWidget);
      expect(find.byIcon(Icons.check_circle_rounded), findsWidgets);
      expect(find.textContaining('Coleta registrada com sucesso na fila local!'), findsOneWidget);
      expect(find.text('VER NA FILA'), findsOneWidget);

      // Aguarda o fechamento do SnackBar no loop real para evitar timer pendente
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(seconds: 5));
      });
      await tester.pumpAndSettle();
    });

    testWidgets('Dashboard / Relatórios: SnackBars informativos nas exportações PDF e CSV',
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

      // Navega para Dashboards & Relatórios
      await tester.tap(find.byKey(const Key('nav_destination_indicators')));
      await tester.pumpAndSettle();

      // Abre pré-visualização de Relatório PDF
      final pdfBtn = find.byKey(const Key('btn_generate_share_pdf_report'));
      await tester.ensureVisible(pdfBtn);
      await tester.runAsync(() async {
        await tester.tap(pdfBtn);
        await Future<void>.delayed(const Duration(milliseconds: 250));
      });
      await tester.pumpAndSettle();

      // Verifica SnackBar de PDF consolidado gerado
      expect(find.byType(SnackBar), findsOneWidget);
      expect(find.text('Relatório PDF consolidado gerado com sucesso!'), findsOneWidget);

      // Fecha diálogo do PDF
      await tester.tap(find.byKey(const Key('close_pdf_preview_dialog_button')));
      await tester.pumpAndSettle();

      // Abre pré-visualização de Planilha CSV
      final csvBtn = find.byKey(const Key('btn_export_share_csv_spreadsheet'));
      await tester.ensureVisible(csvBtn);
      await tester.tap(csvBtn);
      await tester.pumpAndSettle();

      // Verifica SnackBar de Planilha CSV exportada com sucesso
      expect(find.byType(SnackBar), findsOneWidget);
      expect(find.text('Planilha CSV exportada com sucesso!'), findsOneWidget);

      // Fecha diálogo do CSV
      await tester.tap(find.byKey(const Key('close_csv_preview_dialog_button')));
      await tester.pumpAndSettle();

      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
    });
  });
}
