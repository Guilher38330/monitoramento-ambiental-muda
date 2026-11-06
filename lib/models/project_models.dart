import 'dart:convert';

/// Coordenada geográfica simples para centróides e polígonos de áreas (preparado para o Mapa da Fase 3).
class GeoCoordinate {
  final double latitude;
  final double longitude;

  const GeoCoordinate({
    required this.latitude,
    required this.longitude,
  });

  Map<String, dynamic> toMap() => {
        'lat': latitude,
        'lng': longitude,
      };

  factory GeoCoordinate.fromMap(Map<String, dynamic> map) => GeoCoordinate(
        latitude: (map['lat'] as num).toDouble(),
        longitude: (map['lng'] as num).toDouble(),
      );
}

/// Etapa e cronograma de um projeto ambiental (AM-02).
class ProjectStage {
  final String id;
  final String title;
  final String description;
  final String startDate;
  final String endDate;
  final String status; // 'Concluída', 'Em Andamento', 'Planejada'
  final double progressPercent;
  final String responsibleTeam;
  final String targetDeliverable;

  const ProjectStage({
    required this.id,
    required this.title,
    required this.description,
    required this.startDate,
    required this.endDate,
    required this.status,
    required this.progressPercent,
    required this.responsibleTeam,
    required this.targetDeliverable,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'title': title,
        'description': description,
        'startDate': startDate,
        'endDate': endDate,
        'status': status,
        'progressPercent': progressPercent,
        'responsibleTeam': responsibleTeam,
        'targetDeliverable': targetDeliverable,
      };

  factory ProjectStage.fromMap(Map<String, dynamic> map) => ProjectStage(
        id: map['id'] as String,
        title: map['title'] as String,
        description: map['description'] as String,
        startDate: map['startDate'] as String,
        endDate: map['endDate'] as String,
        status: map['status'] as String,
        progressPercent: (map['progressPercent'] as num).toDouble(),
        responsibleTeam: map['responsibleTeam'] as String,
        targetDeliverable: map['targetDeliverable'] as String,
      );
}

/// Documento autorizado vinculado ao projeto (AM-02), com controle de sigilo (AM-01).
class AuthorizedDocument {
  final String id;
  final String code;
  final String title;
  final String category; // 'Licença Ambiental', 'Termo de Adesão PSA', 'Plano Técnico', 'Laudo Hidrológico'
  final String issueDate;
  final String version;
  final String fileSize;
  final String summary;
  final bool isConfidential;
  final String confidentialContent;

  const AuthorizedDocument({
    required this.id,
    required this.code,
    required this.title,
    required this.category,
    required this.issueDate,
    required this.version,
    required this.fileSize,
    required this.summary,
    required this.isConfidential,
    required this.confidentialContent,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'code': code,
        'title': title,
        'category': category,
        'issueDate': issueDate,
        'version': version,
        'fileSize': fileSize,
        'summary': summary,
        'isConfidential': isConfidential,
        'confidentialContent': confidentialContent,
      };

  factory AuthorizedDocument.fromMap(Map<String, dynamic> map) =>
      AuthorizedDocument(
        id: map['id'] as String,
        code: map['code'] as String,
        title: map['title'] as String,
        category: map['category'] as String,
        issueDate: map['issueDate'] as String,
        version: map['version'] as String,
        fileSize: map['fileSize'] as String,
        summary: map['summary'] as String,
        isConfidential: map['isConfidential'] as bool,
        confidentialContent: map['confidentialContent'] as String,
      );
}

/// Projeto Ambiental dos programas Muda ou PSA (AM-02).
class EnvironmentalProject {
  final String id;
  final String code;
  final String name;
  final String programType; // 'MUDA' ou 'PSA'
  final String watershed; // Bacia hidrográfica
  final String municipalityHub;
  final String period;
  final String status;
  final double overallProgress;
  final double totalTargetAreaHa;
  final int targetSeedlingsCount;
  final String publicSummary;
  final String partnerCompany;

  // Campos sigilosos (visíveis apenas para Administrador e Equipe Técnica - AM-01)
  final double confidentialTotalBudget;
  final String confidentialContractCode;
  final String confidentialTechnicalNotes;

  final List<ProjectStage> stages;
  final List<AuthorizedDocument> documents;

  const EnvironmentalProject({
    required this.id,
    required this.code,
    required this.name,
    required this.programType,
    required this.watershed,
    required this.municipalityHub,
    required this.period,
    required this.status,
    required this.overallProgress,
    required this.totalTargetAreaHa,
    required this.targetSeedlingsCount,
    required this.publicSummary,
    required this.partnerCompany,
    required this.confidentialTotalBudget,
    required this.confidentialContractCode,
    required this.confidentialTechnicalNotes,
    required this.stages,
    required this.documents,
  });

  bool get isMuda => programType.toUpperCase() == 'MUDA';
  bool get isPsa => programType.toUpperCase() == 'PSA';

  Map<String, dynamic> toDbMap() => {
        'id': id,
        'code': code,
        'name': name,
        'program_type': programType,
        'watershed': watershed,
        'municipality_hub': municipalityHub,
        'period': period,
        'status': status,
        'overall_progress': overallProgress,
        'total_target_area_ha': totalTargetAreaHa,
        'target_seedlings_count': targetSeedlingsCount,
        'public_summary': publicSummary,
        'partner_company': partnerCompany,
        'confidential_total_budget': confidentialTotalBudget,
        'confidential_contract_code': confidentialContractCode,
        'confidential_technical_notes': confidentialTechnicalNotes,
        'stages_json': jsonEncode(stages.map((s) => s.toMap()).toList()),
        'documents_json': jsonEncode(documents.map((d) => d.toMap()).toList()),
      };

  factory EnvironmentalProject.fromDbMap(Map<String, dynamic> map) {
    final stagesRaw =
        jsonDecode(map['stages_json'] as String) as List<dynamic>;
    final docsRaw =
        jsonDecode(map['documents_json'] as String) as List<dynamic>;

    return EnvironmentalProject(
      id: map['id'] as String,
      code: map['code'] as String,
      name: map['name'] as String,
      programType: map['program_type'] as String,
      watershed: map['watershed'] as String,
      municipalityHub: map['municipality_hub'] as String,
      period: map['period'] as String,
      status: map['status'] as String,
      overallProgress: (map['overall_progress'] as num).toDouble(),
      totalTargetAreaHa: (map['total_target_area_ha'] as num).toDouble(),
      targetSeedlingsCount: (map['target_seedlings_count'] as num).toInt(),
      publicSummary: map['public_summary'] as String,
      partnerCompany: map['partner_company'] as String,
      confidentialTotalBudget:
          (map['confidential_total_budget'] as num).toDouble(),
      confidentialContractCode: map['confidential_contract_code'] as String,
      confidentialTechnicalNotes: map['confidential_technical_notes'] as String,
      stages: stagesRaw
          .map((item) => ProjectStage.fromMap(item as Map<String, dynamic>))
          .toList(),
      documents: docsRaw
          .map((item) =>
              AuthorizedDocument.fromMap(item as Map<String, dynamic>))
          .toList(),
    );
  }
}

/// Propriedade Rural e Áreas Monitoradas (AM-02) com dados sigilosos protegidos (AM-01).
class RuralProperty {
  final String id;
  final String projectId;
  final String code;
  final String name;
  final String municipality;
  final double totalAreaHa;
  final double restorationAreaHa;
  final String areaDescription;
  final String mainSoilType;
  final String conservationStatus;
  final double centerLatitude;
  final double centerLongitude;
  final List<GeoCoordinate> polygonCoordinates;

  // Dados sigilosos (protegidos por LGPD e sigilo contratual para o perfil Empresa - AM-01)
  final String ownerName;
  final String ownerCpf;
  final String carRegistryCode;
  final double psaMonthlyValue;
  final String bankAccountSummary;

  const RuralProperty({
    required this.id,
    required this.projectId,
    required this.code,
    required this.name,
    required this.municipality,
    required this.totalAreaHa,
    required this.restorationAreaHa,
    required this.areaDescription,
    required this.mainSoilType,
    required this.conservationStatus,
    required this.centerLatitude,
    required this.centerLongitude,
    required this.polygonCoordinates,
    required this.ownerName,
    required this.ownerCpf,
    required this.carRegistryCode,
    required this.psaMonthlyValue,
    required this.bankAccountSummary,
  });

  Map<String, dynamic> toDbMap() => {
        'id': id,
        'project_id': projectId,
        'code': code,
        'name': name,
        'municipality': municipality,
        'total_area_ha': totalAreaHa,
        'restoration_area_ha': restorationAreaHa,
        'area_description': areaDescription,
        'main_soil_type': mainSoilType,
        'conservation_status': conservationStatus,
        'center_latitude': centerLatitude,
        'center_longitude': centerLongitude,
        'polygon_json':
            jsonEncode(polygonCoordinates.map((c) => c.toMap()).toList()),
        'owner_name': ownerName,
        'owner_cpf': ownerCpf,
        'car_registry_code': carRegistryCode,
        'psa_monthly_value': psaMonthlyValue,
        'bank_account_summary': bankAccountSummary,
      };

  factory RuralProperty.fromDbMap(Map<String, dynamic> map) {
    final polyRaw = jsonDecode(map['polygon_json'] as String) as List<dynamic>;
    return RuralProperty(
      id: map['id'] as String,
      projectId: map['project_id'] as String,
      code: map['code'] as String,
      name: map['name'] as String,
      municipality: map['municipality'] as String,
      totalAreaHa: (map['total_area_ha'] as num).toDouble(),
      restorationAreaHa: (map['restoration_area_ha'] as num).toDouble(),
      areaDescription: map['area_description'] as String,
      mainSoilType: map['main_soil_type'] as String,
      conservationStatus: map['conservation_status'] as String,
      centerLatitude: (map['center_latitude'] as num).toDouble(),
      centerLongitude: (map['center_longitude'] as num).toDouble(),
      polygonCoordinates: polyRaw
          .map((item) => GeoCoordinate.fromMap(item as Map<String, dynamic>))
          .toList(),
      ownerName: map['owner_name'] as String,
      ownerCpf: map['owner_cpf'] as String,
      carRegistryCode: map['car_registry_code'] as String,
      psaMonthlyValue: (map['psa_monthly_value'] as num).toDouble(),
      bankAccountSummary: map['bank_account_summary'] as String,
    );
  }
}

/// Ponto de Coleta Georreferenciado vinculado a uma propriedade e projeto (AM-02 / AM-05 / AM-06).
class CollectionPoint {
  final String id;
  final String projectId;
  final String propertyId;
  final String code;
  final String name;
  final String pointType; // 'Nascente Hidrológica', 'Parcela de Mudas', 'Conservação de Solo', 'Erosão/APP'
  final double latitude;
  final double longitude;
  final double altitudeMeters;
  final String referenceAreaName;
  final String lastInspectionDate;
  final String monitoringStatus;

  const CollectionPoint({
    required this.id,
    required this.projectId,
    required this.propertyId,
    required this.code,
    required this.name,
    required this.pointType,
    required this.latitude,
    required this.longitude,
    required this.altitudeMeters,
    required this.referenceAreaName,
    required this.lastInspectionDate,
    required this.monitoringStatus,
  });

  Map<String, dynamic> toDbMap() => {
        'id': id,
        'project_id': projectId,
        'property_id': propertyId,
        'code': code,
        'name': name,
        'point_type': pointType,
        'latitude': latitude,
        'longitude': longitude,
        'altitude_meters': altitudeMeters,
        'reference_area_name': referenceAreaName,
        'last_inspection_date': lastInspectionDate,
        'monitoring_status': monitoringStatus,
      };

  factory CollectionPoint.fromDbMap(Map<String, dynamic> map) => CollectionPoint(
        id: map['id'] as String,
        projectId: map['project_id'] as String,
        propertyId: map['property_id'] as String,
        code: map['code'] as String,
        name: map['name'] as String,
        pointType: map['point_type'] as String,
        latitude: (map['latitude'] as num).toDouble(),
        longitude: (map['longitude'] as num).toDouble(),
        altitudeMeters: (map['altitude_meters'] as num).toDouble(),
        referenceAreaName: map['reference_area_name'] as String,
        lastInspectionDate: map['last_inspection_date'] as String,
        monitoringStatus: map['monitoring_status'] as String,
      );
}
