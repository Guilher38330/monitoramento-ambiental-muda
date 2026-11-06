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

  group('Fase 2 — Coleta Offline, GPS/Foto, Sincronização Idempotente, Conflitos e Auditoria (AM-03, AM-04, AM-05, AM-11, AM-12)', () {
    late DatabaseService dbService;
    late AppState appState;

    Future<void> initPhase2State() async {
      dbService = DatabaseService.instance;
      await dbService.initializeForTest(inMemoryDatabasePath);
      appState = AppState(dbService: dbService);
      await appState.initialize();
    }

    test('1º Critério de Aceite: Coleta offline com GPS e foto, idempotência por clientUuid sem duplicatas, falha de rede (AM-12) e conflito (AM-04 / AM-11)', () async {
      await initPhase2State();
      await appState.quickLoginAsRole(UserRole.tecnico);

      // 1. Verifica que o seed já traz 3 formulários (1 synced, 1 pending, 1 conflict)
      expect(appState.fieldForms.length, equals(3));
      expect(appState.syncedCount, equals(1));
      expect(appState.pendingSyncCount, equals(1));
      expect(appState.conflictCount, equals(1));

      // 2. Desliga internet (Modo Offline) e registra um novo formulário com GPS e foto
      appState.toggleOnlineStatus(false);
      expect(appState.isOnline, isFalse);

      const customUuid = 'uuid-offline-test-accept-01';
      final createdOffline = await appState.saveFieldFormRecord(
        customClientUuid: customUuid,
        projectId: 'proj-muda-01',
        propertyId: 'prop-muda-01',
        pointId: 'pt-muda-01',
        templateName: 'Vistoria de Sobrevivência de Mudas (Muda)',
        vegetationStage: 'Estágio Inicial — Pegamento de Mudas (0 a 12 meses)',
        survivalRatePercent: 88.5,
        erosionStatus: 'Ausente — Solo Estabilizado com Cobertura Vegetal',
        invasiveSpeciesPresent: false,
        maintenancePerformed: 'Coroamento Manual + Controle de Formigas Cortadeiras',
        technicalNotes: 'Mudas de Inga vera vigorosas junto à cabeceira norte.',
        isConfidential: true,
        latitude: -29.7132,
        longitude: -52.4295,
        gpsAccuracyMeters: 3.1,
        photoLocalPath: 'demo://foto_offline_nascente_01.jpg',
        photoCapturedAt: '2026-11-06T12:00:00Z',
        photoCaption: 'Foto offline georreferenciada PC-MUDA-01',
      );

      expect(createdOffline, isNotNull);
      expect(appState.fieldForms.length, equals(4));
      expect(appState.pendingSyncCount, equals(2));

      // 3. Testa IDEMPOTÊNCIA (reenviar/salvar o mesmo clientUuid não pode duplicar registros no SQLite)
      await appState.saveFieldFormRecord(
        customClientUuid: customUuid,
        projectId: 'proj-muda-01',
        propertyId: 'prop-muda-01',
        pointId: 'pt-muda-01',
        templateName: 'Vistoria de Sobrevivência de Mudas (Muda)',
        vegetationStage: 'Estágio Inicial — Pegamento de Mudas (0 a 12 meses)',
        survivalRatePercent: 90.0,
        erosionStatus: 'Ausente — Solo Estabilizado com Cobertura Vegetal',
        invasiveSpeciesPresent: false,
        maintenancePerformed: 'Coroamento Manual + Controle de Formigas Cortadeiras',
        technicalNotes: 'Mudas de Inga vera vigorosas (revisão idempotente antes do sync).',
        isConfidential: true,
        latitude: -29.7132,
        longitude: -52.4295,
        gpsAccuracyMeters: 3.1,
        photoLocalPath: 'demo://foto_offline_nascente_01.jpg',
        photoCapturedAt: '2026-11-06T12:05:00Z',
        photoCaption: 'Foto offline georreferenciada PC-MUDA-01',
      );
      expect(appState.fieldForms.length, equals(4)); // Sem duplicata!

      // 4. Tenta sincronizar ainda OFFLINE: deve bloquear envio e manter registros na fila (AM-04 / AM-12)
      final offlineSyncRes = await appState.synchronizePendingForms();
      expect(offlineSyncRes.success, isFalse);
      expect(appState.pendingSyncCount, equals(2));

      // 5. Ativa Simulação de Falha de Rede (HTTP 503 - AM-12) e tenta sincronizar
      appState.toggleSimulateNetworkFailure(true);
      expect(appState.isOnline, isTrue);
      final netFailRes = await appState.synchronizePendingForms();
      expect(netFailRes.success, isFalse);
      expect(netFailRes.failedCount, equals(2));
      expect(appState.pendingSyncCount, equals(2)); // Continuam na fila para reenvio

      // 6. Restabelece conexão normal (desativa falha de rede) e sincroniza a fila
      appState.toggleSimulateNetworkFailure(false);
      final onlineSyncRes = await appState.synchronizePendingForms();
      expect(onlineSyncRes.success, isTrue);
      expect(onlineSyncRes.syncedCount, equals(2));
      expect(appState.pendingSyncCount, equals(0));
      expect(appState.fieldForms.length, equals(4)); // Nenhuma duplicação pós-sync!

      // Chamada extra de sincronização com fila vazia deve ser idempotente e sem duplicatas
      final repeatSyncRes = await appState.synchronizePendingForms();
      expect(repeatSyncRes.success, isTrue);
      expect(repeatSyncRes.syncedCount, equals(0));
      expect(appState.fieldForms.length, equals(4));

      // Verifica data de sincronização e histórico de auditoria (AM-11)
      final syncedRecord = appState.fieldForms.firstWhere((r) => r.clientUuid == customUuid);
      expect(syncedRecord.syncedAt, isNotNull);
      expect(syncedRecord.auditHistory.length, greaterThanOrEqualTo(3));

      // 7. Resolve o conflito existente no registro de seed ('uuid-seed-conflict-003') mantendo versão de campo (AM-04, AM-11)
      expect(appState.conflictCount, equals(1));
      final resolved = await appState.resolveRecordConflict(
        clientUuid: 'uuid-seed-conflict-003',
        keepFieldVersion: true,
      );
      expect(resolved, isNotNull);
      expect(appState.conflictCount, equals(0));
      expect(appState.syncedCount, equals(4));
      expect(
        resolved!.auditHistory.any((a) => a.action == 'CONFLITO_RESOLVIDO_CAMPO'),
        isTrue,
      );

      // 8. Verifica bloqueio RBAC para perfil Empresa Contratante (AM-01)
      await appState.quickLoginAsRole(UserRole.empresa);
      final blockedSave = await appState.saveFieldFormRecord(
        projectId: 'proj-muda-01',
        propertyId: 'prop-muda-01',
        pointId: 'pt-muda-01',
        templateName: 'Vistoria de Sobrevivência de Mudas (Muda)',
        vegetationStage: 'Estágio Inicial — Pegamento de Mudas (0 a 12 meses)',
        survivalRatePercent: 80.0,
        erosionStatus: 'Ausente — Solo Estabilizado com Cobertura Vegetal',
        invasiveSpeciesPresent: false,
        maintenancePerformed: 'Vistoria de Monitoramento Sem Intervenção Física',
        technicalNotes: 'Tentativa não autorizada.',
        isConfidential: false,
        latitude: -29.71,
        longitude: -52.42,
        gpsAccuracyMeters: 4.0,
        photoLocalPath: 'demo://x.jpg',
        photoCapturedAt: '2026-11-06T12:00:00Z',
        photoCaption: 'x',
      );
      expect(blockedSave, isNull);
    });

    testWidgets('Fluxo UI Fase 2: Coleta Offline com GPS + Foto Demo, Sincronização e Resolução de Conflito (AM-03 a AM-05, AM-11, AM-12)', (WidgetTester tester) async {
      await tester.runAsync(() async {
        await initPhase2State();
      });

      tester.view.physicalSize = const Size(1080, 2200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.runAsync(() => appState.quickLoginAsRole(UserRole.tecnico));
      await tester.pumpWidget(MudaPsaApp(appState: appState));
      await tester.pumpAndSettle();

      // Navega para a aba "Coleta & Sync" (index 2)
      await tester.tap(find.text('Coleta & Sync'));
      await tester.pumpAndSettle();

      // Verifica que a lista exibe os registros de seed e o botão de sincronizar fila
      expect(find.byKey(const Key('sync_queue_now_button')), findsOneWidget);
      expect(find.textContaining('Vistoria de Sobrevivência de Mudas (Muda)'), findsOneWidget);

      // Abre o Histórico de Auditoria & Autoria (AM-11) do primeiro registro sincronizado
      final auditBtn = find.byKey(const Key('audit_history_btn_uuid-seed-synced-001'));
      await tester.ensureVisible(auditBtn);
      await tester.tap(auditBtn);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('audit_history_dialog')), findsOneWidget);
      expect(find.textContaining('SINCRONIZADO_SERVIDOR'), findsOneWidget);
      await tester.tap(find.byKey(const Key('close_audit_history_btn')));
      await tester.pumpAndSettle();

      // Abre o modal de Resolução de Conflito (AM-04) do registro em conflito
      final resolveBtn = find.byKey(const Key('resolve_conflict_btn_uuid-seed-conflict-003'));
      await tester.ensureVisible(resolveBtn);
      await tester.tap(resolveBtn);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('conflict_resolution_dialog')), findsOneWidget);
      expect(find.textContaining('VERSÃO DE CAMPO'), findsOneWidget);
      expect(find.textContaining('VERSÃO DA PLATAFORMA'), findsOneWidget);

      await tester.runAsync(() async {
        await appState.resolveRecordConflict(
          clientUuid: 'uuid-seed-conflict-003',
          keepFieldVersion: false,
        );
      });
      Navigator.of(tester.element(find.byKey(const Key('conflict_resolution_dialog')))).pop();
      await tester.pumpAndSettle();
      expect(appState.conflictCount, equals(0));

      // Coloca em Modo OFFLINE na barra superior e abre "Nova Coleta"
      await tester.tap(find.byKey(const Key('demo_toggle_online')));
      await tester.pumpAndSettle();
      expect(appState.isOnline, isFalse);

      await tester.tap(find.byKey(const Key('open_new_field_form_button')));
      await tester.pumpAndSettle();

      // Tenta salvar sem preencher observações nem capturar GPS/foto para testar validação obrigatória (AM-03 / AM-05)
      final submitBtn = find.byKey(const Key('submit_field_form_button'));
      await tester.ensureVisible(submitBtn);
      await tester.tap(submitBtn);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('field_form_validation_error_banner')), findsOneWidget);

      // Testa caso de borda: survivalRatePercent fora do intervalo [0, 100] (ex.: 145.0)
      await tester.enterText(find.byKey(const Key('input_survival_rate')), '145.0');
      await tester.enterText(
        find.byKey(const Key('input_technical_notes')),
        'Coleta offline completa com GPS e foto georreferenciada na nascente.',
      );
      await tester.ensureVisible(submitBtn);
      await tester.tap(submitBtn);
      await tester.pumpAndSettle();
      expect(find.textContaining('Informe um percentual válido entre 0% e 100%'), findsOneWidget);

      // Corrige survivalRatePercent para valor válido (89.5%)
      await tester.enterText(find.byKey(const Key('input_survival_rate')), '89.5');
      await tester.pumpAndSettle();

      final photoDemoBtn = find.byKey(const Key('capture_demo_photo_button'));
      await tester.ensureVisible(photoDemoBtn);
      await tester.tap(photoDemoBtn);
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('captured_gps_display')), findsOneWidget);
      expect(find.byKey(const Key('captured_photo_preview')), findsOneWidget);

      // Salva o formulário Offline
      await tester.ensureVisible(submitBtn);
      await tester.runAsync(() async {
        await tester.tap(submitBtn);
        await Future<void>.delayed(const Duration(milliseconds: 50));
      });
      await tester.pumpAndSettle();

      // Deve ter voltado para a fila com 2 itens pendentes (1 do seed + 1 recém-criado offline)
      expect(appState.pendingSyncCount, equals(2));

      // Reativa modo ONLINE e sincroniza a fila
      await tester.tap(find.byKey(const Key('demo_toggle_online')));
      await tester.pumpAndSettle();
      expect(appState.isOnline, isTrue);

      await tester.runAsync(() async {
        await appState.synchronizePendingForms();
      });
      await tester.pumpAndSettle();

      expect(appState.pendingSyncCount, equals(0));
      expect(appState.syncedCount, equals(4));

      // Alterna para o perfil Empresa Contratante e verifica mascaramento de nota sigilosa (AM-01) e bloqueio de formulário
      await tester.runAsync(() => appState.quickLoginAsRole(UserRole.empresa));
      await tester.pumpAndSettle();

      expect(find.textContaining('OBSERVAÇÃO TÉCNICA SIGILOSA PROTEGIDA (AM-01)'), findsWidgets);
      expect(find.textContaining('marco divisório do TCA judicial'), findsNothing);

      // Navega para a aba "Coleta Campo" (index 1) como Empresa e verifica bloqueio somente leitura
      await tester.tap(find.text('Coleta Campo'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Acesso Somente Leitura — Perfil Empresa Contratante (AM-01)'), findsOneWidget);
    });
  });
}

