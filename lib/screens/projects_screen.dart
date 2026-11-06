import 'package:flutter/material.dart';
import '../models/project_models.dart';
import '../models/user_profile.dart';
import '../state/app_state.dart';

/// Módulo de Consulta de Projetos Muda e PSA, Propriedades, Áreas, Etapas,
/// Cronogramas e Documentos Autorizados (AM-02) com proteção de sigilo por perfil (AM-01).
class ProjectsScreen extends StatelessWidget {
  final AppState appState;

  const ProjectsScreen({
    super.key,
    required this.appState,
  });

  @override
  Widget build(BuildContext context) {
    final user = appState.currentUser!;
    final filteredProjects = appState.filteredProjects;

    return Column(
      children: [
        _buildFilterAndSearchHeader(context, user),
        Expanded(
          child: filteredProjects.isEmpty
              ? _buildEmptyState()
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  itemCount: filteredProjects.length,
                  itemBuilder: (context, index) {
                    final project = filteredProjects[index];
                    final projectProps =
                        appState.getPropertiesForProject(project.id);
                    final projectPoints =
                        appState.getPointsForProject(project.id);
                    return _buildProjectCard(
                      context,
                      project: project,
                      properties: projectProps,
                      points: projectPoints,
                      currentUser: user,
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildFilterAndSearchHeader(BuildContext context, AppUser user) {
    final selectedFilter = appState.selectedProgramFilter;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: Color(0xFFE0E8E2)),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Banner de escopo de permissão de sigilo (AM-01)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: user.canViewConfidentialData
                  ? const Color(0xFFE8F5E9)
                  : const Color(0xFFFFF3E0),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: user.canViewConfidentialData
                    ? const Color(0xFFA5D6A7)
                    : const Color(0xFFFFCC80),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  user.canViewConfidentialData
                      ? Icons.lock_open_rounded
                      : Icons.privacy_tip_rounded,
                  size: 18,
                  color: user.canViewConfidentialData
                      ? const Color(0xFF1B5E20)
                      : const Color(0xFFE65100),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    user.canViewConfidentialData
                        ? 'Perfil ${user.role.label}: Acesso autorizado a Dados Abertos + Dados Sigilosos (CPF, CAR, Contratos e Repasses PSA).'
                        : 'Perfil ${user.role.label}: Visualizando Dados Abertos. Dados sigilosos (CPF, CAR, Repasses PSA e Termos Restritos) estão protegidos (AM-01).',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: user.canViewConfidentialData
                          ? const Color(0xFF1B5E20)
                          : const Color(0xFFE65100),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextField(
                  key: const Key('project_search_field'),
                  onChanged: appState.setSearchQuery,
                  decoration: InputDecoration(
                    hintText:
                        'Buscar por projeto, bacia, município ou propriedade...',
                    prefixIcon: const Icon(Icons.search_rounded, size: 20),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    filled: true,
                    fillColor: const Color(0xFFF5F8F6),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Color(0xFFD5E0D8)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Color(0xFFD5E0D8)),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildFilterChip(
                  label: 'Todos os Programas (${appState.projects.length})',
                  value: 'TODOS',
                  selectedValue: selectedFilter,
                ),
                const SizedBox(width: 8),
                _buildFilterChip(
                  label: 'Programa Muda (Recomposição)',
                  value: 'MUDA',
                  selectedValue: selectedFilter,
                ),
                const SizedBox(width: 8),
                _buildFilterChip(
                  label: 'Programa PSA (Serviços Ambientais)',
                  value: 'PSA',
                  selectedValue: selectedFilter,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    required String value,
    required String selectedValue,
  }) {
    final isSelected = value == selectedValue;
    return ChoiceChip(
      key: Key('filter_chip_$value'),
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => appState.setProgramFilter(value),
      selectedColor: const Color(0xFF1B5E20),
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : const Color(0xFF2C4233),
        fontWeight: FontWeight.w700,
        fontSize: 12,
      ),
    );
  }

  Widget _buildEmptyState() {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.travel_explore_rounded,
              size: 48,
              color: Color(0xFF789080),
            ),
            SizedBox(height: 12),
            Text(
              'Nenhum projeto encontrado para o filtro selecionado.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: Color(0xFF455A4C),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProjectCard(
    BuildContext context, {
    required EnvironmentalProject project,
    required List<RuralProperty> properties,
    required List<CollectionPoint> points,
    required AppUser currentUser,
  }) {
    final isMuda = project.isMuda;
    final badgeColor =
        isMuda ? const Color(0xFF2E7D32) : const Color(0xFF00695C);

    return Card(
      key: Key('project_card_${project.id}'),
      margin: const EdgeInsets.only(top: 12),
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFFD5E2D9)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _openProjectDetailsModal(
          context,
          project: project,
          properties: properties,
          points: points,
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: badgeColor,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      isMuda ? 'PROJETO MUDA' : 'PROJETO PSA',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 11,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEEF4F0),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      project.code,
                      style: const TextStyle(
                        color: Color(0xFF1B4327),
                        fontWeight: FontWeight.w700,
                        fontSize: 11.5,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE3F2FD),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      project.status,
                      style: const TextStyle(
                        color: Color(0xFF0D47A1),
                        fontWeight: FontWeight.w700,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                project.name,
                style: const TextStyle(
                  fontSize: 16.5,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF16301D),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                project.publicSummary,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12.5,
                  color: Color(0xFF4A6050),
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 12),
              _buildInfoRow(
                Icons.water_drop_outlined,
                'Bacia Hidrográfica:',
                project.watershed,
              ),
              const SizedBox(height: 4),
              _buildInfoRow(
                Icons.location_on_outlined,
                'Município-Polo:',
                project.municipalityHub,
              ),
              const SizedBox(height: 4),
              _buildInfoRow(
                Icons.calendar_month_outlined,
                'Vigência do Cronograma:',
                project.period,
              ),
              const SizedBox(height: 4),
              _buildInfoRow(
                Icons.paid_outlined,
                'Orçamento Contratual:',
                currentUser.formatConfidentialCurrency(
                  project.confidentialTotalBudget,
                ),
                isHighlightedConfidential: !currentUser.canViewConfidentialData,
              ),
              const SizedBox(height: 12),
              // Barra de progresso geral
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Execução Física do Cronograma',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF284230),
                    ),
                  ),
                  Text(
                    '${project.overallProgress.toStringAsFixed(1)}%',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                      color: badgeColor,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: project.overallProgress / 100.0,
                  minHeight: 8,
                  backgroundColor: const Color(0xFFE4ECE7),
                  valueColor: AlwaysStoppedAnimation<Color>(badgeColor),
                ),
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _buildMetricPill(
                    Icons.landscape_rounded,
                    '${properties.length} Propriedades (${project.totalTargetAreaHa} ha)',
                  ),
                  _buildMetricPill(
                    Icons.park_rounded,
                    '${project.targetSeedlingsCount} Mudas',
                  ),
                  _buildMetricPill(
                    Icons.timeline_rounded,
                    '${project.stages.length} Etapas',
                  ),
                  _buildMetricPill(
                    Icons.description_outlined,
                    '${project.documents.length} Documentos',
                  ),
                  _buildMetricPill(
                    Icons.pin_drop_outlined,
                    '${points.length} Pontos de Coleta',
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton.tonalIcon(
                  key: Key('open_project_details_${project.id}'),
                  onPressed: () => _openProjectDetailsModal(
                    context,
                    project: project,
                    properties: properties,
                    points: points,
                  ),
                  icon: const Icon(Icons.folder_open_rounded, size: 18),
                  label: const Text(
                    'Consultar Propriedades, Cronograma e Documentos',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(
    IconData icon,
    String label,
    String value, {
    bool isHighlightedConfidential = false,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          size: 16,
          color: isHighlightedConfidential
              ? const Color(0xFFE65100)
              : const Color(0xFF2E7D32),
        ),
        const SizedBox(width: 6),
        Text(
          '$label ',
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: Color(0xFF2C4233),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: isHighlightedConfidential
                  ? FontWeight.w700
                  : FontWeight.w500,
              color: isHighlightedConfidential
                  ? const Color(0xFFE65100)
                  : const Color(0xFF3E5646),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMetricPill(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFFF2F7F4),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFD7E4DC)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: const Color(0xFF1B5E20)),
          const SizedBox(width: 5),
          Text(
            text,
            style: const TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: Color(0xFF213D29),
            ),
          ),
        ],
      ),
    );
  }

  void _openProjectDetailsModal(
    BuildContext context, {
    required EnvironmentalProject project,
    required List<RuralProperty> properties,
    required List<CollectionPoint> points,
  }) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ProjectDetailScreen(
          appState: appState,
          project: project,
          properties: properties,
          points: points,
        ),
      ),
    );
  }
}

/// Tela de Detalhes Completos do Projeto (AM-02) dividida em 4 abas:
/// 1. Visão Geral & Sigilo
/// 2. Propriedades & Áreas (com Pontos de Coleta)
/// 3. Etapas & Cronograma
/// 4. Documentos Autorizados
class ProjectDetailScreen extends StatelessWidget {
  final AppState appState;
  final EnvironmentalProject project;
  final List<RuralProperty> properties;
  final List<CollectionPoint> points;

  const ProjectDetailScreen({
    super.key,
    required this.appState,
    required this.project,
    required this.properties,
    required this.points,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: appState,
      builder: (context, _) {
        final user = appState.currentUser;
        if (user == null) {
          return const Scaffold(
            body: Center(child: Text('Sessão encerrada.')),
          );
        }

        return DefaultTabController(
          length: 4,
          child: Scaffold(
            backgroundColor: const Color(0xFFF3F7F4),
            appBar: AppBar(
              backgroundColor: const Color(0xFF1B5E20),
              foregroundColor: Colors.white,
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${project.code} • Programa ${project.programType}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFFC8E6C9),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    project.name,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              actions: [
                PopupMenuButton<UserRole>(
                  key: const Key('detail_profile_switcher_menu'),
                  tooltip: 'Alternar Perfil em Tempo Real (AM-01)',
                  onSelected: (role) {
                    appState.quickLoginAsRole(role);
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem<UserRole>(
                      enabled: false,
                      child: Text(
                        'Alternar Perfil (Testar Sigilo AM-01)',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF1B5E20),
                        ),
                      ),
                    ),
                    const PopupMenuDivider(),
                    ...UserRole.values.map(
                      (role) => PopupMenuItem<UserRole>(
                        key: Key('detail_switch_role_${role.name}'),
                        value: role,
                        child: Row(
                          children: [
                            Icon(role.icon, color: role.badgeColor, size: 18),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                role.label,
                                style: TextStyle(
                                  fontWeight: user.role == role
                                      ? FontWeight.w800
                                      : FontWeight.w500,
                                ),
                              ),
                            ),
                            if (user.role == role)
                              const Icon(
                                Icons.check_circle_rounded,
                                color: Color(0xFF2E7D32),
                                size: 16,
                              ),
                          ],
                        ),
                      ),
                    ),
                  ],
                  child: Container(
                    margin: const EdgeInsets.symmetric(
                      vertical: 10,
                      horizontal: 8,
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: user.role.badgeColor,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.5),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(user.role.icon, size: 14, color: Colors.white),
                        const SizedBox(width: 5),
                        Text(
                          user.role.shortBadge,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 2),
                        const Icon(
                          Icons.arrow_drop_down_rounded,
                          size: 16,
                          color: Colors.white,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
              bottom: const TabBar(
                isScrollable: true,
                indicatorColor: Colors.white,
                labelColor: Colors.white,
                unselectedLabelColor: Color(0xFFB9DFC0),
                tabs: [
                  Tab(
                    icon: Icon(Icons.analytics_outlined, size: 18),
                    text: 'Visão Geral & Sigilo',
                  ),
                  Tab(
                    icon: Icon(Icons.landscape_outlined, size: 18),
                    text: 'Propriedades & Áreas',
                  ),
                  Tab(
                    icon: Icon(Icons.event_note_outlined, size: 18),
                    text: 'Etapas & Cronograma',
                  ),
                  Tab(
                    icon: Icon(Icons.verified_outlined, size: 18),
                    text: 'Documentos Autorizados',
                  ),
                ],
              ),
            ),
            body: TabBarView(
              children: [
                _buildOverviewAndConfidentialTab(context, user),
                _buildPropertiesAndAreasTab(context, user),
                _buildStagesAndScheduleTab(context),
                _buildAuthorizedDocumentsTab(context, user),
              ],
            ),
          ),
        );
      },
    );
  }

  // ===========================================================================
  // ABA 1: VISÃO GERAL & DADOS SIGILOSOS (AM-01 + AM-02)
  // ===========================================================================
  Widget _buildOverviewAndConfidentialTab(BuildContext context, AppUser user) {
    final canViewConfidential = user.canViewConfidentialData;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          elevation: 0,
          color: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: const BorderSide(color: Color(0xFFD5E2D9)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Dados Abertos do Projeto (Público / Contratante)',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1B4327),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  project.publicSummary,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF374E3E),
                    height: 1.4,
                  ),
                ),
                const Divider(height: 24),
                _buildDetailKeyValue('Código Oficial:', project.code),
                _buildDetailKeyValue('Modalidade:', 'Programa ${project.programType}'),
                _buildDetailKeyValue('Bacia Hidrográfica:', project.watershed),
                _buildDetailKeyValue('Município-Polo:', project.municipalityHub),
                _buildDetailKeyValue('Vigência:', project.period),
                _buildDetailKeyValue('Status Atual:', project.status),
                _buildDetailKeyValue(
                  'Meta de Área Restaurada/PSA:',
                  '${project.totalTargetAreaHa.toStringAsFixed(1)} hectares',
                ),
                _buildDetailKeyValue(
                  'Meta de Plantio / Enriquecimento:',
                  '${project.targetSeedlingsCount} mudas nativas',
                ),
                _buildDetailKeyValue(
                  'Instituição Financiadora / Parceira:',
                  project.partnerCompany,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        // Bloco de Informações Sigilosas (AM-01)
        Card(
          elevation: 0,
          color: canViewConfidential
              ? const Color(0xFFE8F5E9)
              : const Color(0xFFFFF3E0),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(
              color: canViewConfidential
                  ? const Color(0xFF81C784)
                  : const Color(0xFFFFB74D),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      canViewConfidential
                          ? Icons.verified_user_rounded
                          : Icons.lock_person_rounded,
                      color: canViewConfidential
                          ? const Color(0xFF1B5E20)
                          : const Color(0xFFE65100),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        canViewConfidential
                            ? 'Bloco de Informações Sigilosas (Liberado para ${user.role.label})'
                            : 'Bloco de Informações Sigilosas (Bloqueado para ${user.role.label})',
                        style: TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w800,
                          color: canViewConfidential
                              ? const Color(0xFF1B5E20)
                              : const Color(0xFFE65100),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _buildDetailKeyValue(
                  'Instrumento Contratual Restrito:',
                  user.formatConfidentialText(
                    project.confidentialContractCode,
                    maskedFallback: 'CT-SIG-••••/•••• (Restrito AM-01)',
                  ),
                ),
                _buildDetailKeyValue(
                  'Orçamento Global Detalhado:',
                  user.formatConfidentialCurrency(
                    project.confidentialTotalBudget,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.85),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    canViewConfidential
                        ? project.confidentialTechnicalNotes
                        : '🔒 CONTEÚDO PROTEGIDO (REQUISITO AM-01): As notas jurídicas de passivos ambientais, autuações de referência e cláusulas financeiras individuais são restritas aos perfis Administrador e Equipe Técnica.',
                    style: TextStyle(
                      fontSize: 12.5,
                      height: 1.4,
                      fontWeight: FontWeight.w600,
                      color: canViewConfidential
                          ? const Color(0xFF1B3A24)
                          : const Color(0xFFBF360C),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ===========================================================================
  // ABA 2: PROPRIEDADES RURAIS, ÁREAS E PONTOS DE COLETA (AM-01 + AM-02)
  // ===========================================================================
  Widget _buildPropertiesAndAreasTab(BuildContext context, AppUser user) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: properties.length,
      itemBuilder: (context, index) {
        final prop = properties[index];
        final propPoints = appState.getPointsForProperty(prop.id);

        return Card(
          key: Key('property_card_${prop.id}'),
          margin: const EdgeInsets.only(bottom: 14),
          elevation: 0,
          color: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: const BorderSide(color: Color(0xFFD5E2D9)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1B5E20),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        prop.code,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        prop.name,
                        style: const TextStyle(
                          fontSize: 15.5,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF16301D),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                _buildDetailKeyValue('Município:', prop.municipality),
                _buildDetailKeyValue(
                  'Área Total / Área Monitorada:',
                  '${prop.totalAreaHa} ha totais • ${prop.restorationAreaHa} ha em recomposição/PSA',
                ),
                _buildDetailKeyValue(
                  'Caracterização das Áreas:',
                  prop.areaDescription,
                ),
                _buildDetailKeyValue('Solo Predominante:', prop.mainSoilType),
                _buildDetailKeyValue(
                  'Situação Ambiental:',
                  prop.conservationStatus,
                ),
                _buildDetailKeyValue(
                  'Coordenadas Centróide (SIRGAS/WGS84):',
                  'Lat ${prop.centerLatitude.toStringAsFixed(4)}, Lng ${prop.centerLongitude.toStringAsFixed(4)} (${prop.polygonCoordinates.length} vértices mapeados)',
                ),
                const Divider(height: 22),
                // Seção Sigilosa do Proprietário Rural (AM-01)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: user.canViewConfidentialData
                        ? const Color(0xFFF1F8E9)
                        : const Color(0xFFFFF8E1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: user.canViewConfidentialData
                          ? const Color(0xFFC5E1A5)
                          : const Color(0xFFFFE082),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            user.canViewConfidentialData
                                ? Icons.badge_outlined
                                : Icons.visibility_off_outlined,
                            size: 16,
                            color: user.canViewConfidentialData
                                ? const Color(0xFF2E7D32)
                                : const Color(0xFFE65100),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            user.canViewConfidentialData
                                ? 'Cadastro Fundiário e PSA (Acesso Sigiloso Autorizado)'
                                : 'Cadastro Fundiário e PSA (Protegido por Sigilo LGPD - AM-01)',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: user.canViewConfidentialData
                                  ? const Color(0xFF1B5E20)
                                  : const Color(0xFFE65100),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      _buildDetailKeyValue(
                        'Proprietário Beneficiário:',
                        user.formatConfidentialText(
                          prop.ownerName,
                          maskedFallback:
                              'Produtor Rural Cadastrado (Nome Protegido - LGPD)',
                        ),
                      ),
                      _buildDetailKeyValue(
                        'CPF do Titular:',
                        user.formatConfidentialText(prop.ownerCpf),
                      ),
                      _buildDetailKeyValue(
                        'Registro no CAR:',
                        user.formatConfidentialText(
                          prop.carRegistryCode,
                          maskedFallback: 'RS-•••••••-•••••••••••••••• (Sigiloso)',
                        ),
                      ),
                      _buildDetailKeyValue(
                        'Repasse Mensal PSA / Incentivo:',
                        user.formatConfidentialCurrency(prop.psaMonthlyValue),
                      ),
                      _buildDetailKeyValue(
                        'Domicílio Bancário PSA:',
                        user.formatConfidentialText(
                          prop.bankAccountSummary,
                          maskedFallback: 'Dados Bancários Restritos (AM-01)',
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Pontos de Coleta Georreferenciados na Propriedade (${propPoints.length})',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1B4327),
                  ),
                ),
                const SizedBox(height: 8),
                ...propPoints.map(
                  (pt) => Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF6FAF7),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFDCE7DF)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.location_pin,
                          color: Color(0xFF1B5E20),
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${pt.code} — ${pt.name}',
                                style: const TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF1B3A24),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${pt.pointType} • ${pt.referenceAreaName} • Alt: ${pt.altitudeMeters.toStringAsFixed(0)}m',
                                style: const TextStyle(
                                  fontSize: 11.5,
                                  color: Color(0xFF4E6655),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Coord: ${pt.latitude.toStringAsFixed(4)}, ${pt.longitude.toStringAsFixed(4)} • Última vistoria: ${pt.lastInspectionDate} (${pt.monitoringStatus})',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF2E7D32),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ===========================================================================
  // ABA 3: ETAPAS E CRONOGRAMA DO PROJETO (AM-02)
  // ===========================================================================
  Widget _buildStagesAndScheduleTab(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: project.stages.length,
      itemBuilder: (context, index) {
        final stage = project.stages[index];
        final isDone = stage.status == 'Concluída';
        final isRunning = stage.status == 'Em Andamento';

        final statusColor = isDone
            ? const Color(0xFF2E7D32)
            : isRunning
                ? const Color(0xFF0277BD)
                : const Color(0xFF6D4C41);

        return Card(
          key: Key('stage_card_${stage.id}'),
          margin: const EdgeInsets.only(bottom: 12),
          elevation: 0,
          color: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: const BorderSide(color: Color(0xFFD5E2D9)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: statusColor.withValues(alpha: 0.4),
                        ),
                      ),
                      child: Text(
                        stage.status.toUpperCase(),
                        style: TextStyle(
                          color: statusColor,
                          fontSize: 10.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const Spacer(),
                    const Icon(
                      Icons.date_range_rounded,
                      size: 15,
                      color: Color(0xFF4E6655),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${stage.startDate} até ${stage.endDate}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF374E3E),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  stage.title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF16301D),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  stage.description,
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: Color(0xFF475E4E),
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 10),
                _buildDetailKeyValue(
                  'Equipe Responsável:',
                  stage.responsibleTeam,
                ),
                _buildDetailKeyValue(
                  'Entregável Verificável:',
                  stage.targetDeliverable,
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: LinearProgressIndicator(
                          value: stage.progressPercent / 100.0,
                          minHeight: 7,
                          backgroundColor: const Color(0xFFE4ECE7),
                          valueColor:
                              AlwaysStoppedAnimation<Color>(statusColor),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      '${stage.progressPercent.toStringAsFixed(0)}%',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: statusColor,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ===========================================================================
  // ABA 4: DOCUMENTOS AUTORIZADOS COM CONTROLE DE SIGILO (AM-01 + AM-02)
  // ===========================================================================
  Widget _buildAuthorizedDocumentsTab(BuildContext context, AppUser user) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: project.documents.length,
      itemBuilder: (context, index) {
        final doc = project.documents[index];
        final isLockedForUser =
            doc.isConfidential && !user.canViewConfidentialData;

        return Card(
          key: Key('document_card_${doc.id}'),
          margin: const EdgeInsets.only(bottom: 12),
          elevation: 0,
          color: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(
              color: doc.isConfidential
                  ? const Color(0xFFFFB74D)
                  : const Color(0xFFD5E2D9),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: doc.isConfidential
                            ? const Color(0xFFE65100)
                            : const Color(0xFF1B5E20),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        doc.isConfidential
                            ? 'DOCUMENTO SIGILOSO'
                            : 'DOCUMENTO ABERTO AUTORIZADO',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    Text(
                      '${doc.code} • ${doc.category}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF3E5646),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  doc.title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF16301D),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  doc.summary,
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: Color(0xFF475E4E),
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 8),
                _buildDetailKeyValue(
                  'Emissão / Versão:',
                  '${doc.issueDate} (${doc.version}) • ${doc.fileSize}',
                ),
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isLockedForUser
                        ? const Color(0xFFFFF3E0)
                        : const Color(0xFFF3F8F5),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isLockedForUser
                          ? const Color(0xFFFFCC80)
                          : const Color(0xFFD5E2D9),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        isLockedForUser
                            ? Icons.lock_outline_rounded
                            : Icons.description_outlined,
                        size: 18,
                        color: isLockedForUser
                            ? const Color(0xFFE65100)
                            : const Color(0xFF1B5E20),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          isLockedForUser
                              ? 'ACESSO RESTRITO (AM-01): O perfil "${user.role.label}" possui permissão apenas para documentos abertos. Faça login como Administrador ou Equipe Técnica para inspecionar este documento sigiloso.'
                              : doc.confidentialContent,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: isLockedForUser
                                ? const Color(0xFFBF360C)
                                : const Color(0xFF1B3A24),
                            height: 1.35,
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
      },
    );
  }

  Widget _buildDetailKeyValue(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: Text.rich(
        TextSpan(
          style: const TextStyle(
            fontSize: 12.5,
            color: Color(0xFF263B2D),
            height: 1.35,
          ),
          children: [
            TextSpan(
              text: '$label ',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            TextSpan(
              text: value,
              style: const TextStyle(color: Color(0xFF425949)),
            ),
          ],
        ),
      ),
    );
  }
}
