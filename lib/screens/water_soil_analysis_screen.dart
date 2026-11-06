import 'package:flutter/material.dart';
import '../models/project_models.dart';
import '../models/user_profile.dart';
import '../models/water_soil_models.dart';
import '../state/app_state.dart';

/// Tela unificada de Análises de Qualidade da Água (CONAMA 357/2005 - AM-07)
/// e Unidades Modelo de Conservação do Solo (AM-10).
class WaterSoilAnalysisScreen extends StatefulWidget {
  final AppState appState;
  final int initialSubTabIndex; // 0 = Água (AM-07), 1 = Solo (AM-10)
  final String? initialPointId;

  const WaterSoilAnalysisScreen({
    super.key,
    required this.appState,
    this.initialSubTabIndex = 0,
    this.initialPointId,
  });

  @override
  State<WaterSoilAnalysisScreen> createState() =>
      _WaterSoilAnalysisScreenState();
}

class _WaterSoilAnalysisScreenState extends State<WaterSoilAnalysisScreen> {
  late int _activeSubTab;
  String _selectedPointFilter = 'TODOS';

  @override
  void initState() {
    super.initState();
    _activeSubTab = widget.initialSubTabIndex;
    if (widget.initialPointId != null) {
      _selectedPointFilter = widget.initialPointId!;
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.appState.currentUser!;

    return Column(
      children: [
        _buildTopSubNavigation(user),
        Expanded(
          child: _activeSubTab == 0
              ? _buildWaterQualitySection(context, user)
              : _buildSoilConservationSection(context, user),
        ),
      ],
    );
  }

  Widget _buildTopSubNavigation(AppUser user) {
    final waterCount = widget.appState.waterAnalyses.length;
    final soilCount = widget.appState.soilUnits.length;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFD5E2D9))),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: SegmentedButton<int>(
                  key: const Key('water_soil_segmented_switch'),
                  segments: [
                    ButtonSegment<int>(
                      value: 0,
                      icon: const Icon(Icons.water_drop_rounded, size: 18),
                      label: Text('Água CONAMA 357 ($waterCount) • AM-07'),
                    ),
                    ButtonSegment<int>(
                      value: 1,
                      icon: const Icon(Icons.landscape_rounded, size: 18),
                      label: Text('Conservação Solo ($soilCount) • AM-10'),
                    ),
                  ],
                  selected: {_activeSubTab},
                  onSelectionChanged: (sel) {
                    setState(() {
                      _activeSubTab = sel.first;
                    });
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // SEÇÃO 1: ANÁLISES DE QUALIDADE DA ÁGUA E COMPARATIVO CONAMA 357/2005 (AM-07)
  // ===========================================================================
  Widget _buildWaterQualitySection(BuildContext context, AppUser user) {
    final allPoints = widget.appState.collectionPoints;
    final filteredAnalyses = widget.appState.waterAnalyses.where((a) {
      if (_selectedPointFilter != 'TODOS' && a.pointId != _selectedPointFilter) {
        return false;
      }
      return true;
    }).toList();

    final compliantCount =
        filteredAnalyses.where((a) => a.isConamaCompliant).length;
    final violationCount = filteredAnalyses.length - compliantCount;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Card Resumo de Referência CONAMA 357/2005 Classe 2
        _buildConamaReferenceBanner(
          user: user,
          totalCount: filteredAnalyses.length,
          compliantCount: compliantCount,
          violationCount: violationCount,
        ),
        const SizedBox(height: 12),

        // Filtros por Ponto de Coleta + Botão de Novo Laudo
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            const Text(
              'Filtrar Ponto:',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: Color(0xFF16301D),
              ),
            ),
            ChoiceChip(
              key: const Key('water_filter_point_TODOS'),
              label: const Text('Todos os Pontos'),
              selected: _selectedPointFilter == 'TODOS',
              onSelected: (_) => setState(() => _selectedPointFilter = 'TODOS'),
            ),
            ...allPoints.map(
              (pt) => ChoiceChip(
                key: Key('water_filter_point_${pt.id}'),
                label: Text(pt.code),
                selected: _selectedPointFilter == pt.id,
                onSelected: (_) => setState(() => _selectedPointFilter = pt.id),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),

        // Card de Comparativo Histórico Entre Campanhas (quando há >= 2 campanhas no ponto)
        _buildHistoricalWaterComparisonCard(),
        const SizedBox(height: 14),

        // Lista de Laudos Hidrológicos
        ...filteredAnalyses.map((analysis) => _buildWaterAnalysisCard(analysis, user)),
      ],
    );
  }

  Widget _buildConamaReferenceBanner({
    required AppUser user,
    required int totalCount,
    required int compliantCount,
    required int violationCount,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF01579B), Color(0xFF0277BD)],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.science_rounded, color: Colors.white, size: 22),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Padrões CONAMA nº 357/2005 — Águas Doces Classe 2 (AM-07)',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              if (user.canRegisterFieldData)
                FilledButton.icon(
                  key: const Key('open_new_water_analysis_dialog_button'),
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xFF01579B),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  onPressed: () => _showNewWaterAnalysisDialog(context),
                  icon: const Icon(Icons.add_chart_rounded, size: 16),
                  label: const Text(
                    'Registrar Laudo',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Limites Legais de Referência: pH 6,0 a 9,0 • Turbidez ≤ 100 UNT • OD ≥ 5,0 mg/L • DBO₅,₂₀ ≤ 5,0 mg/L • Fósforo Total ≤ 0,050 mg/L • Coliformes Termotolerantes ≤ 1.000 NMP/100mL.',
            style: TextStyle(color: Color(0xFFE1F5FE), fontSize: 11.5, height: 1.35),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 6,
            children: [
              _buildMetricPill(
                label: 'Laudos Analisados: $totalCount',
                color: Colors.white.withValues(alpha: 0.18),
              ),
              _buildMetricPill(
                label: 'Conformes CONAMA: $compliantCount',
                color: const Color(0xFF2E7D32),
              ),
              _buildMetricPill(
                label: 'Com Violação CONAMA: $violationCount',
                color: const Color(0xFFC62828),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetricPill({required String label, required Color color}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  /// Exibe comparativo automático de evolução entre a 1ª Campanha (Linha de Base) e a 2ª Campanha (Pós-Manejo) (AM-07).
  Widget _buildHistoricalWaterComparisonCard() {
    final targetPointId =
        _selectedPointFilter == 'TODOS' ? 'pt-muda-01' : _selectedPointFilter;
    final point = widget.appState.getPointById(targetPointId);
    final pointAnalyses = widget.appState.getWaterAnalysesForPoint(targetPointId);

    if (point == null || pointAnalyses.length < 2) {
      return const SizedBox.shrink();
    }

    // Ordena cronologicamente: mais antiga (Linha de Base) vs mais recente (Atual)
    final baseline = pointAnalyses.last;
    final current = pointAnalyses.first;

    final turbDiffPct = baseline.turbidityUnt > 0
        ? ((baseline.turbidityUnt - current.turbidityUnt) /
                baseline.turbidityUnt) *
            100
        : 0.0;
    final odGain = current.dissolvedOxygenMgL - baseline.dissolvedOxygenMgL;

    return Card(
      key: const Key('historical_water_comparison_card'),
      elevation: 0,
      color: const Color(0xFFF0F7FA),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: Color(0xFFB3E5FC)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.compare_arrows_rounded,
                  color: Color(0xFF0277BD),
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Comparativo Histórico Entre Campanhas — ${point.code} (${point.name})',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF01579B),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Evolução Hidrossedimentológica (${baseline.sampleDate} → ${current.sampleDate}): '
              'Redução de Turbidez de ${turbDiffPct.toStringAsFixed(1)}% (${baseline.turbidityUnt} → ${current.turbidityUnt} UNT) • '
              'Ganho de Oxigênio Dissolvido de +${odGain.toStringAsFixed(1)} mg/L (${baseline.dissolvedOxygenMgL} → ${current.dissolvedOxygenMgL} mg/L) • '
              'Vazão: ${baseline.flowRateLs} → ${current.flowRateLs} L/s.',
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF263238),
                height: 1.35,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWaterAnalysisCard(WaterQualityAnalysis analysis, AppUser user) {
    final point = widget.appState.getPointById(analysis.pointId);
    final project = widget.appState.getProjectById(analysis.projectId);
    final isCompliant = analysis.isConamaCompliant;
    final violations = analysis.violations;

    return Card(
      key: Key('water_analysis_card_${analysis.id}'),
      margin: const EdgeInsets.only(bottom: 14),
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: isCompliant ? const Color(0xFFC8E6C9) : const Color(0xFFFFCDD2),
          width: 1.4,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Cabeçalho com código do laudo e Badge CONAMA 357/2005
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${analysis.reportCode} • ${analysis.campaignName}',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF16301D),
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'Ponto: ${point?.code ?? analysis.pointId} — ${point?.name ?? ""} (${project?.programType ?? ""})',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF455A64),
                        ),
                      ),
                      Text(
                        'Coleta: ${analysis.sampleDate} • Lab: ${analysis.laboratoryName} • Vazão: ${analysis.flowRateLs} L/s',
                        style: const TextStyle(
                          fontSize: 11.5,
                          color: Color(0xFF607D8B),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: isCompliant
                        ? const Color(0xFFE8F5E9)
                        : const Color(0xFFFFEBEE),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isCompliant
                          ? const Color(0xFF2E7D32)
                          : const Color(0xFFC62828),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isCompliant
                            ? Icons.verified_rounded
                            : Icons.warning_amber_rounded,
                        size: 14,
                        color: isCompliant
                            ? const Color(0xFF2E7D32)
                            : const Color(0xFFC62828),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        analysis.complianceStatusLabel,
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w800,
                          color: isCompliant
                              ? const Color(0xFF1B5E20)
                              : const Color(0xFFB71C1C),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Grade dos 6 Parâmetros CONAMA 357/2005 com indicadores visuais individuais
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildParameterChip(
                  label: 'pH',
                  value: analysis.ph.toStringAsFixed(1),
                  refLimit: '6,0–9,0',
                  ok: Conama357Limits.isPhCompliant(analysis.ph),
                ),
                _buildParameterChip(
                  label: 'Turbidez',
                  value: '${analysis.turbidityUnt.toStringAsFixed(1)} UNT',
                  refLimit: '≤ 100 UNT',
                  ok: Conama357Limits.isTurbidityCompliant(analysis.turbidityUnt),
                ),
                _buildParameterChip(
                  label: 'OD',
                  value: '${analysis.dissolvedOxygenMgL.toStringAsFixed(1)} mg/L',
                  refLimit: '≥ 5,0 mg/L',
                  ok: Conama357Limits.isOdCompliant(analysis.dissolvedOxygenMgL),
                ),
                _buildParameterChip(
                  label: 'DBO₅,₂₀',
                  value: '${analysis.dboMgL.toStringAsFixed(1)} mg/L',
                  refLimit: '≤ 5,0 mg/L',
                  ok: Conama357Limits.isDboCompliant(analysis.dboMgL),
                ),
                _buildParameterChip(
                  label: 'Fósforo Total',
                  value: '${analysis.totalPhosphorusMgL.toStringAsFixed(3)} mg/L',
                  refLimit: '≤ 0,050 mg/L',
                  ok: Conama357Limits.isPhosphorusCompliant(
                    analysis.totalPhosphorusMgL,
                  ),
                ),
                _buildParameterChip(
                  label: 'Coliformes',
                  value: '${analysis.thermotolerantColiformsNmp} NMP',
                  refLimit: '≤ 1000/100mL',
                  ok: Conama357Limits.isColiformsCompliant(
                    analysis.thermotolerantColiformsNmp,
                  ),
                ),
              ],
            ),

            if (violations.isNotEmpty) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF3E0),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFFFB74D)),
                ),
                child: Text(
                  'Violações CONAMA 357/2005 detectadas: ${violations.join(" • ")}',
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFFE65100),
                  ),
                ),
              ),
            ],

            const SizedBox(height: 10),
            Text(
              'Parecer Técnico: ${analysis.technicalConclusion}',
              style: const TextStyle(fontSize: 12, color: Color(0xFF37474F)),
            ),
            const SizedBox(height: 8),

            // Controle de Sigilo do Laudo Laboratorial (AM-01)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: analysis.isConfidentialReport && !user.canViewConfidentialData
                    ? const Color(0xFFFFF8E1)
                    : const Color(0xFFF4F7F5),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFD5E2D9)),
              ),
              child: Row(
                children: [
                  Icon(
                    analysis.isConfidentialReport && !user.canViewConfidentialData
                        ? Icons.lock_rounded
                        : Icons.verified_user_rounded,
                    size: 15,
                    color: analysis.isConfidentialReport && !user.canViewConfidentialData
                        ? const Color(0xFFEF6C00)
                        : const Color(0xFF1B5E20),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      analysis.isConfidentialReport && !user.canViewConfidentialData
                          ? 'LAUDO LABORATORIAL RESTRITO PROTEGIDO (AM-01): Notas jurídicas/periciais ocultadas para o perfil Empresa Contratante.'
                          : analysis.confidentialLabNotes,
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF263238),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildParameterChip({
    required String label,
    required String value,
    required String refLimit,
    required bool ok,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: ok ? const Color(0xFFF1F8E9) : const Color(0xFFFFEBEE),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: ok ? const Color(0xFF81C784) : const Color(0xFFE57373),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                ok ? Icons.check_circle_rounded : Icons.error_rounded,
                size: 13,
                color: ok ? const Color(0xFF2E7D32) : const Color(0xFFC62828),
              ),
              const SizedBox(width: 4),
              Text(
                '$label: $value',
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                  color: ok ? const Color(0xFF1B5E20) : const Color(0xFFB71C1C),
                ),
              ),
            ],
          ),
          Text(
            'Ref: $refLimit',
            style: const TextStyle(fontSize: 10, color: Color(0xFF546E7A)),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // SEÇÃO 2: UNIDADES MODELO DE CONSERVAÇÃO DO SOLO (AM-10)
  // ===========================================================================
  Widget _buildSoilConservationSection(BuildContext context, AppUser user) {
    final units = widget.appState.soilUnits;
    final totalAbatement = units.fold<double>(
      0.0,
      (sum, u) => sum + (u.erosionAbatementTonHaYear * u.areaHa),
    );
    final avgCover = units.isEmpty
        ? 0.0
        : units.fold<double>(0.0, (sum, u) => sum + u.vegetalCoverPercent) /
            units.length;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Banner Consolidado de Conservação do Solo (AM-10)
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF3E2723), Color(0xFF5D4037)],
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.landscape_rounded,
                    color: Color(0xFFD7CCC8),
                    size: 22,
                  ),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Unidades Modelo de Conservação do Solo (AM-10)',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  if (user.canRegisterFieldData)
                    FilledButton.icon(
                      key: const Key('open_new_soil_unit_dialog_button'),
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFFA5D6A7),
                        foregroundColor: const Color(0xFF1B5E20),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                      ),
                      onPressed: () => _showNewSoilUnitDialog(context),
                      icon: const Icon(Icons.add_circle_outline_rounded, size: 16),
                      label: const Text(
                        'Nova Unidade Modelo',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              const Text(
                'Monitoramento de práticas conservacionistas (plantio direto, terraceamento, adubação verde, cercamento de APP, curvas de nível/barraginhas) e cálculo de abatimento de erosão hídrica pela Equação Universal de Perda de Solo (USLE).',
                style: TextStyle(
                  color: Color(0xFFEFEBE9),
                  fontSize: 11.5,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 10,
                runSpacing: 6,
                children: [
                  _buildMetricPill(
                    label: 'Unidades Modelo: ${units.length}',
                    color: Colors.white.withValues(alpha: 0.18),
                  ),
                  _buildMetricPill(
                    label: 'Cobertura Vegetal Média: ${avgCover.toStringAsFixed(1)}%',
                    color: const Color(0xFF2E7D32),
                  ),
                  _buildMetricPill(
                    label:
                        'Sedimentos Retidos Total: ${totalAbatement.toStringAsFixed(0)} t/ano',
                    color: const Color(0xFF0277BD),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        ...units.map((unit) => _buildSoilUnitCard(unit, user)),
      ],
    );
  }

  Widget _buildSoilUnitCard(SoilConservationUnit unit, AppUser user) {
    final prop = widget.appState.getPropertyById(unit.propertyId);
    final pt = widget.appState.getPointById(unit.pointId);

    return Card(
      key: Key('soil_unit_card_${unit.id}'),
      margin: const EdgeInsets.only(bottom: 14),
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: Color(0xFFD7CCC8)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${unit.code} — ${unit.name}',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF3E2723),
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'Propriedade: ${prop?.name ?? unit.propertyId} • Ponto: ${pt?.code ?? unit.pointId} • Área: ${unit.areaHa} ha',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF5D4037),
                        ),
                      ),
                      Text(
                        'Classe de Solo: ${unit.soilClass} • Declividade Média: ${unit.slopePercent}% • Avaliação: ${unit.lastEvaluationDate}',
                        style: const TextStyle(
                          fontSize: 11.5,
                          color: Color(0xFF6D4C41),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8F5E9),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF2E7D32)),
                  ),
                  child: Text(
                    'Nível: ${unit.conservationLevel}',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF1B5E20),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Indicadores Quantitativos de Conservação do Solo (AM-10)
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildSoilIndicatorBox(
                  title: 'Cobertura Vegetal',
                  value: '${unit.vegetalCoverPercent.toStringAsFixed(1)}%',
                  subtitle: 'Meta PSA ≥ 80%',
                  color: const Color(0xFF2E7D32),
                ),
                _buildSoilIndicatorBox(
                  title: 'Abatimento de Erosão',
                  value:
                      '${unit.erosionAbatementTonHaYear.toStringAsFixed(1)} t/ha/ano',
                  subtitle:
                      'Redução de ${unit.erosionReductionPercent.toStringAsFixed(1)}% (${unit.baselineErosionTonHaYear} → ${unit.currentErosionTonHaYear})',
                  color: const Color(0xFF0277BD),
                ),
                _buildSoilIndicatorBox(
                  title: 'Bacias de Contenção',
                  value: '${unit.infiltrationBasinsCount} unid.',
                  subtitle: 'Barraginhas ativas',
                  color: const Color(0xFF6A1B9A),
                ),
              ],
            ),
            const SizedBox(height: 10),

            const Text(
              'Práticas Conservacionistas Adotadas (AM-10):',
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w800,
                color: Color(0xFF3E2723),
              ),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: unit.adoptedPractices
                  .map(
                    (practice) => Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFEBE9),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFBCAAA4)),
                      ),
                      child: Text(
                        '✓ $practice',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF4E342E),
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 10),
            Text(
              'Diagnóstico Agronômico: ${unit.technicalNotes}',
              style: const TextStyle(fontSize: 12, color: Color(0xFF37474F)),
            ),
            const SizedBox(height: 8),

            // Controle de Sigilo do Termo do Proprietário Rural (AM-01)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: !user.canViewConfidentialData
                    ? const Color(0xFFFFF8E1)
                    : const Color(0xFFF4F7F5),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFD5E2D9)),
              ),
              child: Row(
                children: [
                  Icon(
                    !user.canViewConfidentialData
                        ? Icons.lock_rounded
                        : Icons.verified_user_rounded,
                    size: 15,
                    color: !user.canViewConfidentialData
                        ? const Color(0xFFEF6C00)
                        : const Color(0xFF1B5E20),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      !user.canViewConfidentialData
                          ? 'ACORDO INDIVIDUAL E CAR/CPF RESTRITOS (AM-01): Valores de incentivo e dados pessoais ocultados para o perfil Empresa Contratante.'
                          : unit.confidentialOwnerAgreement,
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF263238),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSoilIndicatorBox({
    required String title,
    required String value,
    required String subtitle,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w900,
              color: color,
            ),
          ),
          Text(
            subtitle,
            style: const TextStyle(fontSize: 10, color: Color(0xFF546E7A)),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // MODAL DE CADASTRO DE NOVO LAUDO DE ÁGUA CONAMA 357/2005 (AM-07)
  // ===========================================================================
  void _showNewWaterAnalysisDialog(BuildContext context) {
    final points = widget.appState.collectionPoints;
    CollectionPoint selectedPoint = points.first;
    final codeCtrl = TextEditingController(text: 'LAUDO-CONAMA-2026/125');
    final campaignCtrl = TextEditingController(
      text: '3ª Campanha — Monitoramento Trimestral',
    );
    final phCtrl = TextEditingController(text: '7.0');
    final turbCtrl = TextEditingController(text: '12.5');
    final odCtrl = TextEditingController(text: '7.6');
    final dboCtrl = TextEditingController(text: '2.4');
    final phosCtrl = TextEditingController(text: '0.030');
    final colifCtrl = TextEditingController(text: '190');
    final conclusionCtrl = TextEditingController(
      text: 'Amostra coletada em condições normais de vazão sem indícios de contaminação.',
    );
    bool isConfidential = false;
    String? errorMsg;

    showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          key: const Key('new_water_analysis_dialog'),
          title: const Text(
            'Novo Laudo de Água CONAMA 357/2005 (AM-07)',
            style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w800),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (errorMsg != null)
                  Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(8),
                    color: const Color(0xFFFFEBEE),
                    child: Text(
                      errorMsg!,
                      style: const TextStyle(
                        color: Color(0xFFC62828),
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                DropdownButtonFormField<CollectionPoint>(
                  initialValue: selectedPoint,
                  decoration: const InputDecoration(
                    labelText: 'Ponto de Coleta Hidrológica',
                    isDense: true,
                  ),
                  items: points
                      .map(
                        (p) => DropdownMenuItem(
                          value: p,
                          child: Text('${p.code} — ${p.name}',
                              overflow: TextOverflow.ellipsis),
                        ),
                      )
                      .toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setDialogState(() => selectedPoint = val);
                    }
                  },
                ),
                const SizedBox(height: 8),
                TextField(
                  key: const Key('water_input_report_code'),
                  controller: codeCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Código do Laudo Laboratorial',
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  key: const Key('water_input_campaign'),
                  controller: campaignCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Campanha / Ciclo de Coleta',
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        key: const Key('water_input_ph'),
                        controller: phCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'pH (6,0–9,0)',
                          isDense: true,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        key: const Key('water_input_turbidity'),
                        controller: turbCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Turbidez (≤100 UNT)',
                          isDense: true,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        key: const Key('water_input_od'),
                        controller: odCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'OD (≥5,0 mg/L)',
                          isDense: true,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        key: const Key('water_input_dbo'),
                        controller: dboCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'DBO (≤5,0 mg/L)',
                          isDense: true,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        key: const Key('water_input_phosphorus'),
                        controller: phosCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Fósforo (≤0,05 mg/L)',
                          isDense: true,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        key: const Key('water_input_coliforms'),
                        controller: colifCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Coliformes (≤1000)',
                          isDense: true,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                TextField(
                  key: const Key('water_input_conclusion'),
                  controller: conclusionCtrl,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Parecer Técnico Hidrológico',
                    isDense: true,
                  ),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text(
                    'Laudo Restrito / Sigiloso (AM-01)',
                    style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
                  ),
                  value: isConfidential,
                  onChanged: (v) => setDialogState(() => isConfidential = v),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              key: const Key('save_water_analysis_submit_button'),
              onPressed: () async {
                final ph = double.tryParse(phCtrl.text.replaceAll(',', '.'));
                final turb = double.tryParse(turbCtrl.text.replaceAll(',', '.'));
                final od = double.tryParse(odCtrl.text.replaceAll(',', '.'));
                final dbo = double.tryParse(dboCtrl.text.replaceAll(',', '.'));
                final phos = double.tryParse(phosCtrl.text.replaceAll(',', '.'));
                final colif = int.tryParse(colifCtrl.text.trim());

                if (ph == null ||
                    ph < 0 ||
                    ph > 14 ||
                    turb == null ||
                    turb < 0 ||
                    od == null ||
                    od < 0 ||
                    dbo == null ||
                    dbo < 0 ||
                    phos == null ||
                    phos < 0 ||
                    colif == null ||
                    colif < 0) {
                  setDialogState(() {
                    errorMsg =
                        'Valores físico-químicos inválidos. Verifique pH (0–14) e parâmetros não-negativos.';
                  });
                  return;
                }

                await widget.appState.saveWaterQualityAnalysis(
                  projectId: selectedPoint.projectId,
                  propertyId: selectedPoint.propertyId,
                  pointId: selectedPoint.id,
                  reportCode: codeCtrl.text.trim(),
                  sampleDate: '06/11/2026',
                  campaignName: campaignCtrl.text.trim(),
                  laboratoryName: 'LabHidro Ambiental Credenciado',
                  ph: ph,
                  turbidityUnt: turb,
                  dissolvedOxygenMgL: od,
                  dboMgL: dbo,
                  totalPhosphorusMgL: phos,
                  thermotolerantColiformsNmp: colif,
                  waterTemperatureC: 19.5,
                  flowRateLs: 4.1,
                  technicalConclusion: conclusionCtrl.text.trim(),
                  isConfidentialReport: isConfidential,
                  confidentialLabNotes: isConfidential
                      ? 'LAUDO RESTRITO (AM-01): Registrado em vistoria técnica de auditoria.'
                      : 'Laudo público de monitoramento regular.',
                );
                if (ctx.mounted) Navigator.of(ctx).pop();
              },
              child: const Text('Salvar Laudo CONAMA'),
            ),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // MODAL DE CADASTRO DE NOVA UNIDADE MODELO DE CONSERVAÇÃO DO SOLO (AM-10)
  // ===========================================================================
  void _showNewSoilUnitDialog(BuildContext context) {
    final properties = widget.appState.properties;
    RuralProperty selectedProp = properties.first;
    final codeCtrl = TextEditingController(text: 'UMCS-RP-02');
    final nameCtrl = TextEditingController(
      text: 'Unidade Demonstrativa Curvas de Nível & Adubação Verde',
    );
    final areaCtrl = TextEditingController(text: '28.5');
    final coverCtrl = TextEditingController(text: '89.0');
    final baseErosionCtrl = TextEditingController(text: '16.5');
    final currErosionCtrl = TextEditingController(text: '2.1');
    final basinsCtrl = TextEditingController(text: '10');
    final notesCtrl = TextEditingController(
      text: 'Implantação de terraços em base larga e consórcio de cobertura vegetal.',
    );
    final selectedPractices = <String>{
      'Plantio Direto na Palha',
      'Terraceamento em Nível',
      'Adubação Verde e Cobertura Morta',
    };
    String? errorMsg;

    showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          key: const Key('new_soil_unit_dialog'),
          title: const Text(
            'Nova Unidade Modelo de Solo (AM-10)',
            style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w800),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (errorMsg != null)
                  Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(8),
                    color: const Color(0xFFFFEBEE),
                    child: Text(
                      errorMsg!,
                      style: const TextStyle(
                        color: Color(0xFFC62828),
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                DropdownButtonFormField<RuralProperty>(
                  initialValue: selectedProp,
                  decoration: const InputDecoration(
                    labelText: 'Propriedade Rural Vinculada',
                    isDense: true,
                  ),
                  items: properties
                      .map(
                        (p) => DropdownMenuItem(
                          value: p,
                          child: Text(p.name, overflow: TextOverflow.ellipsis),
                        ),
                      )
                      .toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setDialogState(() => selectedProp = val);
                    }
                  },
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        key: const Key('soil_input_code'),
                        controller: codeCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Código Unidade',
                          isDense: true,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        key: const Key('soil_input_area'),
                        controller: areaCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Área (ha)',
                          isDense: true,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                TextField(
                  key: const Key('soil_input_name'),
                  controller: nameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Nome da Unidade Demonstrativa',
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        key: const Key('soil_input_cover'),
                        controller: coverCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Cobertura Vegetal (%)',
                          isDense: true,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        key: const Key('soil_input_basins'),
                        controller: basinsCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Nº Barraginhas',
                          isDense: true,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        key: const Key('soil_input_base_erosion'),
                        controller: baseErosionCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Erosão Base (t/ha/ano)',
                          isDense: true,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        key: const Key('soil_input_curr_erosion'),
                        controller: currErosionCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Erosão Atual (t/ha/ano)',
                          isDense: true,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                const Text(
                  'Práticas Conservacionistas Adotadas:',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: SoilConservationUnit.standardPractices.map((prac) {
                    final isSel = selectedPractices.contains(prac);
                    return FilterChip(
                      label: Text(prac, style: const TextStyle(fontSize: 10.5)),
                      selected: isSel,
                      onSelected: (v) {
                        setDialogState(() {
                          if (v) {
                            selectedPractices.add(prac);
                          } else if (selectedPractices.length > 1) {
                            selectedPractices.remove(prac);
                          }
                        });
                      },
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              key: const Key('save_soil_unit_submit_button'),
              onPressed: () async {
                final area = double.tryParse(areaCtrl.text.replaceAll(',', '.'));
                final cover = double.tryParse(coverCtrl.text.replaceAll(',', '.'));
                final baseEr =
                    double.tryParse(baseErosionCtrl.text.replaceAll(',', '.'));
                final currEr =
                    double.tryParse(currErosionCtrl.text.replaceAll(',', '.'));
                final basins = int.tryParse(basinsCtrl.text.trim()) ?? 0;

                if (area == null ||
                    area <= 0 ||
                    cover == null ||
                    cover < 0 ||
                    cover > 100 ||
                    baseEr == null ||
                    baseEr < 0 ||
                    currEr == null ||
                    currEr < 0) {
                  setDialogState(() {
                    errorMsg =
                        'Verifique a área (>0), cobertura vegetal (0–100%) e taxas de erosão (≥0).';
                  });
                  return;
                }

                final propPoints =
                    widget.appState.getPointsForProperty(selectedProp.id);
                final pointId = propPoints.isNotEmpty
                    ? propPoints.first.id
                    : widget.appState.collectionPoints.first.id;

                await widget.appState.saveSoilConservationUnit(
                  projectId: selectedProp.projectId,
                  propertyId: selectedProp.id,
                  pointId: pointId,
                  code: codeCtrl.text.trim(),
                  name: nameCtrl.text.trim(),
                  areaHa: area,
                  soilClass: selectedProp.mainSoilType,
                  slopePercent: 12.0,
                  adoptedPractices: selectedPractices.toList(),
                  vegetalCoverPercent: cover,
                  baselineErosionTonHaYear: baseEr,
                  currentErosionTonHaYear: currEr,
                  infiltrationBasinsCount: basins,
                  conservationLevel: cover >= 85 ? 'Excelente' : 'Adequado',
                  lastEvaluationDate: '06/11/2026',
                  technicalNotes: notesCtrl.text.trim(),
                  confidentialOwnerAgreement:
                      'ACORDO SIGILOSO (AM-01): Proprietário ${selectedProp.ownerName} (CPF ${selectedProp.ownerCpf} / CAR ${selectedProp.carRegistryCode}).',
                );
                if (ctx.mounted) Navigator.of(ctx).pop();
              },
              child: const Text('Salvar Unidade Modelo'),
            ),
          ],
        ),
      ),
    );
  }
}
