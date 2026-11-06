import '../models/field_form_record.dart';
import '../models/user_profile.dart';
import 'database_service.dart';

/// Resultado consolidado de uma operação de sincronização da fila local (AM-04, AM-12).
class SyncBatchResult {
  final bool success;
  final int syncedCount;
  final int conflictCount;
  final int failedCount;
  final String message;

  const SyncBatchResult({
    required this.success,
    required this.syncedCount,
    required this.conflictCount,
    required this.failedCount,
    required this.message,
  });
}

/// Serviço de Sincronização Offline-First com a API REST/JWT simulada da plataforma
/// Muda & PSA (AM-04, AM-11, AM-12 + 1º Critério de Aceite).
class MockApiSyncService {
  final DatabaseService _dbService;

  MockApiSyncService({DatabaseService? dbService})
      : _dbService = dbService ?? DatabaseService.instance;

  /// Processa todos os registros `pending` ou `failed` na fila SQLite local.
  /// - Valida Token JWT ativo e permissão do perfil (AM-01).
  /// - Respeita `isOnline` (mantém na fila sem perder dados locais - AM-04/AM-12).
  /// - Respeita `simulateNetworkFailure` (retorna HTTP 503 e marca `failed` - AM-12).
  /// - Respeita `simulateConflict` (dispara HTTP 409 com divergência realista - AM-04).
  /// - Garante idempotência pelo `clientUuid` para nunca criar duplicatas (1º Critério de Aceite).
  Future<SyncBatchResult> processSyncQueue({
    required AppUser currentUser,
    required String? jwtToken,
    required bool isOnline,
    required bool simulateNetworkFailure,
    required bool simulateConflict,
  }) async {
    if (jwtToken == null || !JwtAuthSimulator.validateToken(jwtToken)) {
      return const SyncBatchResult(
        success: false,
        syncedCount: 0,
        conflictCount: 0,
        failedCount: 0,
        message:
            'Sessão JWT inválida ou expirada (HTTP 401). Refaça login para sincronizar.',
      );
    }

    if (!currentUser.canRegisterFieldData) {
      return SyncBatchResult(
        success: false,
        syncedCount: 0,
        conflictCount: 0,
        failedCount: 0,
        message:
            'Acesso restrito (AM-01): O perfil ${currentUser.role.label} é somente leitura e não executa sincronização de escrita.',
      );
    }

    if (!isOnline) {
      final allForms = await _dbService.getFieldForms();
      final pendingCount =
          allForms.where((r) => r.isPendingOrFailed).length;
      return SyncBatchResult(
        success: false,
        syncedCount: 0,
        conflictCount: 0,
        failedCount: 0,
        message:
            'Dispositivo em Modo OFFLINE (AM-04 / AM-12). $pendingCount registro(s) permanecem protegidos na fila SQLite local aguardando conexão.',
      );
    }

    final allForms = await _dbService.getFieldForms();
    final queue = allForms.where((r) => r.isPendingOrFailed).toList();

    if (queue.isEmpty) {
      return const SyncBatchResult(
        success: true,
        syncedCount: 0,
        conflictCount: 0,
        failedCount: 0,
        message:
            'Fila local em dia! Nenhum registro pendente para enviar à plataforma.',
      );
    }

    final nowIso = DateTime.now().toUtc().toIso8601String();

    // Simulação de falha de rede / indisponibilidade da API (AM-12)
    if (simulateNetworkFailure) {
      int failedCount = 0;
      for (final record in queue) {
        final auditEntry = AuditLogEntry(
          id: 'aud-err-${DateTime.now().microsecondsSinceEpoch}-$failedCount',
          action: 'FALHA_REDE_AM12',
          summary:
              'Falha de comunicação HTTP 503 (Gateway Timeout / Instabilidade de Rede em Campo). Dados locais e fotos preservados na fila SQLite.',
          authorId: currentUser.id,
          authorName: currentUser.name,
          authorRole: currentUser.role.label,
          timestamp: nowIso,
          version: record.version,
        );

        final updated = record.copyWith(
          syncStatus: SyncStatus.failed,
          syncErrorMessage:
              'Erro HTTP 503 (AM-12): Tempo limite de conexão com a API Muda/PSA esgotado. Nenhum dado foi perdido; tente reenviar quando o sinal estabilizar.',
          auditHistory: [...record.auditHistory, auditEntry],
        );
        await _dbService.upsertFieldForm(updated);
        failedCount++;
      }

      return SyncBatchResult(
        success: false,
        syncedCount: 0,
        conflictCount: 0,
        failedCount: failedCount,
        message:
            'Falha de Rede Simulada (HTTP 503 - AM-12): $failedCount registro(s) marcaram erro de envio, mas estão 100% protegidos no SQLite local para nova tentativa.',
      );
    }

    int syncedCount = 0;
    int conflictCount = 0;

    for (var i = 0; i < queue.length; i++) {
      final record = queue[i];

      // Se a chave "Simular Conflito (AM-04)" estiver ativa, gera conflito no primeiro item da fila
      if (simulateConflict && i == 0) {
        final conflictRecord = _buildConflictVersion(
          record: record,
          currentUser: currentUser,
          timestampIso: nowIso,
        );
        await _dbService.upsertFieldForm(conflictRecord);
        conflictCount++;
        continue;
      }

      final nextVersion = record.version + 1;
      final auditEntry = AuditLogEntry(
        id: 'aud-sync-${DateTime.now().microsecondsSinceEpoch}-$i',
        action: 'SINCRONIZADO_SERVIDOR',
        summary:
            'Sincronização idempotente concluída via API JWT (clientUuid=${record.clientUuid}). Foto e coordenadas validadas sem duplicação.',
        authorId: currentUser.id,
        authorName: currentUser.name,
        authorRole: currentUser.role.label,
        timestamp: nowIso,
        version: nextVersion,
        syncedAt: nowIso,
      );

      final syncedRecord = record.copyWith(
        syncStatus: SyncStatus.synced,
        clearSyncError: true,
        clearConflictServerData: true,
        version: nextVersion,
        syncedAt: nowIso,
        auditHistory: [...record.auditHistory, auditEntry],
      );

      await _dbService.upsertFieldForm(syncedRecord);
      syncedCount++;
    }

    if (conflictCount > 0) {
      return SyncBatchResult(
        success: false,
        syncedCount: syncedCount,
        conflictCount: conflictCount,
        failedCount: 0,
        message:
            'Sincronização parcial: $syncedCount sincronizado(s) e $conflictCount conflito(s) de versão detectado(s) (AM-04). Resolva o conflito na lista.',
      );
    }

    return SyncBatchResult(
      success: true,
      syncedCount: syncedCount,
      conflictCount: 0,
      failedCount: 0,
      message:
          '$syncedCount registro(s) sincronizado(s) com sucesso e sem duplicações (1º Critério de Aceite + AM-04)!',
    );
  }

  /// Força um conflito de versão realista em um registro específico para demonstração imediata (AM-04).
  Future<FieldFormRecord> forceConflictOnRecord({
    required FieldFormRecord record,
    required AppUser currentUser,
  }) async {
    final nowIso = DateTime.now().toUtc().toIso8601String();
    final conflicted = _buildConflictVersion(
      record: record,
      currentUser: currentUser,
      timestampIso: nowIso,
    );
    await _dbService.upsertFieldForm(conflicted);
    return conflicted;
  }

  /// Resolve um conflito de sincronização (AM-04):
  /// - `keepFieldVersion == true`: mantém as respostas coletadas em campo pelo técnico.
  /// - `keepFieldVersion == false`: aceita a revisão existente no servidor da plataforma.
  /// Em ambos os casos, incrementa `version`, define `syncedAt` e grava `AuditLogEntry` (AM-11).
  Future<FieldFormRecord> resolveConflict({
    required FieldFormRecord record,
    required bool keepFieldVersion,
    required AppUser currentUser,
  }) async {
    final serverData = record.conflictServerData;
    final nowIso = DateTime.now().toUtc().toIso8601String();
    final resolvedVersion =
        (serverData != null && serverData.serverVersion >= record.version)
            ? serverData.serverVersion + 1
            : record.version + 1;

    final actionCode = keepFieldVersion
        ? 'CONFLITO_RESOLVIDO_CAMPO'
        : 'CONFLITO_RESOLVIDO_SERVIDOR';

    final summaryText = keepFieldVersion
        ? 'Conflito resolvido por ${currentUser.name}: mantida a coleta in loco de campo sobre a versão do servidor (v$resolvedVersion).'
        : 'Conflito resolvido por ${currentUser.name}: adotada a revisão da plataforma central (${serverData?.serverAuthorName ?? "Servidor"}) (v$resolvedVersion).';

    final auditEntry = AuditLogEntry(
      id: 'aud-res-${DateTime.now().microsecondsSinceEpoch}',
      action: actionCode,
      summary: summaryText,
      authorId: currentUser.id,
      authorName: currentUser.name,
      authorRole: currentUser.role.label,
      timestamp: nowIso,
      version: resolvedVersion,
      syncedAt: nowIso,
    );

    final resolvedRecord = keepFieldVersion || serverData == null
        ? record.copyWith(
            syncStatus: SyncStatus.synced,
            clearSyncError: true,
            clearConflictServerData: true,
            version: resolvedVersion,
            syncedAt: nowIso,
            auditHistory: [...record.auditHistory, auditEntry],
          )
        : record.copyWith(
            vegetationStage: serverData.vegetationStage,
            survivalRatePercent: serverData.survivalRatePercent,
            erosionStatus: serverData.erosionStatus,
            invasiveSpeciesPresent: serverData.invasiveSpeciesPresent,
            maintenancePerformed: serverData.maintenancePerformed,
            technicalNotes: serverData.technicalNotes,
            syncStatus: SyncStatus.synced,
            clearSyncError: true,
            clearConflictServerData: true,
            version: resolvedVersion,
            syncedAt: nowIso,
            auditHistory: [...record.auditHistory, auditEntry],
          );

    await _dbService.upsertFieldForm(resolvedRecord);
    return resolvedRecord;
  }

  FieldFormRecord _buildConflictVersion({
    required FieldFormRecord record,
    required AppUser currentUser,
    required String timestampIso,
  }) {
    final serverVersion = record.version + 1;
    final adjustedRate = (record.survivalRatePercent >= 15.0)
        ? (record.survivalRatePercent - 6.5)
        : (record.survivalRatePercent + 8.0);

    final serverPayload = ConflictServerPayload(
      serverVersion: serverVersion,
      serverAuthorName: 'Dra. Helena Vasconcelos (Revisão Plataforma Web)',
      serverAuthorRole: 'Administrador',
      serverUpdatedAt: timestampIso,
      vegetationStage: FieldFormRecord.vegetationStageOptions.firstWhere(
        (opt) => opt != record.vegetationStage,
        orElse: () => record.vegetationStage,
      ),
      survivalRatePercent: double.parse(adjustedRate.toStringAsFixed(1)),
      erosionStatus: FieldFormRecord.erosionStatusOptions.firstWhere(
        (opt) => opt != record.erosionStatus,
        orElse: () => record.erosionStatus,
      ),
      invasiveSpeciesPresent: !record.invasiveSpeciesPresent,
      maintenancePerformed: FieldFormRecord.maintenanceOptions.firstWhere(
        (opt) => opt != record.maintenancePerformed,
        orElse: () => record.maintenancePerformed,
      ),
      technicalNotes:
          'Revisão concorrente registrada na plataforma central durante homologação de laudo semestral. Verificar divergência com vistoria in loco.',
      divergenceReason:
          'Conflito de concorrência (HTTP 409): o ponto ${record.pointId} recebeu atualização na plataforma central antes da sincronização do pacote offline.',
    );

    final auditEntry = AuditLogEntry(
      id: 'aud-conf-${DateTime.now().microsecondsSinceEpoch}',
      action: 'CONFLITO_DETECTADO',
      summary:
          'Conflito de sincronização (HTTP 409 - AM-04): divergência entre coleta local (v${record.version}) e revisão na plataforma (v$serverVersion).',
      authorId: currentUser.id,
      authorName: currentUser.name,
      authorRole: currentUser.role.label,
      timestamp: timestampIso,
      version: record.version,
    );

    return record.copyWith(
      syncStatus: SyncStatus.conflict,
      syncErrorMessage:
          'Conflito de versão detectado (AM-04): compare os dados de campo com a revisão do servidor para decidir qual versão manter.',
      conflictServerData: serverPayload,
      auditHistory: [...record.auditHistory, auditEntry],
    );
  }
}
