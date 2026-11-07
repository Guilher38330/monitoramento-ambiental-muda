import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:trabalho_final/main.dart';
import 'package:trabalho_final/models/user_profile.dart';
import 'package:trabalho_final/models/water_soil_models.dart';
import 'package:trabalho_final/services/database_service.dart';
import 'package:trabalho_final/services/report_export_service.dart';
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

  group('Fase 3 — Mapa Interativo (AM-06), Água CONAMA 357/2005 (AM-07) e Conservação do Solo (AM-10)', () {
    late DatabaseService dbService;
    late AppState appState;

    Future<void> initPhase3State() async {
      dbService = DatabaseService.instance;
      await dbService.initializeForTest(inMemoryDatabasePath);
      appState = AppState(dbService: dbService);
      await appState.initialize();
    }

    test('Avalia limites CONAMA 357/2005 Classe 2 (AM-07), Unidades Modelo de Solo (AM-10), Camadas KML (AM-06) e bloqueio RBAC', () async {
      await initPhase3State();
      await appState.quickLoginAsRole(UserRole.tecnico);

      // 0. Testa valores de fronteira exatos dos limites CONAMA 357/2005 Classe 2 (casos de borda)
      expect(Conama357Limits.isPhCompliant(6.0), isTrue);
      expect(Conama357Limits.isPhCompliant(9.0), isTrue);
      expect(Conama357Limits.isPhCompliant(5.99), isFalse);
      expect(Conama357Limits.isPhCompliant(9.01), isFalse);
      expect(Conama357Limits.isTurbidityCompliant(100.0), isTrue);
      expect(Conama357Limits.isTurbidityCompliant(100.1), isFalse);
      expect(Conama357Limits.isOdCompliant(5.0), isTrue);
      expect(Conama357Limits.isOdCompliant(4.99), isFalse);
      expect(Conama357Limits.isDboCompliant(5.0), isTrue);
      expect(Conama357Limits.isDboCompliant(5.01), isFalse);
      expect(Conama357Limits.isPhosphorusCompliant(0.050), isTrue);
      expect(Conama357Limits.isPhosphorusCompliant(0.051), isFalse);
      expect(Conama357Limits.isColiformsCompliant(1000), isTrue);
      expect(Conama357Limits.isColiformsCompliant(1001), isFalse);

      // 1. Verifica carregamento do seed da Fase 3 (5 laudos de água, 3 unidades de solo e 4 camadas KML)
      expect(appState.waterAnalyses.length, equals(5));
      expect(appState.soilUnits.length, equals(3));
      expect(appState.kmlOverlays.length, equals(4));

      // 2. Verifica detecção automática de violação CONAMA 357/2005 na 1ª campanha de PC-MUDA-01 vs conformidade na 2ª campanha
      final ptMudaAnalyses = appState.getWaterAnalysesForPoint('pt-muda-01');
      expect(ptMudaAnalyses.length, equals(2));

      final campaign1 = ptMudaAnalyses.firstWhere((a) => a.id == 'wat-muda-01-c1');
      final campaign2 = ptMudaAnalyses.firstWhere((a) => a.id == 'wat-muda-01-c2');

      expect(campaign1.isConamaCompliant, isFalse);
      expect(campaign1.violations.length, equals(6)); // Todos os 6 parâmetros violados na linha de base
      expect(campaign2.isConamaCompliant, isTrue);
      expect(campaign2.violations, isEmpty);

      // 3. Registra novo laudo de água com violação de Turbidez e Fósforo (AM-07)
      final createdWater = await appState.saveWaterQualityAnalysis(
        projectId: 'proj-muda-01',
        propertyId: 'prop-muda-01',
        pointId: 'pt-muda-01',
        reportCode: 'LAUDO-TEST-CONAMA-999',
        sampleDate: '06/11/2026',
        campaignName: 'Campanha Extra Pós-Chuva Torrencial',
        laboratoryName: 'LabHidro UNISC',
        ph: 6.5,
        turbidityUnt: 135.0, // > 100 UNT (violação)
        dissolvedOxygenMgL: 6.8,
        dboMgL: 3.2,
        totalPhosphorusMgL: 0.075, // > 0.050 mg/L (violação)
        thermotolerantColiformsNmp: 420,
        waterTemperatureC: 20.1,
        flowRateLs: 5.4,
        technicalConclusion: 'Pico transitório de turbidez pós-precipitação intensa.',
        isConfidentialReport: true,
        confidentialLabNotes: 'Nota sigilosa de auditoria hidroambiental.',
      );

      expect(createdWater, isNotNull);
      expect(createdWater!.isConamaCompliant, isFalse);
      expect(createdWater.violations.length, equals(2));
      expect(appState.waterAnalyses.length, equals(6));

      // 4. Registra nova Unidade Modelo de Conservação do Solo (AM-10) e valida cálculo de abatimento USLE
      final createdSoil = await appState.saveSoilConservationUnit(
        projectId: 'proj-psa-02',
        propertyId: 'prop-psa-01',
        pointId: 'pt-psa-02',
        code: 'UMCS-TEST-04',
        name: 'Unidade Demonstrativa Terraços Base Larga',
        areaHa: 30.0,
        soilClass: 'Argissolo Vermelho',
        slopePercent: 11.5,
        adoptedPractices: const [
          'Plantio Direto na Palha',
          'Terraceamento em Nível',
        ],
        vegetalCoverPercent: 91.0,
        baselineErosionTonHaYear: 20.0,
        currentErosionTonHaYear: 3.0,
        infiltrationBasinsCount: 14,
        conservationLevel: 'Excelente',
        lastEvaluationDate: '06/11/2026',
        technicalNotes: 'Abatimento expressivo de sedimentos.',
        confidentialOwnerAgreement: 'Termo restrito LGPD.',
      );

      expect(createdSoil, isNotNull);
      expect(createdSoil!.erosionAbatementTonHaYear, closeTo(17.0, 0.01));
      expect(createdSoil.erosionReductionPercent, closeTo(85.0, 0.1));
      expect(appState.soilUnits.length, equals(4));

      // 5. Verifica bloqueio RBAC para perfil Empresa Contratante (AM-01)
      await appState.quickLoginAsRole(UserRole.empresa);
      final blockedWater = await appState.saveWaterQualityAnalysis(
        projectId: 'proj-muda-01',
        propertyId: 'prop-muda-01',
        pointId: 'pt-muda-01',
        reportCode: 'LAUDO-BLOCKED',
        sampleDate: '06/11/2026',
        campaignName: 'Bloqueado',
        laboratoryName: 'Lab',
        ph: 7.0,
        turbidityUnt: 10.0,
        dissolvedOxygenMgL: 7.0,
        dboMgL: 2.0,
        totalPhosphorusMgL: 0.02,
        thermotolerantColiformsNmp: 100,
        waterTemperatureC: 20.0,
        flowRateLs: 3.0,
        technicalConclusion: 'x',
        isConfidentialReport: false,
        confidentialLabNotes: 'x',
      );
      expect(blockedWater, isNull);

      final blockedSoil = await appState.saveSoilConservationUnit(
        projectId: 'proj-psa-02',
        propertyId: 'prop-psa-01',
        pointId: 'pt-psa-02',
        code: 'UMCS-BLOCKED',
        name: 'Bloqueado',
        areaHa: 10.0,
        soilClass: 'Solo',
        slopePercent: 5.0,
        adoptedPractices: const ['Plantio Direto na Palha'],
        vegetalCoverPercent: 80.0,
        baselineErosionTonHaYear: 10.0,
        currentErosionTonHaYear: 2.0,
        infiltrationBasinsCount: 4,
        conservationLevel: 'Adequado',
        lastEvaluationDate: '06/11/2026',
        technicalNotes: 'x',
        confidentialOwnerAgreement: 'x',
      );
      expect(blockedSoil, isNull);
    });

    testWidgets('Fluxo UI Fase 3: Mapa Interativo + Croqui KML (AM-06), Água CONAMA 357/2005 (AM-07) e Conservação do Solo (AM-10)', (WidgetTester tester) async {
      await tester.runAsync(() async {
        await initPhase3State();
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

      // 1. Navega para a aba "Mapa & Histórico" (index 3 - AM-06)
      await tester.tap(find.text('Mapa & Histórico'));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('interactive_flutter_map_container')), findsOneWidget);
      expect(find.byKey(const Key('selected_point_inspector_pt-muda-01')), findsOneWidget);

      // Abre o modal de Croqui Técnico & Camada KML Processada (AM-06)
      await tester.tap(find.byKey(const Key('open_kml_croqui_inspector_button')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('kml_croqui_inspector_dialog')), findsOneWidget);
      expect(find.byKey(const Key('technical_croqui_schematic_canvas')), findsOneWidget);
      expect(find.textContaining('MUDA_RP01_Fazenda_Santa_Ines_Croqui_APP.kml'), findsWidgets);

      await tester.tap(find.byKey(const Key('close_kml_croqui_dialog_btn')));
      await tester.pumpAndSettle();

      // Seleciona outro ponto de coleta no seletor rápido do mapa (PC-PSA-01)
      final psaPointChip = find.byKey(const Key('select_point_chip_pt-psa-01'));
      await tester.ensureVisible(psaPointChip);
      await tester.tap(psaPointChip);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('selected_point_inspector_pt-psa-01')), findsOneWidget);

      // Usa o botão de atalho do mapa para abrir diretamente os Laudos CONAMA & Solo daquele ponto (AM-07)
      final jumpBtn = find.byKey(const Key('jump_to_water_soil_from_map_btn'));
      await tester.ensureVisible(jumpBtn);
      await tester.tap(jumpBtn);
      await tester.pumpAndSettle();

      // 2. Verifica tela de Qualidade da Água CONAMA 357/2005 (AM-07)
      expect(find.textContaining('Padrões CONAMA nº 357/2005'), findsOneWidget);
      expect(find.byKey(const Key('historical_water_comparison_card')), findsOneWidget);
      expect(find.byKey(const Key('water_analysis_card_wat-psa-01-c2')), findsOneWidget);

      // Filtra pelo ponto PC-MUDA-01 e verifica que tanto o laudo conforme (2ª campanha) quanto o com violação (1ª campanha) estão visíveis
      await tester.tap(find.byKey(const Key('water_filter_point_pt-muda-01')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('water_analysis_card_wat-muda-01-c2')), findsOneWidget);
      expect(find.byKey(const Key('water_analysis_card_wat-muda-01-c1')), findsOneWidget);

      // 3. Alterna no SegmentedButton para a aba "Conservação Solo (3) • AM-10"
      await tester.tap(find.textContaining('Conservação Solo'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Unidades Modelo de Conservação do Solo (AM-10)'), findsOneWidget);
      expect(find.byKey(const Key('soil_unit_card_soil-unit-01')), findsOneWidget);

      // 4. Alterna para o perfil Empresa Contratante (AM-01) e verifica proteção dos acordos sigilosos de solo e laudos restritos de água
      await tester.runAsync(() => appState.quickLoginAsRole(UserRole.empresa));
      await tester.pumpAndSettle();

      expect(find.textContaining('ACORDO INDIVIDUAL E CAR/CPF RESTRITOS (AM-01)'), findsWidgets);
      expect(find.byKey(const Key('open_new_soil_unit_dialog_button')), findsNothing);
    });
  });

  group('Fase 4 — Dashboards de Indicadores (AM-08), Relatórios PDF e Planilhas Excel/CSV no Celular (AM-09 + 3º Critério de Aceite)', () {
    late DatabaseService dbService;
    late AppState appState;

    Future<void> initPhase4State() async {
      dbService = DatabaseService.instance;
      await dbService.initializeForTest(inMemoryDatabasePath);
      appState = AppState(dbService: dbService);
      await appState.initialize();
    }

    test('3º Critério de Aceite: Calcula KPIs consolidados, gera PDF válido (%PDF-) e Planilha CSV com controle rigoroso de sigilo por perfil (AM-01, AM-08, AM-09)', () async {
      await initPhase4State();

      // 1. Verifica cálculo de KPIs para Todos, Muda e PSA (AM-08)
      final kpiAll = ReportExportService.calculateKpis(
        appState: appState,
        programFilter: 'TODOS',
      );
      expect(kpiAll.projectsCount, equals(2));
      expect(kpiAll.propertiesCount, equals(4));
      expect(kpiAll.collectionPointsCount, equals(6));
      expect(kpiAll.totalRestorationAreaHa, greaterThan(100.0));
      expect(kpiAll.totalTargetSeedlings, equals(127000));
      expect(kpiAll.averageSurvivalRatePercent, closeTo(88.3, 0.2));
      expect(kpiAll.waterAnalysesCount, equals(5));
      expect(kpiAll.waterCompliantCount, equals(3));
      expect(kpiAll.conamaCompliancePercent, closeTo(60.0, 0.1));
      expect(kpiAll.soilUnitsCount, equals(3));
      expect(kpiAll.totalErosionAbatementTonYear, greaterThan(500.0));

      final kpiMuda = ReportExportService.calculateKpis(
        appState: appState,
        programFilter: 'MUDA',
      );
      expect(kpiMuda.projectsCount, equals(1));
      expect(kpiMuda.totalTargetSeedlings, equals(85000));

      final kpiPsa = ReportExportService.calculateKpis(
        appState: appState,
        programFilter: 'PSA',
      );
      expect(kpiPsa.projectsCount, equals(1));
      expect(kpiPsa.totalTargetSeedlings, equals(42000));

      // Caso de borda: filtro inexistente retorna KPIs zerados sem divisão por zero (NaN)
      final kpiEmpty = ReportExportService.calculateKpis(
        appState: appState,
        programFilter: 'FILTRO_INEXISTENTE',
      );
      expect(kpiEmpty.projectsCount, equals(0));
      expect(kpiEmpty.averageSurvivalRatePercent, equals(0.0));
      expect(kpiEmpty.conamaCompliancePercent, equals(0.0));
      expect(kpiEmpty.averageSoilVegetalCoverPercent, equals(0.0));

      // 2. Testa Geração de PDF e Planilha CSV com perfil Equipe Técnica / Admin (sigilo autorizado - AM-01)
      await appState.quickLoginAsRole(UserRole.tecnico);

      final pdfBytesTecnico =
          await ReportExportService.generateTechnicalReportPdfBytes(
        appState: appState,
        programFilter: 'TODOS',
      );
      expect(pdfBytesTecnico.lengthInBytes, greaterThan(2000));
      // Assinatura mágica de arquivo PDF ("%PDF-")
      final pdfHeader = String.fromCharCodes(pdfBytesTecnico.take(5));
      expect(pdfHeader, equals('%PDF-'));

      final csvTecnico = ReportExportService.generateSpreadsheetCsvContent(
        appState: appState,
        programFilter: 'TODOS',
      );
      expect(csvTecnico, contains('SECAO 1 - INDICADORES CONSOLIDADOS (AM-08)'));
      expect(csvTecnico, contains('SECAO 3 - LAUDOS DE QUALIDADE DA AGUA CONAMA 357/2005'));
      expect(csvTecnico, contains('418.920.330-53')); // CPF visível para Técnico/Admin

      // 3. Testa Geração de PDF e Planilha CSV com perfil Empresa Contratante (mascaramento obrigatório AM-01)
      await appState.quickLoginAsRole(UserRole.empresa);

      final pdfBytesEmpresa =
          await ReportExportService.generateTechnicalReportPdfBytes(
        appState: appState,
        programFilter: 'TODOS',
      );
      expect(pdfBytesEmpresa.lengthInBytes, greaterThan(2000));
      expect(String.fromCharCodes(pdfBytesEmpresa.take(5)), equals('%PDF-'));

      final csvEmpresa = ReportExportService.generateSpreadsheetCsvContent(
        appState: appState,
        programFilter: 'TODOS',
      );
      expect(csvEmpresa, contains('NAO (DADOS SIGILOSOS MASCARADOS)'));
      expect(csvEmpresa, isNot(contains('418.920.330-53'))); // CPF jamais exposto para Empresa!
      expect(csvEmpresa, contains('Restrito - LGPD/Sigilo'));
      expect(csvEmpresa, contains('Sigilo Contratual (AM-01)'));
      expect(csvEmpresa, contains('OBSERVACAO TECNICA SIGILOSA PROTEGIDA (AM-01)'));
      expect(csvEmpresa, contains('LAUDO COMPLEMENTAR RESTRITO (AM-01)'));

      // 4. Caso de borda: Textos longos multiparágrafo, emojis (surrogates UTF-16) e delimitadores CSV (';' e '"')
      await appState.quickLoginAsRole(UserRole.tecnico);
      final longEmojiNote =
          'Relato extenso de campo 🌳💧🔬: ${"Observação detalhada com ponto-e-vírgula; e \"aspas duplas\" em múltiplas linhas.\n" * 18}';
      await appState.saveFieldFormRecord(
        customClientUuid: 'uuid-edge-long-emoji-01',
        projectId: 'proj-muda-01',
        propertyId: 'prop-muda-01',
        pointId: 'pt-muda-01',
        templateName: 'Vistoria de Sobrevivência de Mudas (Muda)',
        vegetationStage: 'Estágio Inicial — Pegamento de Mudas (0 a 12 meses)',
        survivalRatePercent: 93.0,
        erosionStatus: 'Ausente — Solo Estabilizado com Cobertura Vegetal',
        invasiveSpeciesPresent: false,
        maintenancePerformed: 'Coroamento Manual + Controle de Formigas Cortadeiras',
        technicalNotes: longEmojiNote,
        isConfidential: false,
        latitude: -29.7132,
        longitude: -52.4295,
        gpsAccuracyMeters: 2.5,
        photoLocalPath: 'demo://edge_emoji.jpg',
        photoCapturedAt: '2026-11-06T15:00:00Z',
        photoCaption: 'Foto com emoji 📸 e ; ponto e vírgula',
      );

      final pdfMultiPageBytes =
          await ReportExportService.generateTechnicalReportPdfBytes(
        appState: appState,
        programFilter: 'MUDA',
      );
      expect(pdfMultiPageBytes.lengthInBytes, greaterThan(2000));
      expect(String.fromCharCodes(pdfMultiPageBytes.take(5)), equals('%PDF-'));

      final csvEscaped = ReportExportService.generateSpreadsheetCsvContent(
        appState: appState,
        programFilter: 'MUDA',
      );
      // Verifica que o valor com ';' e '"' foi devidamente escapado entre aspas duplas ("...""aspas duplas""...")
      expect(csvEscaped, contains('""aspas duplas""'));
    });

    testWidgets('Fluxo UI Fase 4: Dashboard de Indicadores, Gráficos fl_chart e Compartilhamento de Relatórios PDF e Excel/CSV no Celular (AM-08, AM-09)', (WidgetTester tester) async {
      await tester.runAsync(() async {
        await initPhase4State();
      });

      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.runAsync(() => appState.quickLoginAsRole(UserRole.admin));
      await tester.pumpWidget(MudaPsaApp(appState: appState));
      await tester.pumpAndSettle();

      // 1. Navega para a Aba 5 "Indicadores" (index 4)
      await tester.tap(find.text('Indicadores'));
      await tester.pumpAndSettle();

      // Verifica renderização dos KPIs e dos 3 Gráficos Interativos fl_chart (AM-08)
      expect(find.byKey(const Key('kpi_card_restored_area')), findsOneWidget);
      expect(find.byKey(const Key('kpi_card_seedlings_survival')), findsOneWidget);
      expect(find.byKey(const Key('kpi_card_conama_compliance')), findsOneWidget);
      expect(find.byKey(const Key('kpi_card_soil_conservation')), findsOneWidget);

      expect(find.byKey(const Key('chart_card_seedling_survival')), findsOneWidget);
      expect(find.byKey(const Key('chart_card_water_conama')), findsOneWidget);
      expect(find.byKey(const Key('chart_card_schedule_and_soil')), findsOneWidget);

      // 2. Testa filtro por Programa ('Programa Muda' e 'Programa PSA')
      await tester.tap(find.byKey(const Key('dashboard_filter_muda')));
      await tester.pumpAndSettle();
      expect(find.textContaining('Escopo: MUDA'), findsOneWidget);

      await tester.tap(find.byKey(const Key('dashboard_filter_psa')));
      await tester.pumpAndSettle();
      expect(find.textContaining('Escopo: PSA'), findsOneWidget);

      await tester.tap(find.byKey(const Key('dashboard_filter_todos')));
      await tester.pumpAndSettle();
      expect(find.textContaining('Escopo: TODOS'), findsOneWidget);

      // 3. Gera e visualiza Relatório Técnico PDF direto no celular (AM-09 + 3º Critério de Aceite)
      final pdfBtn = find.byKey(const Key('btn_generate_share_pdf_report'));
      await tester.ensureVisible(pdfBtn);
      await tester.runAsync(() async {
        await tester.tap(pdfBtn);
        await Future<void>.delayed(const Duration(milliseconds: 250));
      });
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('pdf_report_preview_dialog')), findsOneWidget);
      expect(find.textContaining('Documento PDF Gerado Localmente'), findsOneWidget);
      await tester.tap(find.byKey(const Key('close_pdf_preview_dialog_button')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('report_export_feedback_banner')), findsOneWidget);

      // 4. Alterna para Empresa Contratante e abre a Exportação Planilha Excel/CSV verificando mascaramento AM-01
      await tester.runAsync(() => appState.quickLoginAsRole(UserRole.empresa));
      await tester.pumpAndSettle();

      final csvBtn = find.byKey(const Key('btn_export_share_csv_spreadsheet'));
      await tester.ensureVisible(csvBtn);
      await tester.tap(csvBtn);
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('csv_spreadsheet_preview_dialog')), findsOneWidget);
      expect(
        find.textContaining('Perfil Empresa Contratante (AM-01): Dados sigilosos'),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const Key('close_csv_preview_dialog_button')));
      await tester.pumpAndSettle();
    });
  });
}

