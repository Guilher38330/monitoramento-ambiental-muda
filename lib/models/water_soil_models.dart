import 'dart:convert';
import 'project_models.dart';

/// Limites de Referência da Resolução CONAMA nº 357/2005 (Águas Doces — Classe 2)
/// para avaliação automatizada de conformidade hidrossedimentológica e microbiológica (AM-07).
class Conama357Limits {
  static const double phMin = 6.0;
  static const double phMax = 9.0;
  static const double maxTurbidityUnt = 100.0;
  static const double minDissolvedOxygenMgL = 5.0;
  static const double maxDboMgL = 5.0;
  static const double maxTotalPhosphorusMgL = 0.05; // Ambientes lóticos / intermediários Classe 2
  static const int maxThermotolerantColiformsNmp = 1000; // NMP/100mL

  static bool isPhCompliant(double ph) => ph >= phMin && ph <= phMax;
  static bool isTurbidityCompliant(double unt) => unt <= maxTurbidityUnt;
  static bool isOdCompliant(double od) => od >= minDissolvedOxygenMgL;
  static bool isDboCompliant(double dbo) => dbo <= maxDboMgL;
  static bool isPhosphorusCompliant(double p) => p <= maxTotalPhosphorusMgL;
  static bool isColiformsCompliant(int nmp) => nmp <= maxThermotolerantColiformsNmp;

  /// Retorna a lista de parâmetros violados segundo a Resolução CONAMA 357/2005 Classe 2.
  static List<String> evaluateViolations({
    required double ph,
    required double turbidityUnt,
    required double dissolvedOxygenMgL,
    required double dboMgL,
    required double totalPhosphorusMgL,
    required int thermotolerantColiformsNmp,
  }) {
    final violations = <String>[];
    if (!isPhCompliant(ph)) {
      violations.add('pH (${ph.toStringAsFixed(1)} fora da faixa 6,0–9,0)');
    }
    if (!isTurbidityCompliant(turbidityUnt)) {
      violations.add('Turbidez (${turbidityUnt.toStringAsFixed(1)} > 100 UNT)');
    }
    if (!isOdCompliant(dissolvedOxygenMgL)) {
      violations.add('OD (${dissolvedOxygenMgL.toStringAsFixed(1)} < 5,0 mg/L)');
    }
    if (!isDboCompliant(dboMgL)) {
      violations.add('DBO₅,₂₀ (${dboMgL.toStringAsFixed(1)} > 5,0 mg/L)');
    }
    if (!isPhosphorusCompliant(totalPhosphorusMgL)) {
      violations.add('Fósforo Total (${totalPhosphorusMgL.toStringAsFixed(3)} > 0,050 mg/L)');
    }
    if (!isColiformsCompliant(thermotolerantColiformsNmp)) {
      violations.add('Coliformes ($thermotolerantColiformsNmp > 1000 NMP/100mL)');
    }
    return violations;
  }
}

/// Registro e Laudo de Análise de Qualidade da Água por Ponto de Coleta (AM-07),
/// com comparativo histórico de campanhas e verificação automática CONAMA 357/2005.
class WaterQualityAnalysis {
  final String id;
  final String projectId;
  final String propertyId;
  final String pointId;
  final String reportCode;
  final String sampleDate; // Formato DD/MM/AAAA para exibição ou ISO
  final String campaignName; // Ex.: '1ª Campanha (Linha de Base Seca)', '2ª Campanha (Chuvosa)'
  final String laboratoryName;
  final double ph;
  final double turbidityUnt;
  final double dissolvedOxygenMgL;
  final double dboMgL;
  final double totalPhosphorusMgL;
  final int thermotolerantColiformsNmp;
  final double waterTemperatureC;
  final double flowRateLs; // Vazão em L/s
  final String technicalConclusion;
  final bool isConfidentialReport;
  final String confidentialLabNotes;
  final String responsibleAnalyst;
  final String createdAt;

  const WaterQualityAnalysis({
    required this.id,
    required this.projectId,
    required this.propertyId,
    required this.pointId,
    required this.reportCode,
    required this.sampleDate,
    required this.campaignName,
    required this.laboratoryName,
    required this.ph,
    required this.turbidityUnt,
    required this.dissolvedOxygenMgL,
    required this.dboMgL,
    required this.totalPhosphorusMgL,
    required this.thermotolerantColiformsNmp,
    required this.waterTemperatureC,
    required this.flowRateLs,
    required this.technicalConclusion,
    required this.isConfidentialReport,
    required this.confidentialLabNotes,
    required this.responsibleAnalyst,
    required this.createdAt,
  });

  /// Lista de violações detectadas automaticamente frente aos limites CONAMA 357/2005.
  List<String> get violations => Conama357Limits.evaluateViolations(
        ph: ph,
        turbidityUnt: turbidityUnt,
        dissolvedOxygenMgL: dissolvedOxygenMgL,
        dboMgL: dboMgL,
        totalPhosphorusMgL: totalPhosphorusMgL,
        thermotolerantColiformsNmp: thermotolerantColiformsNmp,
      );

  /// Indica se todos os parâmetros atendem integralmente à Classe 2 CONAMA 357/2005.
  bool get isConamaCompliant => violations.isEmpty;

  String get complianceStatusLabel => isConamaCompliant
      ? 'CONFORME CONAMA 357/2005'
      : 'ALERTA: ${violations.length} VIOLAÇÃO(ÕES) CONAMA';

  Map<String, dynamic> toDbMap() => {
        'id': id,
        'project_id': projectId,
        'property_id': propertyId,
        'point_id': pointId,
        'report_code': reportCode,
        'sample_date': sampleDate,
        'campaign_name': campaignName,
        'laboratory_name': laboratoryName,
        'ph': ph,
        'turbidity_unt': turbidityUnt,
        'dissolved_oxygen_mgl': dissolvedOxygenMgL,
        'dbo_mgl': dboMgL,
        'total_phosphorus_mgl': totalPhosphorusMgL,
        'thermotolerant_coliforms_nmp': thermotolerantColiformsNmp,
        'water_temperature_c': waterTemperatureC,
        'flow_rate_ls': flowRateLs,
        'technical_conclusion': technicalConclusion,
        'is_confidential_report': isConfidentialReport ? 1 : 0,
        'confidential_lab_notes': confidentialLabNotes,
        'responsible_analyst': responsibleAnalyst,
        'created_at': createdAt,
      };

  factory WaterQualityAnalysis.fromDbMap(Map<String, dynamic> map) =>
      WaterQualityAnalysis(
        id: map['id'] as String,
        projectId: map['project_id'] as String,
        propertyId: map['property_id'] as String,
        pointId: map['point_id'] as String,
        reportCode: map['report_code'] as String,
        sampleDate: map['sample_date'] as String,
        campaignName: map['campaign_name'] as String,
        laboratoryName: map['laboratory_name'] as String,
        ph: (map['ph'] as num).toDouble(),
        turbidityUnt: (map['turbidity_unt'] as num).toDouble(),
        dissolvedOxygenMgL: (map['dissolved_oxygen_mgl'] as num).toDouble(),
        dboMgL: (map['dbo_mgl'] as num).toDouble(),
        totalPhosphorusMgL: (map['total_phosphorus_mgl'] as num).toDouble(),
        thermotolerantColiformsNmp:
            (map['thermotolerant_coliforms_nmp'] as num).toInt(),
        waterTemperatureC: (map['water_temperature_c'] as num).toDouble(),
        flowRateLs: (map['flow_rate_ls'] as num).toDouble(),
        technicalConclusion: map['technical_conclusion'] as String,
        isConfidentialReport: (map['is_confidential_report'] as num) == 1,
        confidentialLabNotes: map['confidential_lab_notes'] as String,
        responsibleAnalyst: map['responsible_analyst'] as String,
        createdAt: map['created_at'] as String,
      );
}

/// Unidade Modelo de Conservação do Solo (AM-10):
/// Registra unidades demonstrativas, práticas conservacionistas adotadas e indicadores
/// quantitativos de cobertura vegetal (%) e abatimento de erosão hídrica (t/ha/ano — USLE).
class SoilConservationUnit {
  final String id;
  final String projectId;
  final String propertyId;
  final String pointId;
  final String code;
  final String name;
  final double areaHa;
  final String soilClass;
  final double slopePercent; // Declividade média (%)
  final List<String> adoptedPractices; // Ex.: ['Plantio Direto na Palha', 'Terraceamento em Nível', ...]
  final double vegetalCoverPercent; // Cobertura vegetal do solo (%)
  final double baselineErosionTonHaYear; // Perda de solo antes do projeto (t/ha/ano)
  final double currentErosionTonHaYear; // Perda de solo atual (t/ha/ano)
  final double erosionAbatementTonHaYear; // Abatimento de erosão (t/ha/ano)
  final int infiltrationBasinsCount; // Nº de bacias de contenção / barraginhas
  final String conservationLevel; // 'Excelente', 'Adequado', 'Em Recuperação', 'Crítico'
  final String lastEvaluationDate;
  final String technicalNotes;
  final String confidentialOwnerAgreement; // Sigiloso (AM-01)
  final String responsibleTechnician;

  const SoilConservationUnit({
    required this.id,
    required this.projectId,
    required this.propertyId,
    required this.pointId,
    required this.code,
    required this.name,
    required this.areaHa,
    required this.soilClass,
    required this.slopePercent,
    required this.adoptedPractices,
    required this.vegetalCoverPercent,
    required this.baselineErosionTonHaYear,
    required this.currentErosionTonHaYear,
    required this.erosionAbatementTonHaYear,
    required this.infiltrationBasinsCount,
    required this.conservationLevel,
    required this.lastEvaluationDate,
    required this.technicalNotes,
    required this.confidentialOwnerAgreement,
    required this.responsibleTechnician,
  });

  /// Percentual de redução da perda de solo em relação à linha de base (USLE).
  double get erosionReductionPercent {
    if (baselineErosionTonHaYear <= 0) return 0.0;
    final pct = (erosionAbatementTonHaYear / baselineErosionTonHaYear) * 100.0;
    return pct.clamp(0.0, 100.0);
  }

  /// Catálogo padronizado de práticas conservacionistas (AM-10).
  static const List<String> standardPractices = [
    'Plantio Direto na Palha',
    'Terraceamento em Nível',
    'Adubação Verde e Cobertura Morta',
    'Cercamento Integral de APP',
    'Curvas de Nível e Bacias de Contenção (Barraginhas)',
    'Sistema Agroflorestal (SAF) Sucessional',
    'Adequação Ambiental de Estradas Vicinais',
  ];

  Map<String, dynamic> toDbMap() => {
        'id': id,
        'project_id': projectId,
        'property_id': propertyId,
        'point_id': pointId,
        'code': code,
        'name': name,
        'area_ha': areaHa,
        'soil_class': soilClass,
        'slope_percent': slopePercent,
        'adopted_practices_json': jsonEncode(adoptedPractices),
        'vegetal_cover_percent': vegetalCoverPercent,
        'baseline_erosion_ton_ha_year': baselineErosionTonHaYear,
        'current_erosion_ton_ha_year': currentErosionTonHaYear,
        'erosion_abatement_ton_ha_year': erosionAbatementTonHaYear,
        'infiltration_basins_count': infiltrationBasinsCount,
        'conservation_level': conservationLevel,
        'last_evaluation_date': lastEvaluationDate,
        'technical_notes': technicalNotes,
        'confidential_owner_agreement': confidentialOwnerAgreement,
        'responsible_technician': responsibleTechnician,
      };

  factory SoilConservationUnit.fromDbMap(Map<String, dynamic> map) {
    final practicesRaw =
        jsonDecode(map['adopted_practices_json'] as String) as List<dynamic>;
    return SoilConservationUnit(
      id: map['id'] as String,
      projectId: map['project_id'] as String,
      propertyId: map['property_id'] as String,
      pointId: map['point_id'] as String,
      code: map['code'] as String,
      name: map['name'] as String,
      areaHa: (map['area_ha'] as num).toDouble(),
      soilClass: map['soil_class'] as String,
      slopePercent: (map['slope_percent'] as num).toDouble(),
      adoptedPractices: practicesRaw.map((e) => e.toString()).toList(),
      vegetalCoverPercent: (map['vegetal_cover_percent'] as num).toDouble(),
      baselineErosionTonHaYear:
          (map['baseline_erosion_ton_ha_year'] as num).toDouble(),
      currentErosionTonHaYear:
          (map['current_erosion_ton_ha_year'] as num).toDouble(),
      erosionAbatementTonHaYear:
          (map['erosion_abatement_ton_ha_year'] as num).toDouble(),
      infiltrationBasinsCount: (map['infiltration_basins_count'] as num).toInt(),
      conservationLevel: map['conservation_level'] as String,
      lastEvaluationDate: map['last_evaluation_date'] as String,
      technicalNotes: map['technical_notes'] as String,
      confidentialOwnerAgreement: map['confidential_owner_agreement'] as String,
      responsibleTechnician: map['responsible_technician'] as String,
    );
  }
}

/// Camada KML Processada e Croqui Técnico da Propriedade/Microbacia (AM-06).
class ProcessedKmlOverlay {
  final String id;
  final String projectId;
  final String propertyId;
  final String kmlFileName;
  final String title;
  final String layerCategory; // 'Croqui Técnico de Talhões', 'Rede Hidrográfica KML', 'Zonas de Recarga PSA'
  final String datumcrs; // Ex.: 'SIRGAS 2000 / UTM 22S (EPSG:31982)'
  final String processedAt;
  final double mappedAreaHa;
  final String technicalCroquiSummary;
  final String rawKmlSnippet;
  final List<GeoCoordinate> overlayPolygon;
  final List<GeoCoordinate> hydrographyPolyline;

  const ProcessedKmlOverlay({
    required this.id,
    required this.projectId,
    required this.propertyId,
    required this.kmlFileName,
    required this.title,
    required this.layerCategory,
    required this.datumcrs,
    required this.processedAt,
    required this.mappedAreaHa,
    required this.technicalCroquiSummary,
    required this.rawKmlSnippet,
    required this.overlayPolygon,
    required this.hydrographyPolyline,
  });
}
