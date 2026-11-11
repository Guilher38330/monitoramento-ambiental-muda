import 'dart:typed_data';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../models/field_form_record.dart';
import '../models/project_models.dart';
import '../models/user_profile.dart';
import '../models/water_soil_models.dart';
import '../services/report_export_service.dart';
import '../state/app_state.dart';
import 'water_soil_analysis_screen.dart';

/// Tela de Dashboards de Indicadores Ambientais (AM-08), Geração/Compartilhamento
/// de Relatórios Técnicos em PDF e Planilhas Excel/CSV direto do celular (AM-09 + 3º Critério de Aceite),
/// além de acesso integrado aos módulos de Qualidade da Água (AM-07) e Conservação do Solo (AM-10).
class DashboardReportsScreen extends StatefulWidget {
  final AppState appState;
  final String? initialWaterPointId;

  const DashboardReportsScreen({
    super.key,
    required this.appState,
    this.initialWaterPointId,
  });

  @override
  State<DashboardReportsScreen> createState() => _DashboardReportsScreenState();
}

class _DashboardReportsScreenState extends State<DashboardReportsScreen> {
  /// 0 = Dashboard de Indicadores & Exportação PDF/Excel (AM-08 / AM-09)
  /// 1 = Análises de Água CONAMA 357/2005 & Unidades Modelo de Solo (AM-07 / AM-10)
  late int _selectedModeIndex;
  String _selectedProgramFilter = 'TODOS'; // 'TODOS', 'MUDA', 'PSA'
  bool _isGeneratingReport = false;
  String? _exportFeedbackMessage;

  @override
  void initState() {
    super.initState();
    // Se veio de um atalho direto de um ponto do mapa para ver o laudo de água daquele ponto,
    // abre na visão detalhada de Água/Solo, mantendo o botão de alternância para o Dashboard AM-08/AM-09.
    _selectedModeIndex = widget.initialWaterPointId != null ? 1 : 0;
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.appState.currentUser!;

    return Column(
      children: [
        _buildTopModuleSwitchBar(user),
        Expanded(
          child: _selectedModeIndex == 0
              ? _buildDashboardAndReportsView(context, user)
              : WaterSoilAnalysisScreen(
                  key: ValueKey(
                    'embedded_water_soil_${widget.initialWaterPointId ?? "all"}',
                  ),
                  appState: widget.appState,
                  initialPointId: widget.initialWaterPointId,
                ),
        ),
      ],
    );
  }

  Widget _buildTopModuleSwitchBar(AppUser user) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
      decoration: const BoxDecoration(
        color: Color(0xFFE8F2EA),
        border: Border(bottom: BorderSide(color: Color(0xFFC5D8C9))),
      ),
      child: Row(
        children: [
          Expanded(
            child: SegmentedButton<int>(
              key: const Key('indicators_mode_segmented_button'),
              segments: const [
                ButtonSegment<int>(
                  value: 0,
                  icon: Icon(Icons.insights_rounded, size: 18),
                  label: Text('Dashboards & Relatórios (AM-08/09)'),
                ),
                ButtonSegment<int>(
                  value: 1,
                  icon: Icon(Icons.water_drop_rounded, size: 18),
                  label: Text('Laudos Água & Solo (AM-07/10)'),
                ),
              ],
              selected: {_selectedModeIndex},
              onSelectionChanged: (selection) {
                setState(() {
                  _selectedModeIndex = selection.first;
                });
              },
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // VISÃO 0: DASHBOARDS DE INDICADORES (AM-08) E RELATÓRIOS PDF / EXCEL (AM-09)
  // ===========================================================================
  Widget _buildDashboardAndReportsView(BuildContext context, AppUser user) {
    final kpis = ReportExportService.calculateKpis(
      appState: widget.appState,
      programFilter: _selectedProgramFilter,
    );
    final projects = ReportExportService.filterProjects(
      widget.appState,
      _selectedProgramFilter,
    );
    final projectIds = projects.map((p) => p.id).toSet();

    final forms = widget.appState.fieldForms
        .where((f) => projectIds.contains(f.projectId))
        .toList();
    final points = widget.appState.collectionPoints
        .where((pt) => projectIds.contains(pt.projectId))
        .toList();
    final waterAnalyses = widget.appState.waterAnalyses
        .where((w) => projectIds.contains(w.projectId))
        .toList();
    final soilUnits = widget.appState.soilUnits
        .where((s) => projectIds.contains(s.projectId))
        .toList();

    return ListView(
      key: const Key('dashboard_reports_scroll_view'),
      padding: const EdgeInsets.all(16),
      children: [
        // 1. Cabeçalho + Seletor de Programa ('Todos', 'Programa Muda', 'Programa PSA')
        _buildProgramFilterHeader(user, kpis),
        const SizedBox(height: 14),

        // 2. Central de Geração e Compartilhamento de Relatórios no Celular (AM-09 + 3º Critério de Aceite)
        _buildReportExportActionCard(context, user, kpis),
        const SizedBox(height: 16),

        // 3. Cards de KPIs Consolidados de Monitoramento (AM-08)
        _buildKpiCardsGrid(kpis, user),
        const SizedBox(height: 18),

        // 4. Gráfico Interativo 1 (fl_chart BarChart): Taxa de Sobrevivência de Mudas por Vistoria/Ponto (AM-08)
        _buildSeedlingSurvivalChartCard(forms),
        const SizedBox(height: 16),

        // 5. Gráfico Interativo 2 (fl_chart LineChart / BarChart): Qualidade da Água & Conformidade CONAMA 357 por Ponto (AM-07 / AM-08)
        _buildWaterComplianceChartCard(points, waterAnalyses),
        const SizedBox(height: 16),

        // 6. Gráfico Interativo 3 (fl_chart PieChart + Barras de Etapas): Avanço do Cronograma & Conservação do Solo USLE (AM-08 / AM-10)
        _buildScheduleAndSoilChartCard(projects, soilUnits, kpis),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildProgramFilterHeader(AppUser user, DashboardKpiSummary kpis) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFD0E0D4)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F5E9),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.analytics_rounded,
                  color: Color(0xFF1B5E20),
                  size: 22,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Painel Executivo de Indicadores (AM-08 & AM-09)',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF1B3A24),
                      ),
                    ),
                    Text(
                      user.canViewConfidentialData
                          ? 'Visualização completa autorizada para ${user.role.label} (inclui dados técnicos e sigilosos AM-01).'
                          : 'Visualização filtrada para ${user.role.label}: indicadores consolidados abertos e sigilo protegido (AM-01).',
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: Color(0xFF4A6352),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            'Filtrar Indicadores e Relatórios por Programa:',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: Color(0xFF2E4C38),
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ChoiceChip(
                key: const Key('dashboard_filter_todos'),
                label: const Text('Todos os Programas (Muda + PSA)'),
                selected: _selectedProgramFilter == 'TODOS',
                onSelected: (_) {
                  setState(() {
                    _selectedProgramFilter = 'TODOS';
                  });
                },
              ),
              ChoiceChip(
                key: const Key('dashboard_filter_muda'),
                label: const Text('Programa Muda (Florestal)'),
                selected: _selectedProgramFilter == 'MUDA',
                onSelected: (_) {
                  setState(() {
                    _selectedProgramFilter = 'MUDA';
                  });
                },
              ),
              ChoiceChip(
                key: const Key('dashboard_filter_psa'),
                label: const Text('Programa PSA (Recursos Hídricos)'),
                selected: _selectedProgramFilter == 'PSA',
                onSelected: (_) {
                  setState(() {
                    _selectedProgramFilter = 'PSA';
                  });
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildReportExportActionCard(
    BuildContext context,
    AppUser user,
    DashboardKpiSummary kpis,
  ) {
    return Container(
      key: const Key('report_export_action_card'),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1B5E20), Color(0xFF2E7D32)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1F1B5E20),
            blurRadius: 8,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.picture_as_pdf_rounded,
                color: Color(0xFFA5D6A7),
                size: 22,
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Relatórios Técnicos PDF e Planilhas Excel/CSV no Celular (AM-09)',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'Escopo: $_selectedProgramFilter',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            user.canViewConfidentialData
                ? 'Gere, inspecione e compartilhe relatórios técnicos PDF e planilhas CSV diretamente pelo smartphone sem depender de portal web (3º Critério de Aceite).'
                : 'Modo Empresa Contratante (AM-01): Os relatórios PDF e CSV gerados mascaram automaticamente CPF, CAR, valores financeiros PSA e notas restritas.',
            style: const TextStyle(
              color: Color(0xFFE8F5E9),
              fontSize: 11.5,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              ElevatedButton.icon(
                key: const Key('btn_generate_share_pdf_report'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: const Color(0xFF1B5E20),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  textStyle: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                onPressed: _isGeneratingReport
                    ? null
                    : () => _openPdfReportPreviewDialog(context),
                icon: const Icon(Icons.picture_as_pdf_rounded, size: 18),
                label: const Text(
                  'Visualizar / Compartilhar Relatório PDF',
                ),
              ),
              ElevatedButton.icon(
                key: const Key('btn_export_share_csv_spreadsheet'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFE8F5E9),
                  foregroundColor: const Color(0xFF0D3B1E),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  textStyle: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                onPressed: _isGeneratingReport
                    ? null
                    : () => _openCsvSpreadsheetPreviewDialog(context),
                icon: const Icon(Icons.table_view_rounded, size: 18),
                label: const Text('Exportar Planilha Excel/CSV'),
              ),
            ],
          ),
          if (_exportFeedbackMessage != null) ...[
            const SizedBox(height: 10),
            Container(
              key: const Key('report_export_feedback_banner'),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.22),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.check_circle_outline_rounded,
                    color: Color(0xFFA5D6A7),
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _exportFeedbackMessage!,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildKpiCardsGrid(DashboardKpiSummary kpis, AppUser user) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Indicadores-Chave de Monitoramento (KPIs — AM-08)',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            color: Color(0xFF1B3A24),
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            _buildKpiMetricCard(
              cardKey: const Key('kpi_card_restored_area'),
              icon: Icons.forest_rounded,
              accentColor: const Color(0xFF2E7D32),
              title: 'Hectares em Restauração',
              primaryValue: '${kpis.totalRestorationAreaHa.toStringAsFixed(1)} ha',
              subtitle:
                  'Área total monitorada: ${kpis.totalMonitoredAreaHa.toStringAsFixed(1)} ha (${kpis.propertiesCount} propriedades)',
            ),
            _buildKpiMetricCard(
              cardKey: const Key('kpi_card_seedlings_survival'),
              icon: Icons.spa_rounded,
              accentColor: const Color(0xFF00796B),
              title: 'Mudas & Sobrevivência Média',
              primaryValue:
                  '${kpis.averageSurvivalRatePercent.toStringAsFixed(1)}%',
              subtitle:
                  'Meta: ${kpis.totalTargetSeedlings} mudas nativas (${kpis.fieldFormsTotalCount} vistorias)',
            ),
            _buildKpiMetricCard(
              cardKey: const Key('kpi_card_conama_compliance'),
              icon: Icons.water_drop_rounded,
              accentColor: const Color(0xFF0277BD),
              title: 'Conformidade CONAMA 357',
              primaryValue:
                  '${kpis.conamaCompliancePercent.toStringAsFixed(1)}%',
              subtitle:
                  '${kpis.waterCompliantCount} de ${kpis.waterAnalysesCount} laudos 100% Classe 2',
            ),
            _buildKpiMetricCard(
              cardKey: const Key('kpi_card_soil_conservation'),
              icon: Icons.landscape_rounded,
              accentColor: const Color(0xFF6D4C41),
              title: 'Conservação do Solo (AM-10)',
              primaryValue:
                  '${kpis.totalSoilConservationAreaHa.toStringAsFixed(1)} ha',
              subtitle:
                  'Abatimento USLE: ${kpis.totalErosionAbatementTonYear.toStringAsFixed(0)} t/ano • Cobertura: ${kpis.averageSoilVegetalCoverPercent.toStringAsFixed(1)}%',
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildKpiMetricCard({
    required Key cardKey,
    required IconData icon,
    required Color accentColor,
    required String title,
    required String primaryValue,
    required String subtitle,
  }) {
    return Container(
      key: cardKey,
      width: 245,
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: accentColor.withValues(alpha: 0.3)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x08000000),
            blurRadius: 5,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: accentColor, size: 18),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF375240),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            primaryValue,
            style: TextStyle(
              fontSize: 21,
              fontWeight: FontWeight.w900,
              color: accentColor,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: const TextStyle(
              fontSize: 11,
              color: Color(0xFF546E5C),
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // GRÁFICO 1 (fl_chart BarChart): EVOLUÇÃO DA TAXA DE SOBREVIVÊNCIA DE MUDAS
  // ===========================================================================
  Widget _buildSeedlingSurvivalChartCard(List<FieldFormRecord> forms) {
    return Container(
      key: const Key('chart_card_seedling_survival'),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFD0E0D4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.bar_chart_rounded, color: Color(0xFF1B5E20), size: 20),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Evolução da Taxa de Sobrevivência de Mudas por Vistoria (%) — fl_chart',
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1B3A24),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'Meta técnica de referência contratual: >= 80,0% de pegamento florestal nos talhões monitorados.',
            style: TextStyle(fontSize: 11.5, color: Color(0xFF4F6957)),
          ),
          const SizedBox(height: 14),
          if (forms.isEmpty)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('Nenhuma vistoria registrada para o filtro atual.'),
            )
          else
            SizedBox(
              height: 210,
              child: BarChart(
                BarChartData(
                  maxY: 100,
                  minY: 0,
                  gridData: FlGridData(
                    show: true,
                    horizontalInterval: 20,
                    getDrawingHorizontalLine: (value) => FlLine(
                      color: value == 80
                          ? const Color(0xFF2E7D32)
                          : const Color(0xFFE0E8E2),
                      strokeWidth: value == 80 ? 1.5 : 1.0,
                      dashArray: value == 80 ? [5, 4] : null,
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  titlesData: FlTitlesData(
                    topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 36,
                        interval: 20,
                        getTitlesWidget: (val, meta) => Text(
                          '${val.toInt()}%',
                          style: const TextStyle(
                            fontSize: 10,
                            color: Color(0xFF4A6352),
                          ),
                        ),
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 32,
                        getTitlesWidget: (val, meta) {
                          final idx = val.toInt();
                          if (idx < 0 || idx >= forms.length) {
                            return const SizedBox.shrink();
                          }
                          final ptCode = forms[idx]
                              .pointId
                              .toUpperCase()
                              .replaceAll('PT-', '');
                          return Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(
                              ptCode,
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF1B3A24),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  barGroups: List.generate(forms.length, (index) {
                    final f = forms[index];
                    final isAboveTarget = f.survivalRatePercent >= 80.0;
                    return BarChartGroupData(
                      x: index,
                      barRods: [
                        BarChartRodData(
                          toY: f.survivalRatePercent.clamp(0.0, 100.0),
                          width: 24,
                          color: isAboveTarget
                              ? const Color(0xFF2E7D32)
                              : const Color(0xFFEF6C00),
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(6),
                          ),
                        ),
                      ],
                    );
                  }),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ===========================================================================
  // GRÁFICO 2 (fl_chart LineChart): EVOLUÇÃO HIDROAMBIENTAL & CONFORMIDADE CONAMA 357
  // ===========================================================================
  Widget _buildWaterComplianceChartCard(
    List<CollectionPoint> points,
    List<WaterQualityAnalysis> analyses,
  ) {
    return Container(
      key: const Key('chart_card_water_conama'),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFD0E0D4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.show_chart_rounded, color: Color(0xFF0277BD), size: 20),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Qualidade da Água: Oxigênio Dissolvido (OD) & Turbidez vs Limite CONAMA 357/2005',
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1B3A24),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'Linha Verde = OD (mg/L, mínimo CONAMA >= 5,0 mg/L) • Indicadores por campanha de coleta.',
            style: TextStyle(fontSize: 11.5, color: Color(0xFF4F6957)),
          ),
          const SizedBox(height: 14),
          if (analyses.isEmpty)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('Nenhum laudo de água encontrado para o filtro.'),
            )
          else
            SizedBox(
              height: 200,
              child: LineChart(
                LineChartData(
                  minY: 0,
                  maxY: 12,
                  gridData: FlGridData(
                    show: true,
                    horizontalInterval: 2,
                    getDrawingHorizontalLine: (val) => FlLine(
                      color: val == 5
                          ? const Color(0xFFC62828)
                          : const Color(0xFFE0E8E2),
                      strokeWidth: val == 5 ? 1.5 : 1.0,
                      dashArray: val == 5 ? [4, 4] : null,
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  titlesData: FlTitlesData(
                    topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 42,
                        interval: 2,
                        getTitlesWidget: (val, meta) => Text(
                          '${val.toInt()} mg/L',
                          style: const TextStyle(
                            fontSize: 9.5,
                            color: Color(0xFF4A6352),
                          ),
                        ),
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 30,
                        interval: 1,
                        getTitlesWidget: (val, meta) {
                          final idx = val.toInt();
                          if (idx < 0 || idx >= analyses.length) {
                            return const SizedBox.shrink();
                          }
                          final shortCode = analyses[idx]
                              .pointId
                              .toUpperCase()
                              .replaceAll('PT-', '');
                          return Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(
                              shortCode,
                              style: const TextStyle(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  lineBarsData: [
                    LineChartBarData(
                      isCurved: true,
                      color: const Color(0xFF0277BD),
                      barWidth: 3,
                      dotData: const FlDotData(show: true),
                      belowBarData: BarAreaData(
                        show: true,
                        color: const Color(0xFF0277BD).withValues(alpha: 0.12),
                      ),
                      spots: List.generate(analyses.length, (i) {
                        final od =
                            analyses[i].dissolvedOxygenMgL.clamp(0.0, 12.0);
                        return FlSpot(i.toDouble(), od);
                      }),
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: analyses.map((w) {
              final ok = w.isConamaCompliant;
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                decoration: BoxDecoration(
                  color: ok ? const Color(0xFFE8F5E9) : const Color(0xFFFFEBEE),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color:
                        ok ? const Color(0xFF81C784) : const Color(0xFFEF9A9A),
                  ),
                ),
                child: Text(
                  '${w.reportCode} (${w.pointId.toUpperCase()}): ${ok ? "CONFORME" : "${w.violations.length} VIOLAÇÃO(ÕES)"}',
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    color:
                        ok ? const Color(0xFF1B5E20) : const Color(0xFFC62828),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // GRÁFICO 3 (fl_chart PieChart + Etapas): CRONOGRAMA E CONSERVAÇÃO DO SOLO
  // ===========================================================================
  Widget _buildScheduleAndSoilChartCard(
    List<EnvironmentalProject> projects,
    List<SoilConservationUnit> soilUnits,
    DashboardKpiSummary kpis,
  ) {
    final compliantWater = kpis.waterCompliantCount.toDouble();
    final violatedWater =
        (kpis.waterAnalysesCount - kpis.waterCompliantCount).toDouble();

    return Container(
      key: const Key('chart_card_schedule_and_soil'),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFD0E0D4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.pie_chart_rounded, color: Color(0xFF6D4C41), size: 20),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Distribuição de Conformidade Ambiental & Avanço Físico dos Projetos',
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1B3A24),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              SizedBox(
                width: 130,
                height: 130,
                child: PieChart(
                  PieChartData(
                    centerSpaceRadius: 26,
                    sectionsSpace: 2,
                    sections: [
                      PieChartSectionData(
                        value: compliantWater <= 0 && violatedWater <= 0
                            ? 1
                            : compliantWater,
                        title: '${kpis.conamaCompliancePercent.toStringAsFixed(0)}%',
                        color: const Color(0xFF2E7D32),
                        radius: 34,
                        titleStyle: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                      if (violatedWater > 0)
                        PieChartSectionData(
                          value: violatedWater,
                          title: '${violatedWater.toInt()} viol.',
                          color: const Color(0xFFEF6C00),
                          radius: 30,
                          titleStyle: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ...projects.map((p) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '[${p.programType}] ${p.code} — Avanço: ${p.overallProgress.toStringAsFixed(1)}%',
                              style: const TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF1B3A24),
                              ),
                            ),
                            const SizedBox(height: 4),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(6),
                              child: LinearProgressIndicator(
                                value: (p.overallProgress / 100.0).clamp(0.0, 1.0),
                                minHeight: 8,
                                backgroundColor: const Color(0xFFE0E8E2),
                                color: p.isMuda
                                    ? const Color(0xFF2E7D32)
                                    : const Color(0xFF0277BD),
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                    const Divider(height: 14),
                    Text(
                      'Unidades Modelo de Solo (AM-10): ${soilUnits.length} unidade(s) • Abatimento de erosão: ${kpis.totalErosionAbatementTonYear.toStringAsFixed(1)} t/ano.',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF4E342E),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // MODAIS INTERATIVOS DE RELATÓRIO PDF E PLANILHA CSV (AM-09 + 3º CRITÉRIO)
  // ===========================================================================
  Future<void> _openPdfReportPreviewDialog(BuildContext context) async {
    setState(() {
      _isGeneratingReport = true;
    });

    Uint8List pdfBytes;
    try {
      pdfBytes = await ReportExportService.generateTechnicalReportPdfBytes(
        appState: widget.appState,
        programFilter: _selectedProgramFilter,
      );
    } finally {
      if (mounted) {
        setState(() {
          _isGeneratingReport = false;
          _exportFeedbackMessage =
              'Relatório Técnico PDF ($_selectedProgramFilter) gerado com sucesso no celular (${widget.appState.currentUser?.role.label}).';
        });
      }
    }

    if (!context.mounted) return;

    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        backgroundColor: Color(0xFF2E7D32),
        behavior: SnackBarBehavior.floating,
        content: Row(
          children: [
            Icon(Icons.check_circle_rounded, color: Colors.white),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Relatório PDF consolidado gerado com sucesso!',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );

    final user = widget.appState.currentUser!;
    final kpis = ReportExportService.calculateKpis(
      appState: widget.appState,
      programFilter: _selectedProgramFilter,
    );

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        key: const Key('pdf_report_preview_dialog'),
        title: Row(
          children: [
            const Icon(Icons.picture_as_pdf_rounded, color: Color(0xFFC62828)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Relatório Técnico PDF ($_selectedProgramFilter)',
                style: const TextStyle(
                  fontSize: 15.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: 520,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8F5E9),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFA5D6A7)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Documento PDF Gerado Localmente (${(pdfBytes.lengthInBytes / 1024).toStringAsFixed(1)} KB)',
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 12.5,
                          color: Color(0xFF1B5E20),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Emissor: ${user.name} (${user.role.label})',
                        style: const TextStyle(fontSize: 11.5),
                      ),
                      Text(
                        user.canViewConfidentialData
                            ? 'Política AM-01: Relatório Completo com Dados Técnicos e Sigilosos Autorizados.'
                            : 'Política AM-01: Relatório para Empresa Contratante — CPF, CAR, Repasses PSA e Notas Sigilosas foram MASCARADOS.',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: user.canViewConfidentialData
                              ? const Color(0xFF1B5E20)
                              : const Color(0xFFE65100),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Resumo Executivo Incluído no PDF:',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5),
                ),
                const SizedBox(height: 6),
                Text(
                  '• Projetos Incluídos: ${kpis.projectsCount} | Propriedades: ${kpis.propertiesCount}\n'
                  '• Área em Restauração: ${kpis.totalRestorationAreaHa.toStringAsFixed(1)} ha (Total Monitorado: ${kpis.totalMonitoredAreaHa.toStringAsFixed(1)} ha)\n'
                  '• Meta de Mudas: ${kpis.totalTargetSeedlings} | Sobrevivência Média: ${kpis.averageSurvivalRatePercent.toStringAsFixed(1)}%\n'
                  '• Conformidade CONAMA 357/2005 Classe 2: ${kpis.conamaCompliancePercent.toStringAsFixed(1)}% (${kpis.waterCompliantCount}/${kpis.waterAnalysesCount} laudos)\n'
                  '• Conservação do Solo (AM-10): ${kpis.totalSoilConservationAreaHa.toStringAsFixed(1)} ha (${kpis.totalErosionAbatementTonYear.toStringAsFixed(0)} t/ano abatidas)',
                  style: const TextStyle(fontSize: 12, height: 1.4),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            key: const Key('close_pdf_preview_dialog_button'),
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Fechar'),
          ),
          ElevatedButton.icon(
            key: const Key('share_native_pdf_button'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1B5E20),
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              Navigator.of(dialogContext).pop();
              try {
                await ReportExportService.shareOrPrintPdfReport(
                  appState: widget.appState,
                  programFilter: _selectedProgramFilter,
                );
                if (context.mounted) {
                  ScaffoldMessenger.of(context).clearSnackBars();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      backgroundColor: Color(0xFF2E7D32),
                      behavior: SnackBarBehavior.floating,
                      content: Row(
                        children: [
                          Icon(Icons.check_circle_rounded, color: Colors.white),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Relatório PDF consolidado gerado com sucesso!',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }
              } catch (_) {}
            },
            icon: const Icon(Icons.share_rounded, size: 16),
            label: const Text('Compartilhar / Imprimir PDF'),
          ),
        ],
      ),
    );
  }

  Future<void> _openCsvSpreadsheetPreviewDialog(BuildContext context) async {
    final csvContent = ReportExportService.generateSpreadsheetCsvContent(
      appState: widget.appState,
      programFilter: _selectedProgramFilter,
    );

    setState(() {
      _exportFeedbackMessage =
          'Planilha Excel/CSV ($_selectedProgramFilter) formatada e pronta para compartilhamento (${csvContent.split("\n").length} linhas).';
    });

    if (!context.mounted) return;

    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        backgroundColor: Color(0xFF2E7D32),
        behavior: SnackBarBehavior.floating,
        content: Row(
          children: [
            Icon(Icons.check_circle_rounded, color: Colors.white),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Planilha CSV exportada com sucesso!',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );

    final user = widget.appState.currentUser!;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        key: const Key('csv_spreadsheet_preview_dialog'),
        title: Row(
          children: [
            const Icon(Icons.table_view_rounded, color: Color(0xFF1B5E20)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Exportação Planilha Excel/CSV ($_selectedProgramFilter)',
                style: const TextStyle(
                  fontSize: 15.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: 560,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  user.canViewConfidentialData
                      ? 'Perfil ${user.role.label}: Exportação CSV completa com todos os indicadores, análises CONAMA 357/2005 e dados técnicos.'
                      : 'Perfil Empresa Contratante (AM-01): Dados sigilosos (CPF, CAR, Repasses PSA e Notas Restritas) foram mascarados na planilha.',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1B5E20),
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF4F7F5),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFCFDCD2)),
                  ),
                  child: SelectableText(
                    csvContent,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 10.5,
                      color: Color(0xFF1B3A24),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            key: const Key('close_csv_preview_dialog_button'),
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Fechar'),
          ),
          ElevatedButton.icon(
            key: const Key('share_native_csv_button'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1B5E20),
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              Navigator.of(dialogContext).pop();
              await ReportExportService.exportAndShareCsvSpreadsheet(
                appState: widget.appState,
                programFilter: _selectedProgramFilter,
              );
              if (context.mounted) {
                ScaffoldMessenger.of(context).clearSnackBars();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    backgroundColor: Color(0xFF2E7D32),
                    behavior: SnackBarBehavior.floating,
                    content: Row(
                      children: [
                        Icon(Icons.check_circle_rounded, color: Colors.white),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Planilha CSV exportada com sucesso!',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }
            },
            icon: const Icon(Icons.ios_share_rounded, size: 16),
            label: const Text('Compartilhar Arquivo .CSV'),
          ),
        ],
      ),
    );
  }
}
