import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
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

  group('Fase 1 — Autenticação JWT, Perfis (AM-01) e Projetos Muda/PSA (AM-02)', () {
    late DatabaseService dbService;
    late AppState appState;

    Future<void> initTestState() async {
      dbService = DatabaseService.instance;
      await dbService.initializeForTest(inMemoryDatabasePath);
      appState = AppState(dbService: dbService);
      await appState.initialize();
    }

    test('Gera e valida Token JWT (HMAC-SHA256) e permissões dos 3 perfis (AM-01)', () {
      for (final demoUser in AppUser.demoUsers) {
        final token = JwtAuthSimulator.generateToken(demoUser);
        expect(JwtAuthSimulator.validateToken(token), isTrue);

        final payload = JwtAuthSimulator.decodePayload(token);
        expect(payload['email'], equals(demoUser.email));
        expect(payload['role'], equals(demoUser.role.name));
      }

      // Token adulterado deve ser rejeitado
      final validToken = JwtAuthSimulator.generateToken(AppUser.demoUsers.first);
      final tamperedToken = '${validToken}x';
      expect(JwtAuthSimulator.validateToken(tamperedToken), isFalse);

      // Token expirado deve ser rejeitado
      final expiredToken = JwtAuthSimulator.generateToken(
        AppUser.demoUsers.first,
        issuedAt: DateTime.now().toUtc().subtract(const Duration(hours: 24)),
      );
      expect(JwtAuthSimulator.validateToken(expiredToken), isFalse);

      // Token malformado deve ser rejeitado
      expect(JwtAuthSimulator.validateToken('invalido'), isFalse);

      // Verificação de permissões de sigilo por perfil (AM-01)
      final admin = AppUser.demoUsers.firstWhere((u) => u.role == UserRole.admin);
      final tecnico = AppUser.demoUsers.firstWhere((u) => u.role == UserRole.tecnico);
      final empresa = AppUser.demoUsers.firstWhere((u) => u.role == UserRole.empresa);

      expect(admin.canViewConfidentialData, isTrue);
      expect(tecnico.canViewConfidentialData, isTrue);
      expect(empresa.canViewConfidentialData, isFalse);

      expect(admin.formatConfidentialText('418.920.330-53'), equals('418.920.330-53'));
      expect(empresa.formatConfidentialText('418.920.330-53'), contains('Restrito'));
    });

    test('Carrega Seed Data completo de Projetos Muda e PSA do SQLite (AM-02) e filtra buscas', () async {
      await initTestState();
      expect(appState.projects.length, equals(2));
      expect(
        appState.projects.any((p) => p.programType == 'MUDA'),
        isTrue,
      );
      expect(
        appState.projects.any((p) => p.programType == 'PSA'),
        isTrue,
      );
      expect(appState.properties.length, equals(4));
      expect(appState.collectionPoints.length, equals(6));

      // Verifica filtro por programa
      appState.setProgramFilter('MUDA');
      expect(appState.filteredProjects.length, equals(1));
      expect(appState.filteredProjects.first.code, equals('MUDA-2026-RP01'));

      appState.setProgramFilter('PSA');
      expect(appState.filteredProjects.length, equals(1));
      expect(appState.filteredProjects.first.code, equals('PSA-2026-TQ02'));

      appState.setProgramFilter('TODOS');
      expect(appState.filteredProjects.length, equals(2));

      // Verifica busca por nome de propriedade vinculada e termo inexistente
      appState.setSearchQuery('Santa Inês');
      expect(appState.filteredProjects.length, equals(1));
      expect(appState.filteredProjects.first.id, equals('proj-muda-01'));

      appState.setSearchQuery('termo_inexistente_xyz');
      expect(appState.filteredProjects, isEmpty);

      appState.setSearchQuery('');
      expect(appState.filteredProjects.length, equals(2));

      // Verifica interações de estado da Barra de Modo Demonstração
      appState.toggleOnlineStatus(false);
      expect(appState.isOnline, isFalse);
      appState.toggleSimulateNetworkFailure(true);
      expect(appState.simulateNetworkFailure, isTrue);
      expect(appState.isOnline, isTrue); // reativa online para simular falha na rede
      appState.toggleSimulateConflictOnNextSync(true);
      expect(appState.simulateConflictOnNextSync, isTrue);
    });

    testWidgets('Fluxo UI: Login por perfil, Barra Demo e Sigilo de Dados (AM-01 e AM-02)', (WidgetTester tester) async {
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

      // Verifica tela de login
      expect(find.text('EcoMonitor — Muda & PSA'), findsOneWidget);
      final empresaQuickLogin = find.byKey(const Key('quick_login_empresa'));
      expect(empresaQuickLogin, findsOneWidget);

      // 0. Testa tentativa de login com senha inválida (caso de borda de erro)
      final invalidAuth = await tester.runAsync(
        () => appState.loginWithCredentials('admin@muda.org.br', 'senha_errada'),
      );
      expect(invalidAuth, isFalse);
      expect(appState.authError, isNotNull);
      await tester.pumpAndSettle();
      expect(find.textContaining('Credenciais inválidas'), findsOneWidget);

      // 1. Login rápido como Empresa Contratante (dados sigilosos devem ser mascarados)
      await tester.runAsync(() => appState.quickLoginAsRole(UserRole.empresa));
      await tester.pumpAndSettle();

      expect(appState.currentUser?.role, equals(UserRole.empresa));
      expect(find.text('EMPRESA'), findsOneWidget);
      expect(find.textContaining('MODO DEMONSTRAÇÃO:'), findsOneWidget);

      // Testa alternância Online / Offline na Barra de Modo Demonstração
      expect(appState.isOnline, isTrue);
      await tester.tap(find.byKey(const Key('demo_toggle_online')));
      await tester.pumpAndSettle();
      expect(appState.isOnline, isFalse);
      expect(find.text('Status: OFFLINE (Campo)'), findsOneWidget);

      // Verifica que os projetos Muda e PSA estão listados e o orçamento está sob sigilo contratual
      expect(find.text('Recomposição Florestal e Proteção de Nascentes — Alto Rio Pardo'), findsOneWidget);
      expect(find.textContaining('Sigilo Contratual'), findsWidgets);

      // Abre detalhes do projeto Muda
      final openDetailsBtn = find.byKey(const Key('open_project_details_proj-muda-01'));
      await tester.ensureVisible(openDetailsBtn);
      await tester.tap(openDetailsBtn);
      await tester.pumpAndSettle();

      // Na aba Visão Geral & Sigilo, o bloco sigiloso deve estar bloqueado para Empresa
      expect(find.textContaining('Bloco de Informações Sigilosas (Bloqueado para Empresa Contratante)'), findsOneWidget);

      // Navega para a aba Propriedades & Áreas e verifica que o CPF real não é exibido para Empresa
      await tester.tap(find.text('Propriedades & Áreas'));
      await tester.pumpAndSettle();
      expect(find.text('Fazenda Santa Inês (Gleba Nascentes do Pardo)'), findsOneWidget);
      expect(find.textContaining('418.920.330-53'), findsNothing);
      expect(find.textContaining('Restrito - LGPD/Sigilo'), findsWidgets);

      // Navega para Etapas & Cronograma (AM-02)
      await tester.tap(find.text('Etapas & Cronograma'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Etapa 1 — Diagnóstico Hidroambiental'), findsOneWidget);

      // Navega para Documentos Autorizados (AM-02) e verifica bloqueio do documento sigiloso
      await tester.tap(find.text('Documentos Autorizados'));
      await tester.pumpAndSettle();
      expect(find.textContaining('ACESSO RESTRITO (AM-01)'), findsOneWidget);

      // Volta para a tela principal e alterna para o perfil Administrador
      await tester.pageBack();
      await tester.pumpAndSettle();

      // Testa caracteres especiais de SQL/busca na barra de pesquisa
      await tester.enterText(
        find.byKey(const Key('project_search_field')),
        "'; DROP TABLE projects; -- % _",
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('Nenhum projeto encontrado'), findsOneWidget);

      await tester.enterText(find.byKey(const Key('project_search_field')), '');
      await tester.pumpAndSettle();

      // Abre novamente os detalhes do Projeto Muda ainda como Empresa e usa o seletor em tempo real na própria tela de detalhes
      await tester.ensureVisible(openDetailsBtn);
      await tester.tap(openDetailsBtn);
      await tester.pumpAndSettle();
      expect(find.textContaining('Bloco de Informações Sigilosas (Bloqueado para Empresa Contratante)'), findsOneWidget);

      // Troca para Administrador diretamente dentro da tela de detalhes (ProjectDetailScreen)
      await tester.tap(find.byKey(const Key('detail_profile_switcher_menu')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('detail_switch_role_admin')));
      await tester.pumpAndSettle();
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 20));
      });

      expect(appState.currentUser?.role, equals(UserRole.admin));
      expect(find.textContaining('Bloco de Informações Sigilosas (Liberado para Administrador)'), findsOneWidget);

      await tester.tap(find.text('Propriedades & Áreas'));
      await tester.pumpAndSettle();
      expect(find.textContaining('418.920.330-53'), findsOneWidget);
    });
  });
}
