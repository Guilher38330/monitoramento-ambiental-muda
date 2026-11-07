import 'dart:convert';
import 'dart:typed_data';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import '../models/field_form_record.dart';
import '../models/project_models.dart';
import '../models/user_profile.dart';
import '../state/app_state.dart';

/// Conjunto consolidado de Indicadores de Monitoramento (KPIs) calculados
/// para o Dashboard de Indicadores (AM-08) e para os Relatórios PDF / CSV (AM-09).
class DashboardKpiSummary {
  final String programFilter; // 'TODOS', 'MUDA', 'PSA'
  final int projectsCount;
  final int propertiesCount;
  final int collectionPointsCount;
  final double totalMonitoredAreaHa;
  final double totalRestorationAreaHa;
  final int totalTargetSeedlings;
  final double averageSurvivalRatePercent;
  final double averageScheduleProgressPercent;
  final int waterAnalysesCount;
  final int waterCompliantCount;
  final double conamaCompliancePercent;
  final int soilUnitsCount;
  final double totalSoilConservationAreaHa;
  final double totalErosionAbatementTonYear;
  final double averageSoilVegetalCoverPercent;
  final int fieldFormsTotalCount;
  final int fieldFormsSyncedCount;
  final int fieldFormsPendingCount;

  const DashboardKpiSummary({
    required this.programFilter,
    required this.projectsCount,
    required this.propertiesCount,
    required this.collectionPointsCount,
    required this.totalMonitoredAreaHa,
    required this.totalRestorationAreaHa,
    required this.totalTargetSeedlings,
    required this.averageSurvivalRatePercent,
    required this.averageScheduleProgressPercent,
    required this.waterAnalysesCount,
    required this.waterCompliantCount,
    required this.conamaCompliancePercent,
    required this.soilUnitsCount,
    required this.totalSoilConservationAreaHa,
    required this.totalErosionAbatementTonYear,
    required this.averageSoilVegetalCoverPercent,
    required this.fieldFormsTotalCount,
    required this.fieldFormsSyncedCount,
    required this.fieldFormsPendingCount,
  });
}

/// Serviço de Cálculo de Indicadores Consolidados (AM-08) e Geração / Exportação
/// de Relatórios Técnicos em PDF e Planilhas Excel/CSV direto do celular (AM-09 + 3º Critério de Aceite).
/// Respeita rigorosamente o controle de sigilo por perfil (AM-01).
class ReportExportService {
  const ReportExportService._();

  /// Filtra os projetos pelo seletor ('TODOS', 'MUDA', 'PSA').
  static List<EnvironmentalProject> filterProjects(
    AppState appState,
    String programFilter,
  ) {
    final normalized = programFilter.trim().toUpperCase();
    if (normalized == 'TODOS' || normalized.isEmpty) {
      return appState.projects;
    }
    return appState.projects
        .where((p) => p.programType.toUpperCase() == normalized)
        .toList();
  }

  /// Calcula todos os KPIs consolidados para o filtro de programa selecionado ('TODOS', 'MUDA', 'PSA').
  static DashboardKpiSummary calculateKpis({
    required AppState appState,
    String programFilter = 'TODOS',
  }) {
    final projects = filterProjects(appState, programFilter);
    final projectIds = projects.map((p) => p.id).toSet();

    final properties = appState.properties
        .where((prop) => projectIds.contains(prop.projectId))
        .toList();
    final points = appState.collectionPoints
        .where((pt) => projectIds.contains(pt.projectId))
        .toList();
    final forms = appState.fieldForms
        .where((f) => projectIds.contains(f.projectId))
        .toList();
    final waterList = appState.waterAnalyses
        .where((w) => projectIds.contains(w.projectId))
        .toList();
    final soilList = appState.soilUnits
        .where((s) => projectIds.contains(s.projectId))
        .toList();

    final totalMonitoredHa = properties.fold<double>(
      0.0,
      (sum, prop) => sum + prop.totalAreaHa,
    );
    final totalRestoredHa = properties.fold<double>(
      0.0,
      (sum, prop) => sum + prop.restorationAreaHa,
    );
    final totalSeedlings = projects.fold<int>(
      0,
      (sum, proj) => sum + proj.targetSeedlingsCount,
    );

    final avgSurvival = forms.isEmpty
        ? 0.0
        : forms.fold<double>(0.0, (sum, f) => sum + f.survivalRatePercent) /
            forms.length;

    final avgProgress = projects.isEmpty
        ? 0.0
        : projects.fold<double>(0.0, (sum, p) => sum + p.overallProgress) /
            projects.length;

    final waterCompliant =
        waterList.where((w) => w.isConamaCompliant).length;
    final conamaPct = waterList.isEmpty
        ? 0.0
        : (waterCompliant / waterList.length) * 100.0;

    final soilAreaHa = soilList.fold<double>(
      0.0,
      (sum, s) => sum + s.areaHa,
    );
    final totalAbatementTonYear = soilList.fold<double>(
      0.0,
      (sum, s) => sum + (s.erosionAbatementTonHaYear * s.areaHa),
    );
    final avgCover = soilList.isEmpty
        ? 0.0
        : soilList.fold<double>(0.0, (sum, s) => sum + s.vegetalCoverPercent) /
            soilList.length;

    final syncedForms =
        forms.where((f) => f.syncStatus == SyncStatus.synced).length;
    final pendingForms = forms.where((f) => f.isPendingOrFailed).length;

    return DashboardKpiSummary(
      programFilter: programFilter.toUpperCase(),
      projectsCount: projects.length,
      propertiesCount: properties.length,
      collectionPointsCount: points.length,
      totalMonitoredAreaHa: totalMonitoredHa,
      totalRestorationAreaHa: totalRestoredHa,
      totalTargetSeedlings: totalSeedlings,
      averageSurvivalRatePercent: avgSurvival,
      averageScheduleProgressPercent: avgProgress,
      waterAnalysesCount: waterList.length,
      waterCompliantCount: waterCompliant,
      conamaCompliancePercent: conamaPct,
      soilUnitsCount: soilList.length,
      totalSoilConservationAreaHa: soilAreaHa,
      totalErosionAbatementTonYear: totalAbatementTonYear,
      averageSoilVegetalCoverPercent: avgCover,
      fieldFormsTotalCount: forms.length,
      fieldFormsSyncedCount: syncedForms,
      fieldFormsPendingCount: pendingForms,
    );
  }

  /// Gera os bytes binários de um Relatório Técnico Consolidado em PDF (AM-09)
  /// utilizando o pacote `pdf`, respeitando rigorosamente o controle de sigilo AM-01
  /// quando o usuário ativo for `Empresa Contratante`.
  static Future<Uint8List> generateTechnicalReportPdfBytes({
    required AppState appState,
    String programFilter = 'TODOS',
  }) async {
    final user = appState.currentUser ?? AppUser.demoUsers.last;
    final canViewConfidential = user.canViewConfidentialData;
    final kpis = calculateKpis(
      appState: appState,
      programFilter: programFilter,
    );

    final projects = filterProjects(appState, programFilter);
    final projectIds = projects.map((p) => p.id).toSet();
    final properties = appState.properties
        .where((prop) => projectIds.contains(prop.projectId))
        .toList();
    final waterAnalyses = appState.waterAnalyses
        .where((w) => projectIds.contains(w.projectId))
        .toList();
    final soilUnits = appState.soilUnits
        .where((s) => projectIds.contains(s.projectId))
        .toList();
    final fieldForms = appState.fieldForms
        .where((f) => projectIds.contains(f.projectId))
        .toList();

    final doc = pw.Document(
      title: 'Relatorio Tecnico Monitoramento Muda e PSA ($programFilter)',
      author: _sanitizePdfText('${user.name} - ${user.role.label}'),
      subject:
          'Monitoramento Ambiental Consolidado (AM-08 / AM-09 / CONAMA 357/2005)',
      creator: 'EcoMonitor Muda & PSA Mobile App',
    );

    final nowIso = DateTime.now().toUtc().toIso8601String();
    final primaryGreen = PdfColor.fromInt(0xFF1B5E20);
    final lightGreenBg = PdfColor.fromInt(0xFFE8F5E9);
    final headerTextWhite = PdfColors.white;
    final borderGrey = PdfColor.fromInt(0xFFB0BEC5);

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(28),
        header: (context) => pw.Container(
          padding: const pw.EdgeInsets.all(10),
          margin: const pw.EdgeInsets.only(bottom: 12),
          decoration: pw.BoxDecoration(
            color: primaryGreen,
            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
          ),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'RELATORIO TECNICO DE MONITORAMENTO AMBIENTAL - MUDA & PSA',
                    style: pw.TextStyle(
                      color: headerTextWhite,
                      fontSize: 11,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.SizedBox(height: 2),
                  pw.Text(
                    'Escopo: Programa $programFilter | Emitido em: ${nowIso.substring(0, 19).replaceAll("T", " ")} UTC',
                    style: const pw.TextStyle(
                      color: PdfColors.white,
                      fontSize: 8.5,
                    ),
                  ),
                ],
              ),
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 4,
                ),
                decoration: pw.BoxDecoration(
                  color: canViewConfidential
                      ? PdfColor.fromInt(0xFF2E7D32)
                      : PdfColor.fromInt(0xFFEF6C00),
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                ),
                child: pw.Text(
                  canViewConfidential
                      ? _sanitizePdfText(
                          'PERFIL: ${user.role.shortBadge} (SIGILO AUTORIZADO)',
                        )
                      : 'PERFIL: EMPRESA (SIGILO PROTEGIDO AM-01)',
                  style: pw.TextStyle(
                    color: headerTextWhite,
                    fontSize: 8,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
        footer: (context) => pw.Container(
          margin: const pw.EdgeInsets.only(top: 10),
          padding: const pw.EdgeInsets.only(top: 6),
          decoration: pw.BoxDecoration(
            border: pw.Border(top: pw.BorderSide(color: borderGrey, width: 0.5)),
          ),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                _sanitizePdfText(
                  'Responsavel pela emissao: ${user.name} (${user.registrationCode}) - ${user.role.label}',
                ),
                style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
              ),
              pw.Text(
                'Pagina ${context.pageNumber} de ${context.pagesCount}',
                style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
              ),
            ],
          ),
        ),
        build: (context) => [
          // 1. Quadro de KPIs Consolidados (AM-08)
          pw.Text(
            '1. INDICADORES CONSOLIDADOS DE DESEMPENHO AMBIENTAL (AM-08)',
            style: pw.TextStyle(
              fontSize: 11,
              fontWeight: pw.FontWeight.bold,
              color: primaryGreen,
            ),
          ),
          pw.SizedBox(height: 6),
          pw.Container(
            padding: const pw.EdgeInsets.all(10),
            decoration: pw.BoxDecoration(
              color: lightGreenBg,
              border: pw.Border.all(color: borderGrey),
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    _buildPdfKpiBox(
                      'Area em Restauracao',
                      '${kpis.totalRestorationAreaHa.toStringAsFixed(1)} ha',
                      'Total monitorado: ${kpis.totalMonitoredAreaHa.toStringAsFixed(1)} ha',
                    ),
                    _buildPdfKpiBox(
                      'Meta de Mudas / Plantio',
                      '${kpis.totalTargetSeedlings} mudas',
                      'Sobrevivencia media: ${kpis.averageSurvivalRatePercent.toStringAsFixed(1)}%',
                    ),
                    _buildPdfKpiBox(
                      'Conformidade CONAMA 357',
                      '${kpis.conamaCompliancePercent.toStringAsFixed(1)}%',
                      '${kpis.waterCompliantCount}/${kpis.waterAnalysesCount} laudos Classe 2',
                    ),
                    _buildPdfKpiBox(
                      'Conservacao do Solo (USLE)',
                      '${kpis.totalSoilConservationAreaHa.toStringAsFixed(1)} ha',
                      'Abatimento: ${kpis.totalErosionAbatementTonYear.toStringAsFixed(0)} t/ano',
                    ),
                  ],
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 14),

          // 2. Projetos, Cronogramas e Controle de Sigilo Financeiro (AM-01 / AM-02)
          pw.Text(
            '2. PROJETOS MONITORADOS, CRONOGRAMA DE ETAPAS E SIGILO (AM-01 / AM-02)',
            style: pw.TextStyle(
              fontSize: 11,
              fontWeight: pw.FontWeight.bold,
              color: primaryGreen,
            ),
          ),
          pw.SizedBox(height: 6),
          ...projects.map((proj) {
            final budgetText = user.formatConfidentialCurrency(
              proj.confidentialTotalBudget,
            );
            final contractText = canViewConfidential
                ? proj.confidentialContractCode
                : 'RESTRITO AO PERFIL ${user.role.shortBadge} (AM-01)';

            return pw.Container(
              margin: const pw.EdgeInsets.only(bottom: 10),
              padding: const pw.EdgeInsets.all(8),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: borderGrey),
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    '[${proj.programType}] ${proj.code} - ${_sanitizePdfText(proj.name)}',
                    style: pw.TextStyle(
                      fontSize: 9.5,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.SizedBox(height: 3),
                  pw.Text(
                    'Bacia: ${_sanitizePdfText(proj.watershed)} | Polo: ${_sanitizePdfText(proj.municipalityHub)} | Avanco Fisico: ${proj.overallProgress.toStringAsFixed(1)}%',
                    style: const pw.TextStyle(fontSize: 8.5),
                  ),
                  pw.Text(
                    'Orcamento / Repasse: ${_sanitizePdfText(budgetText)} | Contrato: ${_sanitizePdfText(contractText)}',
                    style: pw.TextStyle(
                      fontSize: 8.5,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.SizedBox(height: 4),
                  pw.TableHelper.fromTextArray(
                    headerStyle: pw.TextStyle(
                      fontSize: 7.5,
                      fontWeight: pw.FontWeight.bold,
                    ),
                    cellStyle: const pw.TextStyle(fontSize: 7.5),
                    headers: const ['Etapa', 'Periodo', 'Status', 'Avanco (%)'],
                    data: proj.stages
                        .map(
                          (s) => [
                            _sanitizePdfText(s.title),
                            '${s.startDate} a ${s.endDate}',
                            _sanitizePdfText(s.status),
                            '${s.progressPercent.toStringAsFixed(0)}%',
                          ],
                        )
                        .toList(),
                  ),
                ],
              ),
            );
          }),
          pw.SizedBox(height: 10),

          // 3. Propriedades Rurais e Proteção LGPD / Sigilo Contratual (AM-01 / AM-02)
          pw.Text(
            '3. PROPRIEDADES RURAIS E PROTECAO DE DADOS SIGILOSOS (AM-01 / LGPD)',
            style: pw.TextStyle(
              fontSize: 11,
              fontWeight: pw.FontWeight.bold,
              color: primaryGreen,
            ),
          ),
          pw.SizedBox(height: 6),
          pw.TableHelper.fromTextArray(
            headerStyle: pw.TextStyle(
              fontSize: 7.5,
              fontWeight: pw.FontWeight.bold,
            ),
            cellStyle: const pw.TextStyle(fontSize: 7.5),
            headers: const [
              'Codigo',
              'Propriedade / Municipio',
              'Restauracao (ha)',
              'Proprietario / CPF (AM-01)',
              'Registro CAR / Repasse PSA',
            ],
            data: properties.map((prop) {
              final ownerCpfDisplay = canViewConfidential
                  ? '${_sanitizePdfText(prop.ownerName)} (${prop.ownerCpf})'
                  : 'RESTRITO LGPD / SIGILO (AM-01)';
              final carPsaDisplay = canViewConfidential
                  ? '${prop.carRegistryCode} | R\$ ${prop.psaMonthlyValue.toStringAsFixed(2)}/mes'
                  : 'SIGILO CONTRATUAL (AM-01)';
              return [
                prop.code,
                '${_sanitizePdfText(prop.name)} (${_sanitizePdfText(prop.municipality)})',
                '${prop.restorationAreaHa.toStringAsFixed(1)} ha',
                ownerCpfDisplay,
                carPsaDisplay,
              ];
            }).toList(),
          ),
          pw.SizedBox(height: 12),

          // 4. Análises de Qualidade da Água — Resolução CONAMA 357/2005 Classe 2 (AM-07)
          pw.Text(
            '4. ANALISES DE QUALIDADE DA AGUA - PADRAO CONAMA 357/2005 CLASSE 2 (AM-07)',
            style: pw.TextStyle(
              fontSize: 11,
              fontWeight: pw.FontWeight.bold,
              color: primaryGreen,
            ),
          ),
          pw.SizedBox(height: 6),
          pw.TableHelper.fromTextArray(
            headerStyle: pw.TextStyle(
              fontSize: 6.8,
              fontWeight: pw.FontWeight.bold,
            ),
            cellStyle: const pw.TextStyle(fontSize: 6.8),
            headers: const [
              'Laudo / Data',
              'Ponto',
              'pH',
              'Turb.',
              'OD',
              'DBO',
              'P Total',
              'Colif.',
              'Status CONAMA',
              'Notas Lab (AM-01)',
            ],
            data: waterAnalyses.map((w) {
              final labNoteDisplay = (!w.isConfidentialReport || canViewConfidential)
                  ? _sanitizePdfText(w.confidentialLabNotes)
                  : 'RESTRITO (AM-01)';
              return [
                '${_sanitizePdfText(w.reportCode)} (${_sanitizePdfText(w.sampleDate)})',
                _sanitizePdfText(w.pointId.toUpperCase()),
                w.ph.toStringAsFixed(1),
                w.turbidityUnt.toStringAsFixed(1),
                w.dissolvedOxygenMgL.toStringAsFixed(1),
                w.dboMgL.toStringAsFixed(1),
                w.totalPhosphorusMgL.toStringAsFixed(3),
                '${w.thermotolerantColiformsNmp}',
                w.isConamaCompliant
                    ? 'CONFORME'
                    : 'VIOLACAO (${w.violations.length})',
                labNoteDisplay,
              ];
            }).toList(),
          ),
          pw.SizedBox(height: 12),

          // 5. Unidades Modelo de Conservação do Solo (AM-10)
          pw.Text(
            '5. UNIDADES MODELO DE CONSERVACAO DO SOLO E ABATIMENTO DE EROSAO (AM-10)',
            style: pw.TextStyle(
              fontSize: 11,
              fontWeight: pw.FontWeight.bold,
              color: primaryGreen,
            ),
          ),
          pw.SizedBox(height: 6),
          pw.TableHelper.fromTextArray(
            headerStyle: pw.TextStyle(
              fontSize: 7.5,
              fontWeight: pw.FontWeight.bold,
            ),
            cellStyle: const pw.TextStyle(fontSize: 7.5),
            headers: const [
              'Codigo',
              'Unidade Modelo',
              'Area (ha)',
              'Cobertura (%)',
              'Abatimento USLE',
              'Termo Propriet. (AM-01)',
            ],
            data: soilUnits.map((s) {
              final agreementDisplay = canViewConfidential
                  ? _sanitizePdfText(s.confidentialOwnerAgreement)
                  : 'ACORDO RESTRITO (AM-01)';
              return [
                s.code,
                _sanitizePdfText(s.name),
                '${s.areaHa.toStringAsFixed(1)} ha',
                '${s.vegetalCoverPercent.toStringAsFixed(1)}%',
                '${s.erosionAbatementTonHaYear.toStringAsFixed(1)} t/ha/ano (-${s.erosionReductionPercent.toStringAsFixed(0)}%)',
                agreementDisplay,
              ];
            }).toList(),
          ),
          pw.SizedBox(height: 12),

          // 6. Vistorias Georreferenciadas de Campo e Trilha de Sincronização (AM-03 a AM-05, AM-11)
          pw.Text(
            '6. REGISTROS DE CAMPO GEORREFERENCIADOS E AUDITORIA (AM-03 A AM-05, AM-11)',
            style: pw.TextStyle(
              fontSize: 11,
              fontWeight: pw.FontWeight.bold,
              color: primaryGreen,
            ),
          ),
          pw.SizedBox(height: 6),
          pw.TableHelper.fromTextArray(
            headerStyle: pw.TextStyle(
              fontSize: 7.2,
              fontWeight: pw.FontWeight.bold,
            ),
            cellStyle: const pw.TextStyle(fontSize: 7.2),
            headers: const [
              'Ponto / Template',
              'Sobrevivencia',
              'GPS (Lat, Lng)',
              'Status Sync (v)',
              'Autoria / Observacao Tecnica (AM-01)',
            ],
            data: fieldForms.map((f) {
              final noteText = (f.isConfidential && !canViewConfidential)
                  ? 'OBSERVACAO TECNICA SIGILOSA PROTEGIDA (AM-01)'
                  : _sanitizePdfText(f.technicalNotes);
              return [
                '${f.pointId.toUpperCase()} - ${_sanitizePdfText(f.templateName)}',
                '${f.survivalRatePercent.toStringAsFixed(1)}%',
                '${f.latitude.toStringAsFixed(4)}, ${f.longitude.toStringAsFixed(4)}',
                '${f.syncStatus.shortBadge} (v${f.version})',
                '${_sanitizePdfText(f.authorName)}: $noteText',
              ];
            }).toList(),
          ),
        ],
      ),
    );

    return doc.save();
  }

  /// Constrói o conteúdo estruturado de planilha CSV compatível com Microsoft Excel / LibreOffice Calc
  /// (com separador `;` padrão pt-BR) contendo KPIs, Projetos, Qualidade da Água CONAMA 357/2005,
  /// Unidades de Conservação do Solo e Coletas de Campo, respeitando o sigilo por perfil (AM-01 e AM-09).
  static String generateSpreadsheetCsvContent({
    required AppState appState,
    String programFilter = 'TODOS',
  }) {
    final user = appState.currentUser ?? AppUser.demoUsers.last;
    final canViewConfidential = user.canViewConfidentialData;
    final kpis = calculateKpis(
      appState: appState,
      programFilter: programFilter,
    );

    final projects = filterProjects(appState, programFilter);
    final projectIds = projects.map((p) => p.id).toSet();
    final properties = appState.properties
        .where((prop) => projectIds.contains(prop.projectId))
        .toList();
    final waterAnalyses = appState.waterAnalyses
        .where((w) => projectIds.contains(w.projectId))
        .toList();
    final soilUnits = appState.soilUnits
        .where((s) => projectIds.contains(s.projectId))
        .toList();
    final fieldForms = appState.fieldForms
        .where((f) => projectIds.contains(f.projectId))
        .toList();

    final buf = StringBuffer();

    // Cabeçalho Institucional e Escopo de Sigilo (AM-01 / AM-09)
    buf.writeln('RELATORIO PLANILHA EXCEL/CSV - MONITORAMENTO AMBIENTAL MUDA & PSA');
    buf.writeln(
      'Filtro Programa;${_escapeCsv(kpis.programFilter)};Usuario Emissor;${_escapeCsv(user.name)};Perfil Ativo;${_escapeCsv(user.role.label)};Sigilo Autorizado (AM-01);${canViewConfidential ? "SIM" : "NAO (DADOS SIGILOSOS MASCARADOS)"}',
    );
    buf.writeln();

    // Seção 1: KPIs Consolidados (AM-08)
    buf.writeln('SECAO 1 - INDICADORES CONSOLIDADOS (AM-08)');
    buf.writeln('Indicador;Valor;Unidade / Detalhe');
    buf.writeln('Projetos Monitorados;${kpis.projectsCount};projetos');
    buf.writeln('Propriedades Rurais;${kpis.propertiesCount};propriedades');
    buf.writeln(
      'Area Total Monitorada;${kpis.totalMonitoredAreaHa.toStringAsFixed(2)};ha',
    );
    buf.writeln(
      'Area em Restauracao Florestal;${kpis.totalRestorationAreaHa.toStringAsFixed(2)};ha',
    );
    buf.writeln('Meta Total de Mudas;${kpis.totalTargetSeedlings};mudas');
    buf.writeln(
      'Taxa Media de Sobrevivencia de Mudas;${kpis.averageSurvivalRatePercent.toStringAsFixed(2)};%',
    );
    buf.writeln(
      'Avanco Medio do Cronograma;${kpis.averageScheduleProgressPercent.toStringAsFixed(2)};%',
    );
    buf.writeln(
      'Indice de Conformidade CONAMA 357/2005 Classe 2;${kpis.conamaCompliancePercent.toStringAsFixed(2)};% (${kpis.waterCompliantCount}/${kpis.waterAnalysesCount} laudos)',
    );
    buf.writeln(
      'Area de Unidades Modelo de Conservacao do Solo;${kpis.totalSoilConservationAreaHa.toStringAsFixed(2)};ha',
    );
    buf.writeln(
      'Abatimento Total Estimado de Erosao Hidrica (USLE);${kpis.totalErosionAbatementTonYear.toStringAsFixed(2)};t/ano',
    );
    buf.writeln();

    // Seção 2: Propriedades Rurais e Controle de Sigilo (AM-01 / AM-02)
    buf.writeln('SECAO 2 - PROPRIEDADES RURAIS E AREAS MONITORADAS (AM-01 / AM-02)');
    buf.writeln(
      'Codigo;Propriedade;Municipio;Area Total (ha);Area Restauracao (ha);Proprietario (AM-01);CPF (AM-01);Registro CAR (AM-01);Repasse Mensal PSA (AM-01)',
    );
    for (final prop in properties) {
      final ownerName = canViewConfidential
          ? prop.ownerName
          : 'Restrito LGPD/Sigilo (AM-01)';
      final ownerCpf = canViewConfidential
          ? prop.ownerCpf
          : '•••.•••.•••-•• (Restrito - LGPD/Sigilo)';
      final carCode = canViewConfidential
          ? prop.carRegistryCode
          : 'CAR Restrito (AM-01)';
      final psaValue = canViewConfidential
          ? 'R\$ ${prop.psaMonthlyValue.toStringAsFixed(2)}'
          : 'Sigilo Contratual (AM-01)';
      buf.writeln(
        '${_escapeCsv(prop.code)};${_escapeCsv(prop.name)};${_escapeCsv(prop.municipality)};${prop.totalAreaHa.toStringAsFixed(2)};${prop.restorationAreaHa.toStringAsFixed(2)};${_escapeCsv(ownerName)};${_escapeCsv(ownerCpf)};${_escapeCsv(carCode)};${_escapeCsv(psaValue)}',
      );
    }
    buf.writeln();

    // Seção 3: Análises de Qualidade da Água CONAMA 357/2005 (AM-07)
    buf.writeln('SECAO 3 - LAUDOS DE QUALIDADE DA AGUA CONAMA 357/2005 CLASSE 2 (AM-07)');
    buf.writeln(
      'Codigo Laudo;Ponto Coleta;Data Amostra;Campanha;pH;Turbidez (UNT);OD (mg/L);DBO (mg/L);Fosforo Total (mg/L);Coliformes (NMP/100mL);Vazao (L/s);Status CONAMA 357;Notas Laboratoriais Sigilosas (AM-01)',
    );
    for (final w in waterAnalyses) {
      final labNotes = (!w.isConfidentialReport || canViewConfidential)
          ? w.confidentialLabNotes
          : 'LAUDO COMPLEMENTAR RESTRITO (AM-01)';
      buf.writeln(
        '${_escapeCsv(w.reportCode)};${_escapeCsv(w.pointId)};${_escapeCsv(w.sampleDate)};${_escapeCsv(w.campaignName)};${w.ph.toStringAsFixed(2)};${w.turbidityUnt.toStringAsFixed(1)};${w.dissolvedOxygenMgL.toStringAsFixed(2)};${w.dboMgL.toStringAsFixed(2)};${w.totalPhosphorusMgL.toStringAsFixed(3)};${w.thermotolerantColiformsNmp};${w.flowRateLs.toStringAsFixed(2)};${_escapeCsv(w.complianceStatusLabel)};${_escapeCsv(labNotes)}',
      );
    }
    buf.writeln();

    // Seção 4: Unidades Modelo de Conservação do Solo (AM-10)
    buf.writeln('SECAO 4 - UNIDADES MODELO DE CONSERVACAO DO SOLO (AM-10)');
    buf.writeln(
      'Codigo;Unidade;Ponto;Area (ha);Classe Solo;Declividade (%);Cobertura Vegetal (%);Erosao Base (t/ha/ano);Erosao Atual (t/ha/ano);Abatimento (t/ha/ano);Reducao (%);Acordo Proprietario (AM-01)',
    );
    for (final s in soilUnits) {
      final agreement = canViewConfidential
          ? s.confidentialOwnerAgreement
          : 'ACORDO INDIVIDUAL E CAR/CPF RESTRITOS (AM-01)';
      buf.writeln(
        '${_escapeCsv(s.code)};${_escapeCsv(s.name)};${_escapeCsv(s.pointId)};${s.areaHa.toStringAsFixed(2)};${_escapeCsv(s.soilClass)};${s.slopePercent.toStringAsFixed(1)};${s.vegetalCoverPercent.toStringAsFixed(1)};${s.baselineErosionTonHaYear.toStringAsFixed(2)};${s.currentErosionTonHaYear.toStringAsFixed(2)};${s.erosionAbatementTonHaYear.toStringAsFixed(2)};${s.erosionReductionPercent.toStringAsFixed(1)};${_escapeCsv(agreement)}',
      );
    }
    buf.writeln();

    // Seção 5: Coletas de Campo Offline/Online e Auditoria (AM-03 a AM-05, AM-11)
    buf.writeln('SECAO 5 - VISTORIAS DE CAMPO GEORREFERENCIADAS E SINCRONIZACAO (AM-03 A AM-05, AM-11)');
    buf.writeln(
      'Client UUID;Ponto;Template;Sobrevivencia (%);Status Erosao;Invasoras;Latitude;Longitude;Precisao GPS (m);Status Sincronizacao;Versao;Autor;Observacao Tecnica (AM-01)',
    );
    for (final f in fieldForms) {
      final notes = (f.isConfidential && !canViewConfidential)
          ? 'OBSERVACAO TECNICA SIGILOSA PROTEGIDA (AM-01)'
          : f.technicalNotes;
      buf.writeln(
        '${_escapeCsv(f.clientUuid)};${_escapeCsv(f.pointId)};${_escapeCsv(f.templateName)};${f.survivalRatePercent.toStringAsFixed(1)};${_escapeCsv(f.erosionStatus)};${f.invasiveSpeciesPresent ? "SIM" : "NAO"};${f.latitude.toStringAsFixed(6)};${f.longitude.toStringAsFixed(6)};${f.gpsAccuracyMeters.toStringAsFixed(1)};${_escapeCsv(f.syncStatus.label)};${f.version};${_escapeCsv(f.authorName)};${_escapeCsv(notes)}',
      );
    }

    return buf.toString();
  }

  /// Abre o diálogo nativo de impressão / visualização / compartilhamento de PDF no celular (`printing`).
  static Future<void> shareOrPrintPdfReport({
    required AppState appState,
    String programFilter = 'TODOS',
  }) async {
    final pdfBytes = await generateTechnicalReportPdfBytes(
      appState: appState,
      programFilter: programFilter,
    );
    final fileName =
        'Relatorio_Ambiental_Muda_PSA_${programFilter.toUpperCase()}.pdf';

    await Printing.sharePdf(
      bytes: pdfBytes,
      filename: fileName,
    );
  }

  /// Exporta e compartilha a planilha Excel/CSV direto do celular via `share_plus` (AM-09).
  static Future<String> exportAndShareCsvSpreadsheet({
    required AppState appState,
    String programFilter = 'TODOS',
  }) async {
    final csvContent = generateSpreadsheetCsvContent(
      appState: appState,
      programFilter: programFilter,
    );
    final fileName =
        'Planilha_Monitoramento_Muda_PSA_${programFilter.toUpperCase()}.csv';

    try {
      final tempDir = await getTemporaryDirectory();
      final filePath = p.join(tempDir.path, fileName);
      final xFile = XFile.fromData(
        Uint8List.fromList(utf8.encode(csvContent)),
        name: fileName,
        mimeType: 'text/csv',
        path: filePath,
      );
      await Share.shareXFiles(
        [xFile],
        subject: 'Planilha de Monitoramento Ambiental Muda & PSA ($programFilter)',
        text:
            'Exportação consolidada de indicadores, qualidade da água CONAMA 357/2005 e conservação do solo.',
      );
    } catch (_) {
      // Em ambiente de teste sem canal nativo de path_provider/share_plus, retorna o conteúdo CSV gerado
    }

    return csvContent;
  }

  static pw.Widget _buildPdfKpiBox(
    String title,
    String primaryValue,
    String subtitle,
  ) {
    return pw.Container(
      width: 120,
      padding: const pw.EdgeInsets.all(6),
      decoration: pw.BoxDecoration(
        color: PdfColors.white,
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            title,
            style: const pw.TextStyle(fontSize: 7.2, color: PdfColors.grey700),
          ),
          pw.SizedBox(height: 2),
          pw.Text(
            primaryValue,
            style: pw.TextStyle(
              fontSize: 10.5,
              fontWeight: pw.FontWeight.bold,
              color: PdfColor.fromInt(0xFF1B5E20),
            ),
          ),
          pw.SizedBox(height: 2),
          pw.Text(
            subtitle,
            style: const pw.TextStyle(fontSize: 6.8, color: PdfColors.grey800),
          ),
        ],
      ),
    );
  }

  static String _escapeCsv(String value) {
    final cleaned = value.replaceAll('\r', ' ').replaceAll('\n', ' ').trim();
    if (cleaned.contains(';') || cleaned.contains('"')) {
      return '"${cleaned.replaceAll('"', '""')}"';
    }
    return cleaned;
  }

  /// Normaliza acentuação, emojis e caracteres especiais para ASCII puro (32..126),
  /// garantindo compatibilidade total com a fonte Helvetica padrão do PDF.
  static String _sanitizePdfText(String input) {
    const diacriticsMap = <String, String>{
      'á': 'a', 'à': 'a', 'â': 'a', 'ã': 'a', 'ä': 'a',
      'Á': 'A', 'À': 'A', 'Â': 'A', 'Ã': 'A', 'Ä': 'A',
      'é': 'e', 'è': 'e', 'ê': 'e', 'ë': 'e',
      'É': 'E', 'È': 'E', 'Ê': 'E', 'Ë': 'E',
      'í': 'i', 'ì': 'i', 'î': 'i', 'ï': 'i',
      'Í': 'I', 'Ì': 'I', 'Î': 'I', 'Ï': 'I',
      'ó': 'o', 'ò': 'o', 'ô': 'o', 'õ': 'o', 'ö': 'o',
      'Ó': 'O', 'Ò': 'O', 'Ô': 'O', 'Õ': 'O', 'Ö': 'O',
      'ú': 'u', 'ù': 'u', 'û': 'u', 'ü': 'u',
      'Ú': 'U', 'Ù': 'U', 'Û': 'U', 'Ü': 'U',
      'ç': 'c', 'Ç': 'C', 'ñ': 'n', 'Ñ': 'N',
      '—': '-', '–': '-', '•': '*', 'º': 'o', 'ª': 'a',
      '₅': '5', '₂': '2', '₀': '0', '±': '+/-',
    };
    final sb = StringBuffer();
    for (final rune in input.runes) {
      if (rune >= 32 && rune <= 126) {
        sb.writeCharCode(rune);
        continue;
      }
      if (rune == 10 || rune == 13) {
        sb.write(' ');
        continue;
      }
      final ch = String.fromCharCode(rune);
      final mapped = diacriticsMap[ch];
      if (mapped != null) {
        sb.write(mapped);
      } else {
        sb.write(' ');
      }
    }
    return sb.toString().replaceAll(RegExp(r'\s+'), ' ').trim();
  }
}
