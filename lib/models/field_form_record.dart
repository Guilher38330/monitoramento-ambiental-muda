import 'dart:convert';
import 'package:flutter/material.dart';

/// Status de sincronização de um registro de campo na fila local (AM-04, AM-12).
enum SyncStatus {
  pending,
  syncing,
  synced,
  conflict,
  failed;

  String get label {
    switch (this) {
      case SyncStatus.pending:
        return 'Na Fila (Offline)';
      case SyncStatus.syncing:
        return 'Sincronizando...';
      case SyncStatus.synced:
        return 'Sincronizado';
      case SyncStatus.conflict:
        return 'Conflito de Versão';
      case SyncStatus.failed:
        return 'Falha no Envio';
    }
  }

  String get shortBadge {
    switch (this) {
      case SyncStatus.pending:
        return 'PENDENTE OFFLINE';
      case SyncStatus.syncing:
        return 'ENVIANDO...';
      case SyncStatus.synced:
        return 'SINCRONIZADO';
      case SyncStatus.conflict:
        return 'CONFLITO AM-04';
      case SyncStatus.failed:
        return 'ERRO REDE AM-12';
    }
  }

  IconData get icon {
    switch (this) {
      case SyncStatus.pending:
        return Icons.schedule_send_rounded;
      case SyncStatus.syncing:
        return Icons.sync_rounded;
      case SyncStatus.synced:
        return Icons.cloud_done_rounded;
      case SyncStatus.conflict:
        return Icons.warning_amber_rounded;
      case SyncStatus.failed:
        return Icons.cloud_off_rounded;
    }
  }

  Color get color {
    switch (this) {
      case SyncStatus.pending:
        return const Color(0xFF0277BD);
      case SyncStatus.syncing:
        return const Color(0xFF00838F);
      case SyncStatus.synced:
        return const Color(0xFF2E7D32);
      case SyncStatus.conflict:
        return const Color(0xFFEF6C00);
      case SyncStatus.failed:
        return const Color(0xFFC62828);
    }
  }

  Color get backgroundColor {
    switch (this) {
      case SyncStatus.pending:
        return const Color(0xFFE1F5FE);
      case SyncStatus.syncing:
        return const Color(0xFFE0F7FA);
      case SyncStatus.synced:
        return const Color(0xFFE8F5E9);
      case SyncStatus.conflict:
        return const Color(0xFFFFF3E0);
      case SyncStatus.failed:
        return const Color(0xFFFFEBEE);
    }
  }

  static SyncStatus fromString(String value) {
    return SyncStatus.values.firstWhere(
      (s) => s.name.toLowerCase() == value.toLowerCase(),
      orElse: () => SyncStatus.pending,
    );
  }
}

/// Entrada na trilha de auditoria e autoria do registro de campo (AM-11).
class AuditLogEntry {
  final String id;
  final String action; // 'CRIACAO_OFFLINE', 'SINCRONIZADO_SERVIDOR', 'FALHA_REDE_AM12', 'CONFLITO_DETECTADO', 'CONFLITO_RESOLVIDO_CAMPO', 'CONFLITO_RESOLVIDO_SERVIDOR'
  final String summary;
  final String authorId;
  final String authorName;
  final String authorRole;
  final String timestamp;
  final int version;
  final String? syncedAt;

  const AuditLogEntry({
    required this.id,
    required this.action,
    required this.summary,
    required this.authorId,
    required this.authorName,
    required this.authorRole,
    required this.timestamp,
    required this.version,
    this.syncedAt,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'action': action,
        'summary': summary,
        'authorId': authorId,
        'authorName': authorName,
        'authorRole': authorRole,
        'timestamp': timestamp,
        'version': version,
        'syncedAt': syncedAt,
      };

  factory AuditLogEntry.fromMap(Map<String, dynamic> map) => AuditLogEntry(
        id: map['id'] as String,
        action: map['action'] as String,
        summary: map['summary'] as String,
        authorId: map['authorId'] as String,
        authorName: map['authorName'] as String,
        authorRole: map['authorRole'] as String,
        timestamp: map['timestamp'] as String,
        version: (map['version'] as num).toInt(),
        syncedAt: map['syncedAt'] as String?,
      );
}

/// Snapshot divergente da plataforma central para resolução de conflitos (AM-04).
class ConflictServerPayload {
  final int serverVersion;
  final String serverAuthorName;
  final String serverAuthorRole;
  final String serverUpdatedAt;
  final String vegetationStage;
  final double survivalRatePercent;
  final String erosionStatus;
  final bool invasiveSpeciesPresent;
  final String maintenancePerformed;
  final String technicalNotes;
  final String divergenceReason;

  const ConflictServerPayload({
    required this.serverVersion,
    required this.serverAuthorName,
    required this.serverAuthorRole,
    required this.serverUpdatedAt,
    required this.vegetationStage,
    required this.survivalRatePercent,
    required this.erosionStatus,
    required this.invasiveSpeciesPresent,
    required this.maintenancePerformed,
    required this.technicalNotes,
    required this.divergenceReason,
  });

  Map<String, dynamic> toMap() => {
        'serverVersion': serverVersion,
        'serverAuthorName': serverAuthorName,
        'serverAuthorRole': serverAuthorRole,
        'serverUpdatedAt': serverUpdatedAt,
        'vegetationStage': vegetationStage,
        'survivalRatePercent': survivalRatePercent,
        'erosionStatus': erosionStatus,
        'invasiveSpeciesPresent': invasiveSpeciesPresent,
        'maintenancePerformed': maintenancePerformed,
        'technicalNotes': technicalNotes,
        'divergenceReason': divergenceReason,
      };

  factory ConflictServerPayload.fromMap(Map<String, dynamic> map) =>
      ConflictServerPayload(
        serverVersion: (map['serverVersion'] as num).toInt(),
        serverAuthorName: map['serverAuthorName'] as String,
        serverAuthorRole: map['serverAuthorRole'] as String,
        serverUpdatedAt: map['serverUpdatedAt'] as String,
        vegetationStage: map['vegetationStage'] as String,
        survivalRatePercent: (map['survivalRatePercent'] as num).toDouble(),
        erosionStatus: map['erosionStatus'] as String,
        invasiveSpeciesPresent: map['invasiveSpeciesPresent'] as bool,
        maintenancePerformed: map['maintenancePerformed'] as String,
        technicalNotes: map['technicalNotes'] as String,
        divergenceReason: map['divergenceReason'] as String,
      );
}

/// Modelo completo de Formulário de Campo Offline com GPS, Foto Georreferenciada,
/// Fila de Sincronização Idempotente (`clientUuid`), Tratamento de Conflitos e Auditoria
/// (AM-03, AM-04, AM-05, AM-11, AM-12 + 1º Critério de Aceite).
class FieldFormRecord {
  /// Chave única gerada offline (UUID v4) para garantir idempotência e evitar duplicações
  /// no envio repetido para a plataforma central (1º Critério de Aceite / AM-04).
  final String clientUuid;

  final String projectId;
  final String propertyId;
  final String pointId;

  /// Nome do modelo de formulário configurado pela plataforma (AM-03).
  final String templateName;

  // Respostas validadas do formulário de campo (AM-03)
  final String vegetationStage;
  final double survivalRatePercent;
  final String erosionStatus;
  final bool invasiveSpeciesPresent;
  final String maintenancePerformed;
  final String technicalNotes;
  final bool isConfidential;

  // Coordenadas GPS capturadas em campo (AM-05)
  final double latitude;
  final double longitude;
  final double gpsAccuracyMeters;

  // Metadados da foto georreferenciada capturada em campo (AM-05)
  final String photoLocalPath;
  final String photoCapturedAt;
  final String photoCaption;

  // Controle de fila local, sincronização e conflitos (AM-04, AM-12)
  final SyncStatus syncStatus;
  final String? syncErrorMessage;
  final int version;

  // Autoria e rastreabilidade temporal (AM-11)
  final String authorId;
  final String authorName;
  final String authorRole;
  final String createdAt;
  final String? syncedAt;

  /// Dados divergentes do servidor caso ocorra conflito de versão (AM-04).
  final ConflictServerPayload? conflictServerData;

  /// Histórico completo de alterações e autoria do registro (AM-11).
  final List<AuditLogEntry> auditHistory;

  const FieldFormRecord({
    required this.clientUuid,
    required this.projectId,
    required this.propertyId,
    required this.pointId,
    required this.templateName,
    required this.vegetationStage,
    required this.survivalRatePercent,
    required this.erosionStatus,
    required this.invasiveSpeciesPresent,
    required this.maintenancePerformed,
    required this.technicalNotes,
    required this.isConfidential,
    required this.latitude,
    required this.longitude,
    required this.gpsAccuracyMeters,
    required this.photoLocalPath,
    required this.photoCapturedAt,
    required this.photoCaption,
    required this.syncStatus,
    this.syncErrorMessage,
    required this.version,
    required this.authorId,
    required this.authorName,
    required this.authorRole,
    required this.createdAt,
    this.syncedAt,
    this.conflictServerData,
    required this.auditHistory,
  });

  bool get isPendingOrFailed =>
      syncStatus == SyncStatus.pending || syncStatus == SyncStatus.failed;

  bool get hasConflict =>
      syncStatus == SyncStatus.conflict && conflictServerData != null;

  bool get hasPhoto => photoLocalPath.trim().isNotEmpty;

  /// Templates oficiais configurados pela plataforma (AM-03).
  static const List<String> availableTemplates = [
    'Vistoria de Sobrevivência de Mudas (Muda)',
    'Monitoramento de APP e Nascente (PSA)',
    'Inspeção de Erosão e Cercamento',
  ];

  static const List<String> vegetationStageOptions = [
    'Estágio Inicial — Pegamento de Mudas (0 a 12 meses)',
    'Estágio Intermediário — Fechamento de Entrelinhas (1 a 3 anos)',
    'Estágio Avançado — Formação de Dossel e Regeneração Natural',
    'Área sob Replantio / Adensamento Emergencial',
  ];

  static const List<String> erosionStatusOptions = [
    'Ausente — Solo Estabilizado com Cobertura Vegetal',
    'Laminar Leve — Sem Sulcos Ativos',
    'Sulcos Erosivos Moderados — Requer Contenção',
    'Processo Crítico / Ravina — Intervenção Imediata',
  ];

  static const List<String> maintenanceOptions = [
    'Coroamento Manual + Controle de Formigas Cortadeiras',
    'Roçada Seletiva de Gramíneas Exóticas + Adubação de Cobertura',
    'Manutenção de Cercamento de APP + Limpeza de Aceiro',
    'Desassoreamento de Bacia de Contenção / Olho d\'Água (PSA)',
    'Vistoria de Monitoramento Sem Intervenção Física',
  ];

  FieldFormRecord copyWith({
    String? clientUuid,
    String? projectId,
    String? propertyId,
    String? pointId,
    String? templateName,
    String? vegetationStage,
    double? survivalRatePercent,
    String? erosionStatus,
    bool? invasiveSpeciesPresent,
    String? maintenancePerformed,
    String? technicalNotes,
    bool? isConfidential,
    double? latitude,
    double? longitude,
    double? gpsAccuracyMeters,
    String? photoLocalPath,
    String? photoCapturedAt,
    String? photoCaption,
    SyncStatus? syncStatus,
    String? syncErrorMessage,
    bool clearSyncError = false,
    int? version,
    String? authorId,
    String? authorName,
    String? authorRole,
    String? createdAt,
    String? syncedAt,
    ConflictServerPayload? conflictServerData,
    bool clearConflictServerData = false,
    List<AuditLogEntry>? auditHistory,
  }) {
    return FieldFormRecord(
      clientUuid: clientUuid ?? this.clientUuid,
      projectId: projectId ?? this.projectId,
      propertyId: propertyId ?? this.propertyId,
      pointId: pointId ?? this.pointId,
      templateName: templateName ?? this.templateName,
      vegetationStage: vegetationStage ?? this.vegetationStage,
      survivalRatePercent: survivalRatePercent ?? this.survivalRatePercent,
      erosionStatus: erosionStatus ?? this.erosionStatus,
      invasiveSpeciesPresent:
          invasiveSpeciesPresent ?? this.invasiveSpeciesPresent,
      maintenancePerformed: maintenancePerformed ?? this.maintenancePerformed,
      technicalNotes: technicalNotes ?? this.technicalNotes,
      isConfidential: isConfidential ?? this.isConfidential,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      gpsAccuracyMeters: gpsAccuracyMeters ?? this.gpsAccuracyMeters,
      photoLocalPath: photoLocalPath ?? this.photoLocalPath,
      photoCapturedAt: photoCapturedAt ?? this.photoCapturedAt,
      photoCaption: photoCaption ?? this.photoCaption,
      syncStatus: syncStatus ?? this.syncStatus,
      syncErrorMessage:
          clearSyncError ? null : (syncErrorMessage ?? this.syncErrorMessage),
      version: version ?? this.version,
      authorId: authorId ?? this.authorId,
      authorName: authorName ?? this.authorName,
      authorRole: authorRole ?? this.authorRole,
      createdAt: createdAt ?? this.createdAt,
      syncedAt: syncedAt ?? this.syncedAt,
      conflictServerData: clearConflictServerData
          ? null
          : (conflictServerData ?? this.conflictServerData),
      auditHistory: auditHistory ?? this.auditHistory,
    );
  }

  Map<String, dynamic> toDbMap() => {
        'client_uuid': clientUuid,
        'project_id': projectId,
        'property_id': propertyId,
        'point_id': pointId,
        'template_name': templateName,
        'vegetation_stage': vegetationStage,
        'survival_rate_percent': survivalRatePercent,
        'erosion_status': erosionStatus,
        'invasive_species_present': invasiveSpeciesPresent ? 1 : 0,
        'maintenance_performed': maintenancePerformed,
        'technical_notes': technicalNotes,
        'is_confidential': isConfidential ? 1 : 0,
        'latitude': latitude,
        'longitude': longitude,
        'gps_accuracy_meters': gpsAccuracyMeters,
        'photo_local_path': photoLocalPath,
        'photo_captured_at': photoCapturedAt,
        'photo_caption': photoCaption,
        'sync_status': syncStatus.name,
        'sync_error_message': syncErrorMessage,
        'version': version,
        'author_id': authorId,
        'author_name': authorName,
        'author_role': authorRole,
        'created_at': createdAt,
        'synced_at': syncedAt,
        'conflict_server_json': conflictServerData == null
            ? null
            : jsonEncode(conflictServerData!.toMap()),
        'audit_history_json':
            jsonEncode(auditHistory.map((e) => e.toMap()).toList()),
      };

  factory FieldFormRecord.fromDbMap(Map<String, dynamic> map) {
    final conflictRaw = map['conflict_server_json'] as String?;
    final auditRaw =
        jsonDecode(map['audit_history_json'] as String) as List<dynamic>;

    return FieldFormRecord(
      clientUuid: map['client_uuid'] as String,
      projectId: map['project_id'] as String,
      propertyId: map['property_id'] as String,
      pointId: map['point_id'] as String,
      templateName: map['template_name'] as String,
      vegetationStage: map['vegetation_stage'] as String,
      survivalRatePercent: (map['survival_rate_percent'] as num).toDouble(),
      erosionStatus: map['erosion_status'] as String,
      invasiveSpeciesPresent: (map['invasive_species_present'] as int) == 1,
      maintenancePerformed: map['maintenance_performed'] as String,
      technicalNotes: map['technical_notes'] as String,
      isConfidential: (map['is_confidential'] as int) == 1,
      latitude: (map['latitude'] as num).toDouble(),
      longitude: (map['longitude'] as num).toDouble(),
      gpsAccuracyMeters: (map['gps_accuracy_meters'] as num).toDouble(),
      photoLocalPath: map['photo_local_path'] as String,
      photoCapturedAt: map['photo_captured_at'] as String,
      photoCaption: map['photo_caption'] as String,
      syncStatus: SyncStatus.fromString(map['sync_status'] as String),
      syncErrorMessage: map['sync_error_message'] as String?,
      version: (map['version'] as num).toInt(),
      authorId: map['author_id'] as String,
      authorName: map['author_name'] as String,
      authorRole: map['author_role'] as String,
      createdAt: map['created_at'] as String,
      syncedAt: map['synced_at'] as String?,
      conflictServerData: conflictRaw == null || conflictRaw.isEmpty
          ? null
          : ConflictServerPayload.fromMap(
              jsonDecode(conflictRaw) as Map<String, dynamic>,
            ),
      auditHistory: auditRaw
          .map((item) => AuditLogEntry.fromMap(item as Map<String, dynamic>))
          .toList(),
    );
  }
}
