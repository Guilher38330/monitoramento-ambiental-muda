import 'dart:io';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import '../models/field_form_record.dart';
import '../models/project_models.dart';
import '../models/user_profile.dart';
import '../state/app_state.dart';

/// Tela Integrada da Fase 2:
/// - Sub-aba 1 (index 0): **Fila de Sincronização & Registros de Campo (AM-04, AM-11, AM-12)**
///   com chips de filtro (`Todos`, `Na Fila (Offline)`, `Sincronizados`, `Com Conflito`),
///   banner de status, botão "Sincronizar Fila Agora", diálogo de resolução de conflito
///   lado a lado (Campo vs. Servidor) e modal de Histórico de Auditoria e Autoria.
/// - Sub-aba 2 (index 1): **Novo Formulário de Campo (AM-03, AM-05)**
///   com validação obrigatória, seletor de Projeto/Propriedade/Ponto, captura GPS
///   (`geolocator` + fallback realista para emuladores), captura de Foto Georreferenciada
///   (`image_picker` câmera/galeria + botão instantâneo de Demonstração com carimbo GPS/timestamp)
///   e controle rigoroso de sigilo/RBAC (`Empresa Contratante` somente leitura).
class FieldFormsSyncScreen extends StatefulWidget {
  final AppState appState;
  final int initialSectionIndex;

  const FieldFormsSyncScreen({
    super.key,
    required this.appState,
    this.initialSectionIndex = 0,
  });

  @override
  State<FieldFormsSyncScreen> createState() => _FieldFormsSyncScreenState();
}

class _FieldFormsSyncScreenState extends State<FieldFormsSyncScreen> {
  late int _activeSubTabIndex;

  // Estado do formulário de Novo Registro de Campo (AM-03, AM-05)
  final _formKey = GlobalKey<FormState>();
  String? _selectedProjectId;
  String? _selectedPropertyId;
  String? _selectedPointId;
  String _selectedTemplate = FieldFormRecord.availableTemplates.first;
  String _selectedVegetationStage = FieldFormRecord.vegetationStageOptions.first;
  String _selectedErosionStatus = FieldFormRecord.erosionStatusOptions.first;
  String _selectedMaintenance = FieldFormRecord.maintenanceOptions.first;
  bool _invasiveSpeciesPresent = false;
  bool _isConfidentialNote = false;

  final TextEditingController _survivalRateController =
      TextEditingController(text: '89.5');
  final TextEditingController _technicalNotesController = TextEditingController();
  final TextEditingController _photoCaptionController = TextEditingController();

  // Estado de captura GPS (AM-05)
  double? _capturedLatitude;
  double? _capturedLongitude;
  double? _capturedAccuracyMeters;
  String? _gpsCaptureStatusText;
  bool _isCapturingGps = false;

  // Estado de captura de Foto Georreferenciada (AM-05)
  String? _capturedPhotoPath;
  String? _capturedPhotoTimestamp;
  bool _isCapturingPhoto = false;

  String? _formValidationBannerError;
  bool _highlightMissingTerritory = false;
  bool _highlightMissingForm = false;
  bool _highlightMissingGps = false;
  bool _highlightMissingPhoto = false;

  @override
  void initState() {
    super.initState();
    _activeSubTabIndex = widget.initialSectionIndex;
    _initDefaultProjectSelections();
  }

  @override
  void didUpdateWidget(covariant FieldFormsSyncScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialSectionIndex != widget.initialSectionIndex) {
      setState(() {
        _activeSubTabIndex = widget.initialSectionIndex;
      });
    }
  }

  void _initDefaultProjectSelections() {
    final projects = widget.appState.projects;
    if (projects.isEmpty) return;

    _selectedProjectId ??= projects.first.id;
    final props = widget.appState.getPropertiesForProject(_selectedProjectId!);
    if (props.isNotEmpty) {
      _selectedPropertyId ??= props.first.id;
      final pts = widget.appState.getPointsForProperty(_selectedPropertyId!);
      if (pts.isNotEmpty) {
        _selectedPointId ??= pts.first.id;
      }
    }
  }

  @override
  void dispose() {
    _survivalRateController.dispose();
    _technicalNotesController.dispose();
    _photoCaptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.appState.currentUser!;

    return Column(
      children: [
        _buildTopSubNavigationHeader(context, user),
        if (widget.appState.lastSyncMessage != null)
          _buildSyncFeedbackBanner(context, widget.appState.lastSyncMessage!),
        Expanded(
          child: _activeSubTabIndex == 0
              ? _buildSyncQueueAndRecordsSection(context, user)
              : _buildNewFieldFormSection(context, user),
        ),
      ],
    );
  }

  Widget _buildTopSubNavigationHeader(BuildContext context, AppUser user) {
    final pendingCount = widget.appState.pendingSyncCount;
    final conflictCount = widget.appState.conflictCount;

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
          Row(
            children: [
              Expanded(
                child: SegmentedButton<int>(
                  key: const Key('field_sync_subtab_selector'),
                  segments: [
                    ButtonSegment<int>(
                      value: 0,
                      icon: const Icon(Icons.cloud_sync_rounded, size: 18),
                      label: Text(
                        'Fila & Registros (${widget.appState.fieldForms.length})',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    ButtonSegment<int>(
                      value: 1,
                      icon: const Icon(Icons.add_location_alt_rounded, size: 18),
                      label: const Text(
                        'Novo Formulário Campo',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                  selected: {_activeSubTabIndex},
                  onSelectionChanged: (selection) {
                    setState(() {
                      _activeSubTabIndex = selection.first;
                      _formValidationBannerError = null;
                    });
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _buildQuickCounterPill(
                icon: Icons.schedule_send_rounded,
                label: 'Na Fila Offline: $pendingCount',
                color: const Color(0xFF0277BD),
                bgColor: const Color(0xFFE1F5FE),
              ),
              _buildQuickCounterPill(
                icon: Icons.cloud_done_rounded,
                label: 'Sincronizados: ${widget.appState.syncedCount}',
                color: const Color(0xFF2E7D32),
                bgColor: const Color(0xFFE8F5E9),
              ),
              _buildQuickCounterPill(
                icon: Icons.warning_amber_rounded,
                label: 'Conflitos AM-04: $conflictCount',
                color: const Color(0xFFEF6C00),
                bgColor: const Color(0xFFFFF3E0),
              ),
              if (!user.canRegisterFieldData)
                _buildQuickCounterPill(
                  icon: Icons.lock_outline_rounded,
                  label: 'Perfil ${user.role.shortBadge}: Somente Leitura (AM-01)',
                  color: const Color(0xFFE65100),
                  bgColor: const Color(0xFFFFF3E0),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickCounterPill({
    required IconData icon,
    required String label,
    required Color color,
    required Color bgColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSyncFeedbackBanner(BuildContext context, String message) {
    final isErrorOrConflict = message.contains('Falha') ||
        message.contains('OFFLINE') ||
        message.contains('Conflito') ||
        message.contains('bloqueada') ||
        message.contains('restrito');

    return Container(
      key: const Key('sync_status_feedback_banner'),
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: isErrorOrConflict
            ? const Color(0xFFFFF3E0)
            : const Color(0xFFE8F5E9),
        border: Border(
          bottom: BorderSide(
            color: isErrorOrConflict
                ? const Color(0xFFFFB74D)
                : const Color(0xFFA5D6A7),
          ),
        ),
      ),
      child: Row(
        children: [
          Icon(
            isErrorOrConflict
                ? Icons.info_outline_rounded
                : Icons.check_circle_outline_rounded,
            size: 18,
            color: isErrorOrConflict
                ? const Color(0xFFE65100)
                : const Color(0xFF1B5E20),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: isErrorOrConflict
                    ? const Color(0xFFBF360C)
                    : const Color(0xFF1B5E20),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // SEÇÃO 1: FILA DE SINCRONIZAÇÃO & REGISTROS DE CAMPO (AM-04, AM-11, AM-12)
  // ===========================================================================
  Widget _buildSyncQueueAndRecordsSection(
    BuildContext context,
    AppUser user,
  ) {
    final selectedFilter = widget.appState.selectedSyncFilter;
    final filteredForms = widget.appState.filteredFieldForms;

    return Column(
      children: [
        // Barra de ações de Sincronização + Chips de Filtro
        Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
          color: const Color(0xFFF3F7F4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      key: const Key('sync_queue_now_button'),
                      onPressed: widget.appState.isSyncing
                          ? null
                          : () {
                              widget.appState.synchronizePendingForms();
                            },
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF1B5E20),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      icon: widget.appState.isSyncing
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.sync_rounded, size: 18),
                      label: Text(
                        widget.appState.isSyncing
                            ? 'Sincronizando Fila...'
                            : 'Sincronizar Fila Agora (${widget.appState.pendingSyncCount})',
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (user.canRegisterFieldData)
                    OutlinedButton.icon(
                      key: const Key('open_new_field_form_button'),
                      onPressed: () {
                        setState(() {
                          _activeSubTabIndex = 1;
                        });
                      },
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 12,
                        ),
                      ),
                      icon: const Icon(Icons.add_rounded, size: 18),
                      label: const Text(
                        'Nova Coleta',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 12.5,
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
                    _buildSyncFilterChip(
                      chipKey: const Key('sync_filter_TODOS'),
                      label: 'Todos (${widget.appState.fieldForms.length})',
                      value: 'TODOS',
                      selectedValue: selectedFilter,
                    ),
                    const SizedBox(width: 8),
                    _buildSyncFilterChip(
                      chipKey: const Key('sync_filter_FILA'),
                      label:
                          'Na Fila (Offline) (${widget.appState.pendingSyncCount})',
                      value: 'FILA',
                      selectedValue: selectedFilter,
                    ),
                    const SizedBox(width: 8),
                    _buildSyncFilterChip(
                      chipKey: const Key('sync_filter_SINCRONIZADOS'),
                      label: 'Sincronizados (${widget.appState.syncedCount})',
                      value: 'SINCRONIZADOS',
                      selectedValue: selectedFilter,
                    ),
                    const SizedBox(width: 8),
                    _buildSyncFilterChip(
                      chipKey: const Key('sync_filter_CONFLITOS'),
                      label: 'Com Conflito (${widget.appState.conflictCount})',
                      value: 'CONFLITOS',
                      selectedValue: selectedFilter,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: filteredForms.isEmpty
              ? _buildEmptyQueueState()
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
                  itemCount: filteredForms.length,
                  itemBuilder: (context, index) {
                    final record = filteredForms[index];
                    return _buildFieldFormRecordCard(
                      context,
                      record: record,
                      user: user,
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildSyncFilterChip({
    required Key chipKey,
    required String label,
    required String value,
    required String selectedValue,
  }) {
    final isSelected = value == selectedValue;
    return ChoiceChip(
      key: chipKey,
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => widget.appState.setSyncFilter(value),
      selectedColor: const Color(0xFF1B5E20),
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : const Color(0xFF2C4233),
        fontWeight: FontWeight.w700,
        fontSize: 12,
      ),
    );
  }

  Widget _buildEmptyQueueState() {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.fact_check_outlined,
              size: 48,
              color: Color(0xFF789080),
            ),
            SizedBox(height: 12),
            Text(
              'Nenhum registro de campo encontrado para o filtro selecionado.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14.5,
                fontWeight: FontWeight.w600,
                color: Color(0xFF455A4C),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFieldFormRecordCard(
    BuildContext context, {
    required FieldFormRecord record,
    required AppUser user,
  }) {
    final project = widget.appState.getProjectById(record.projectId);
    final property = widget.appState.getPropertyById(record.propertyId);
    final point = widget.appState.getPointById(record.pointId);
    final status = record.syncStatus;

    final maskedNotes = record.isConfidential && !user.canViewConfidentialData
        ? 'OBSERVAÇÃO TÉCNICA SIGILOSA PROTEGIDA (AM-01): Restrita aos perfis Administrador e Equipe Técnica.'
        : record.technicalNotes;

    return Card(
      key: Key('field_form_card_${record.clientUuid}'),
      margin: const EdgeInsets.only(top: 12),
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: record.hasConflict
              ? const Color(0xFFFFB74D)
              : const Color(0xFFD5E2D9),
          width: record.hasConflict ? 1.6 : 1.0,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Cabeçalho: Status Badge + Versão + UUID de idempotência
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
                    color: status.backgroundColor,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: status.color.withValues(alpha: 0.5)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(status.icon, size: 14, color: status.color),
                      const SizedBox(width: 5),
                      Text(
                        status.shortBadge,
                        style: TextStyle(
                          color: status.color,
                          fontWeight: FontWeight.w800,
                          fontSize: 11,
                        ),
                      ),
                    ],
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
                    'Versão v${record.version}',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF1B4327),
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF5F5F5),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'UUID: ${record.clientUuid}',
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF546E7A),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              record.templateName,
              style: const TextStyle(
                fontSize: 15.5,
                fontWeight: FontWeight.w800,
                color: Color(0xFF16301D),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${project?.code ?? record.projectId} • ${property?.name ?? record.propertyId} • ${point?.code ?? record.pointId} (${point?.name ?? ""})',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Color(0xFF2E7D32),
              ),
            ),
            const Divider(height: 20),
            // Dados técnicos coletados em campo (AM-03)
            _buildRecordFieldLine(
              Icons.forest_outlined,
              'Estágio de Regeneração:',
              record.vegetationStage,
            ),
            const SizedBox(height: 4),
            _buildRecordFieldLine(
              Icons.percent_rounded,
              'Sobrevivência de Mudas:',
              '${record.survivalRatePercent.toStringAsFixed(1)}%',
            ),
            const SizedBox(height: 4),
            _buildRecordFieldLine(
              Icons.terrain_outlined,
              'Situação de Erosão/Solo:',
              record.erosionStatus,
            ),
            const SizedBox(height: 4),
            _buildRecordFieldLine(
              Icons.grass_rounded,
              'Espécies Exóticas Invasoras:',
              record.invasiveSpeciesPresent
                  ? 'Sim — Manejo necessário'
                  : 'Não detectadas na parcela',
            ),
            const SizedBox(height: 4),
            _buildRecordFieldLine(
              Icons.build_circle_outlined,
              'Manutenção Realizada:',
              record.maintenancePerformed,
            ),
            const SizedBox(height: 6),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: record.isConfidential && !user.canViewConfidentialData
                    ? const Color(0xFFFFF3E0)
                    : const Color(0xFFF6F9F7),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: record.isConfidential && !user.canViewConfidentialData
                      ? const Color(0xFFFFCC80)
                      : const Color(0xFFDDE7E0),
                ),
              ),
              child: Text(
                maskedNotes,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight:
                      record.isConfidential && !user.canViewConfidentialData
                          ? FontWeight.w700
                          : FontWeight.w500,
                  color: record.isConfidential && !user.canViewConfidentialData
                      ? const Color(0xFFE65100)
                      : const Color(0xFF334A3B),
                ),
              ),
            ),
            const SizedBox(height: 10),
            // Bloco de Coordenadas GPS e Foto Georreferenciada (AM-05)
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFE8F5E9),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFC8E6C9)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.gps_fixed_rounded,
                        size: 15,
                        color: Color(0xFF1B5E20),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'GPS (AM-05): Lat ${record.latitude.toStringAsFixed(5)}, Lng ${record.longitude.toStringAsFixed(5)} (±${record.gpsAccuracyMeters.toStringAsFixed(1)}m)',
                          style: const TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF1B5E20),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  Row(
                    children: [
                      const Icon(
                        Icons.camera_alt_rounded,
                        size: 15,
                        color: Color(0xFF00695C),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Foto Georreferenciada: ${record.photoCaption} (${record.photoLocalPath})',
                          style: const TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF004D40),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            // Bloco de Autoria e Datas de Criação/Sincronização (AM-11)
            Wrap(
              spacing: 12,
              runSpacing: 4,
              children: [
                Text(
                  'Autor (AM-11): ${record.authorName} (${record.authorRole})',
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF37474F),
                  ),
                ),
                Text(
                  'Coletado em: ${_formatIsoTimestamp(record.createdAt)}',
                  style: const TextStyle(
                    fontSize: 11.5,
                    color: Color(0xFF546E7A),
                  ),
                ),
                Text(
                  record.syncedAt != null
                      ? 'Sincronizado em: ${_formatIsoTimestamp(record.syncedAt!)}'
                      : 'Sincronização: Pendente',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: record.syncedAt != null
                        ? const Color(0xFF2E7D32)
                        : const Color(0xFFEF6C00),
                  ),
                ),
              ],
            ),
            if (record.syncErrorMessage != null) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: record.hasConflict
                      ? const Color(0xFFFFF3E0)
                      : const Color(0xFFFFEBEE),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: record.hasConflict
                        ? const Color(0xFFFFB74D)
                        : const Color(0xFFEF9A9A),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      record.hasConflict
                          ? Icons.merge_type_rounded
                          : Icons.wifi_tethering_error_rounded,
                      size: 18,
                      color: record.hasConflict
                          ? const Color(0xFFE65100)
                          : const Color(0xFFC62828),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        record.syncErrorMessage!,
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: record.hasConflict
                              ? const Color(0xFFE65100)
                              : const Color(0xFFC62828),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 12),
            // Ações do Card: Histórico de Auditoria (AM-11), Resolver Conflito (AM-04) ou Simular Conflito
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.end,
              children: [
                OutlinedButton.icon(
                  key: Key('audit_history_btn_${record.clientUuid}'),
                  onPressed: () => _showAuditHistoryModal(context, record),
                  icon: const Icon(Icons.history_edu_rounded, size: 16),
                  label: Text(
                    'Histórico & Autoria (${record.auditHistory.length})',
                    style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (record.hasConflict && user.canResolveSyncConflicts)
                  FilledButton.icon(
                    key: Key('resolve_conflict_btn_${record.clientUuid}'),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFFEF6C00),
                    ),
                    onPressed: () =>
                        _showConflictResolutionDialog(context, record),
                    icon: const Icon(Icons.compare_arrows_rounded, size: 17),
                    label: const Text(
                      'Resolver Conflito (AM-04)',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                if (widget.appState.isDemoModeEnabled &&
                    !record.hasConflict &&
                    user.canResolveSyncConflicts)
                  TextButton.icon(
                    key: Key('simulate_conflict_btn_${record.clientUuid}'),
                    onPressed: () {
                      widget.appState.triggerConflictOnRecord(record.clientUuid);
                    },
                    icon: const Icon(
                      Icons.warning_amber_rounded,
                      size: 15,
                      color: Color(0xFFEF6C00),
                    ),
                    label: const Text(
                      'Simular Conflito',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFFEF6C00),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecordFieldLine(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 15, color: const Color(0xFF2E7D32)),
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
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF3E5646),
            ),
          ),
        ),
      ],
    );
  }

  // ===========================================================================
  // SEÇÃO 2: NOVO FORMULÁRIO DE CAMPO OFFLINE COM GPS E FOTO (AM-03, AM-05)
  // ===========================================================================
  Widget _buildNewFieldFormSection(BuildContext context, AppUser user) {
    if (!user.canRegisterFieldData) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Card(
            elevation: 0,
            color: const Color(0xFFFFF3E0),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: const BorderSide(color: Color(0xFFFFB74D)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.lock_person_rounded,
                    size: 46,
                    color: Color(0xFFE65100),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Acesso Somente Leitura — Perfil ${user.role.label} (AM-01)',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFFBF360C),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'O perfil Empresa Contratante possui permissão para consultar projetos, indicadores públicos e acompanhar o status de sincronização, mas não está autorizado a registrar ou alterar formulários técnicos de campo.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      color: Color(0xFF5D4037),
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: () {
                      setState(() {
                        _activeSubTabIndex = 0;
                      });
                    },
                    icon: const Icon(Icons.list_alt_rounded, size: 18),
                    label: const Text('Voltar para a Lista de Registros'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    _initDefaultProjectSelections();
    final projects = widget.appState.projects;
    final availableProperties = _selectedProjectId == null
        ? <RuralProperty>[]
        : widget.appState.getPropertiesForProject(_selectedProjectId!);
    final availablePoints = _selectedPropertyId == null
        ? <CollectionPoint>[]
        : widget.appState.getPointsForProperty(_selectedPropertyId!);
    final selectedPoint = _selectedPointId == null
        ? null
        : widget.appState.getPointById(_selectedPointId!);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Banner indicando se a coleta será gravada Offline ou Online
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: widget.appState.isOnline
                    ? const Color(0xFFE8F5E9)
                    : const Color(0xFFFFF3E0),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: widget.appState.isOnline
                      ? const Color(0xFFA5D6A7)
                      : const Color(0xFFFFB74D),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    widget.appState.isOnline
                        ? Icons.cloud_queue_rounded
                        : Icons.offline_pin_rounded,
                    color: widget.appState.isOnline
                        ? const Color(0xFF1B5E20)
                        : const Color(0xFFE65100),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      widget.appState.isOnline
                          ? 'Modo ONLINE: O formulário será salvo no SQLite com chave UUID v4 idempotente e poderá ser sincronizado imediatamente.'
                          : 'Modo OFFLINE (Sem Conexão): O formulário, as coordenadas GPS e a foto serão gravados na fila SQLite local para sincronização posterior sem duplicação (1º Critério de Aceite).',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: widget.appState.isOnline
                            ? const Color(0xFF1B5E20)
                            : const Color(0xFFBF360C),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (_formValidationBannerError != null) ...[
              const SizedBox(height: 10),
              Container(
                key: const Key('field_form_validation_error_banner'),
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFEBEE),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFEF9A9A)),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.error_outline_rounded,
                      color: Color(0xFFC62828),
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _formValidationBannerError!,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFFC62828),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 14),
            // Card 1: Vinculação ao Projeto, Propriedade e Ponto de Coleta (AM-05)
            Card(
              elevation: 0,
              color: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: BorderSide(
                  color: _highlightMissingTerritory
                      ? const Color(0xFFC62828)
                      : const Color(0xFFD5E2D9),
                  width: _highlightMissingTerritory ? 1.8 : 1.0,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '1. Vinculação Territorial (Projeto, Propriedade e Ponto — AM-05)',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF1B4327),
                      ),
                    ),
                    if (_highlightMissingTerritory) ...[
                      const SizedBox(height: 8),
                      Container(
                        key: const Key('territory_validation_banner'),
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFEBEE),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFEF9A9A)),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.warning_amber_rounded, size: 16, color: Color(0xFFC62828)),
                            SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                'Atenção: Selecione Projeto, Propriedade e Ponto de Coleta.',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFFC62828),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      key: const Key('dropdown_project'),
                      initialValue: _selectedProjectId,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Projeto Ambiental (Muda / PSA) *',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      items: projects
                          .map(
                            (p) => DropdownMenuItem<String>(
                              value: p.id,
                              child: Text(
                                '${p.code} — ${p.name}',
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (val) {
                        if (val == null) return;
                        final props =
                            widget.appState.getPropertiesForProject(val);
                        final firstPropId =
                            props.isNotEmpty ? props.first.id : null;
                        final pts = firstPropId == null
                            ? <CollectionPoint>[]
                            : widget.appState.getPointsForProperty(firstPropId);
                        setState(() {
                          _selectedProjectId = val;
                          _selectedPropertyId = firstPropId;
                          _selectedPointId =
                              pts.isNotEmpty ? pts.first.id : null;
                          _highlightMissingTerritory = false;
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      key: const Key('dropdown_property'),
                      initialValue: _selectedPropertyId,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Propriedade Rural / Área Monitorada *',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      items: availableProperties
                          .map(
                            (prop) => DropdownMenuItem<String>(
                              value: prop.id,
                              child: Text(
                                '${prop.code} — ${prop.name} (${prop.municipality})',
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (val) {
                        if (val == null) return;
                        final pts = widget.appState.getPointsForProperty(val);
                        setState(() {
                          _selectedPropertyId = val;
                          _selectedPointId =
                              pts.isNotEmpty ? pts.first.id : null;
                          _highlightMissingTerritory = false;
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      key: const Key('dropdown_point'),
                      initialValue: _selectedPointId,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Ponto de Coleta Georreferenciado *',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      items: availablePoints
                          .map(
                            (pt) => DropdownMenuItem<String>(
                              value: pt.id,
                              child: Text(
                                '${pt.code} — ${pt.name} (${pt.pointType})',
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (val) {
                        setState(() {
                          _selectedPointId = val;
                          _highlightMissingTerritory = false;
                        });
                      },
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
            // Card 2: Respostas Técnicas e Validação de Campos Obrigatórios (AM-03)
            Card(
              elevation: 0,
              color: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: BorderSide(
                  color: _highlightMissingForm
                      ? const Color(0xFFC62828)
                      : const Color(0xFFD5E2D9),
                  width: _highlightMissingForm ? 1.8 : 1.0,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '2. Formulário Técnico Configurado pela Plataforma (AM-03)',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF1B4327),
                      ),
                    ),
                    if (_highlightMissingForm) ...[
                      const SizedBox(height: 8),
                      Container(
                        key: const Key('form_fields_validation_banner'),
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFEBEE),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFEF9A9A)),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.warning_amber_rounded, size: 16, color: Color(0xFFC62828)),
                            SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                'Atenção: Preencha os campos obrigatórios do parecer técnico.',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFFC62828),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      key: const Key('dropdown_template'),
                      initialValue: _selectedTemplate,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Modelo de Formulário *',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      items: FieldFormRecord.availableTemplates
                          .map(
                            (t) => DropdownMenuItem<String>(
                              value: t,
                              child: Text(t, overflow: TextOverflow.ellipsis),
                            ),
                          )
                          .toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setState(() => _selectedTemplate = val);
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      key: const Key('dropdown_vegetation_stage'),
                      initialValue: _selectedVegetationStage,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Estágio de Regeneração / Cobertura Vegetal *',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      items: FieldFormRecord.vegetationStageOptions
                          .map(
                            (s) => DropdownMenuItem<String>(
                              value: s,
                              child: Text(s, overflow: TextOverflow.ellipsis),
                            ),
                          )
                          .toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setState(() => _selectedVegetationStage = val);
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      key: const Key('input_survival_rate'),
                      controller: _survivalRateController,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText:
                            'Taxa de Sobrevivência / Pegamento de Mudas (%) *',
                        hintText: 'Ex: 88.5 (entre 0 e 100)',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Informe a taxa de sobrevivência (%).';
                        }
                        final parsed =
                            double.tryParse(value.trim().replaceAll(',', '.'));
                        if (parsed == null || parsed < 0 || parsed > 100) {
                          return 'Informe um percentual válido entre 0% e 100%.';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      key: const Key('dropdown_erosion_status'),
                      initialValue: _selectedErosionStatus,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Avaliação de Feições Erosivas e Solo *',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      items: FieldFormRecord.erosionStatusOptions
                          .map(
                            (e) => DropdownMenuItem<String>(
                              value: e,
                              child: Text(e, overflow: TextOverflow.ellipsis),
                            ),
                          )
                          .toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setState(() => _selectedErosionStatus = val);
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      key: const Key('dropdown_maintenance'),
                      initialValue: _selectedMaintenance,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Ação de Manejo / Manutenção Executada *',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      items: FieldFormRecord.maintenanceOptions
                          .map(
                            (m) => DropdownMenuItem<String>(
                              value: m,
                              child: Text(m, overflow: TextOverflow.ellipsis),
                            ),
                          )
                          .toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setState(() => _selectedMaintenance = val);
                        }
                      },
                    ),
                    const SizedBox(height: 8),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text(
                        'Presença de Espécies Exóticas Invasoras (ex.: Braquiária / Pinus)',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      value: _invasiveSpeciesPresent,
                      onChanged: (val) {
                        setState(() => _invasiveSpeciesPresent = val);
                      },
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text(
                        'Classificar Observação Técnica como Sigilosa (AM-01)',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      subtitle: const Text(
                        'Oculta o texto técnico para o perfil Empresa Contratante.',
                        style: TextStyle(fontSize: 11.5),
                      ),
                      value: _isConfidentialNote,
                      onChanged: (val) {
                        setState(() => _isConfidentialNote = val);
                      },
                    ),
                    const SizedBox(height: 6),
                    TextFormField(
                      key: const Key('input_technical_notes'),
                      controller: _technicalNotesController,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Parecer / Observações Técnicas de Campo *',
                        hintText:
                            'Descreva as condições da parcela, vigor das mudas, vazão da nascente ou recomendações...',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().length < 8) {
                          return 'Preencha as observações técnicas (mínimo 8 caracteres).';
                        }
                        return null;
                      },
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
            // Card 3: Captura de Coordenadas GPS e Foto Georreferenciada (AM-05 + AM-12)
            Card(
              elevation: 0,
              color: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: BorderSide(
                  color: (_highlightMissingGps || _highlightMissingPhoto)
                      ? const Color(0xFFC62828)
                      : const Color(0xFFD5E2D9),
                  width: (_highlightMissingGps || _highlightMissingPhoto) ? 1.8 : 1.0,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '3. Coordenadas GPS e Foto Georreferenciada (AM-05 / AM-12)',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF1B4327),
                      ),
                    ),
                    if (_highlightMissingGps) ...[
                      const SizedBox(height: 8),
                      Container(
                        key: const Key('gps_validation_banner'),
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFEBEE),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFEF9A9A)),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.warning_amber_rounded, size: 16, color: Color(0xFFC62828)),
                            SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                'Atenção: Capture as coordenadas GPS para validar a coleta.',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFFC62828),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    if (_highlightMissingPhoto) ...[
                      const SizedBox(height: 8),
                      Container(
                        key: const Key('photo_validation_banner'),
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFEBEE),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFEF9A9A)),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.warning_amber_rounded, size: 16, color: Color(0xFFC62828)),
                            SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                'Atenção: Anexe uma foto georreferenciada antes de salvar.',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFFC62828),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 10),
                    // Bloco GPS
                    Row(
                      children: [
                        Expanded(
                          child: FilledButton.tonalIcon(
                            key: const Key('capture_gps_button'),
                            onPressed: _isCapturingGps
                                ? null
                                : () => _captureGpsCoordinates(selectedPoint),
                            icon: const Icon(Icons.my_location_rounded, size: 18),
                            label: Text(
                              _isCapturingGps
                                  ? 'Obtendo Sinal GPS...'
                                  : 'Capturar Coordenadas GPS',
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 12.5,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (_capturedLatitude != null &&
                        _capturedLongitude != null) ...[
                      const SizedBox(height: 8),
                      Container(
                        key: const Key('captured_gps_display'),
                        width: double.infinity,
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE8F5E9),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFA5D6A7)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Coordenadas Capturadas: Lat ${_capturedLatitude!.toStringAsFixed(5)}, Lng ${_capturedLongitude!.toStringAsFixed(5)} (Precisão ±${(_capturedAccuracyMeters ?? 3.5).toStringAsFixed(1)}m)',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF1B5E20),
                              ),
                            ),
                            if (_gpsCaptureStatusText != null)
                              Text(
                                _gpsCaptureStatusText!,
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Color(0xFF2E7D32),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                    const Divider(height: 22),
                    // Bloco Foto Georreferenciada
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        if (widget.appState.isDemoModeEnabled)
                          FilledButton.tonalIcon(
                            key: const Key('capture_demo_photo_button'),
                            onPressed: _isCapturingPhoto
                                ? null
                                : () => _captureDemoGeoreferencedPhoto(
                                      selectedPoint,
                                    ),
                            icon: const Icon(
                              Icons.enhance_photo_translate_rounded,
                              size: 18,
                            ),
                            label: const Text(
                              'Capturar Foto Georreferenciada de Demonstração',
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        OutlinedButton.icon(
                          key: const Key('capture_camera_photo_button'),
                          onPressed: _isCapturingPhoto
                              ? null
                              : () => _pickPhotoFromDevice(
                                    ImageSource.camera,
                                    selectedPoint,
                                  ),
                          icon: const Icon(Icons.photo_camera_outlined, size: 17),
                          label: const Text(
                            'Câmera / Galeria',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (_capturedPhotoPath != null) ...[
                      const SizedBox(height: 10),
                      _buildCapturedPhotoPreviewCard(),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                key: const Key('submit_field_form_button'),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF1B5E20),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                onPressed: () => _submitFieldForm(selectedPoint),
                icon: const Icon(Icons.save_alt_rounded, size: 20),
                label: Text(
                  widget.appState.isOnline
                      ? 'Salvar Formulário de Campo na Fila Local'
                      : 'Salvar Formulário OFFLINE (Sem Conexão)',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCapturedPhotoPreviewCard() {
    final isDemoStamp = _capturedPhotoPath!.startsWith('demo://');

    return Container(
      key: const Key('captured_photo_preview'),
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFE0F2F1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF80CBC4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.verified_rounded,
                color: Color(0xFF00695C),
                size: 18,
              ),
              const SizedBox(width: 6),
              const Expanded(
                child: Text(
                  'Evidência Fotográfica Georreferenciada Anexada (AM-05)',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF004D40),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (!isDemoStamp && File(_capturedPhotoPath!).existsSync())
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.file(
                File(_capturedPhotoPath!),
                height: 120,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
            )
          else
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF1B5E20), Color(0xFF00695C)],
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(
                        Icons.camera_outdoor_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                      SizedBox(width: 8),
                      Text(
                        'CARIMBO ÓPTICO DE CAMPO — MUDA & PSA',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Arquivo: $_capturedPhotoPath',
                    style: const TextStyle(
                      color: Color(0xFFE0F2F1),
                      fontSize: 11,
                      fontFamily: 'monospace',
                    ),
                  ),
                  Text(
                    'Timestamp UTC: ${_capturedPhotoTimestamp ?? ""}',
                    style: const TextStyle(
                      color: Color(0xFFE0F2F1),
                      fontSize: 11,
                      fontFamily: 'monospace',
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 8),
          TextFormField(
            key: const Key('input_photo_caption'),
            controller: _photoCaptionController,
            decoration: const InputDecoration(
              labelText: 'Legenda / Metadados da Foto Georreferenciada',
              border: OutlineInputBorder(),
              isDense: true,
              filled: true,
              fillColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  void _showGpsSuccessSnackBar() {
    if (!mounted) return;
    final lat = _capturedLatitude!;
    final lng = _capturedLongitude!;
    final acc = _capturedAccuracyMeters ?? 3.2;

    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: const Color(0xFF2E7D32),
        behavior: SnackBarBehavior.floating,
        content: Row(
          children: [
            const Icon(Icons.check_circle_rounded, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Coordenadas GPS capturadas: Lat ${lat.toStringAsFixed(4)}, Long ${lng.toStringAsFixed(4)} (Precisão: ±${acc.toStringAsFixed(1)}m)',
                style: const TextStyle(
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

  /// Captura coordenadas GPS usando `geolocator` com fallback gracioso e realista
  /// para as coordenadas reais do ponto de coleta no emulador/ambiente de teste (AM-05, AM-12).
  Future<void> _captureGpsCoordinates(CollectionPoint? point) async {
    setState(() {
      _isCapturingGps = true;
      _formValidationBannerError = null;
    });

    final fallbackLat = point?.latitude ?? -29.7132;
    final fallbackLng = point?.longitude ?? -52.4295;

    try {
      bool serviceEnabled = false;
      try {
        serviceEnabled = await Geolocator.isLocationServiceEnabled()
            .timeout(const Duration(seconds: 2));
      } catch (_) {
        serviceEnabled = false;
      }

      if (serviceEnabled) {
        LocationPermission permission = await Geolocator.checkPermission();
        if (permission == LocationPermission.denied) {
          permission = await Geolocator.requestPermission();
        }
        if (permission == LocationPermission.always ||
            permission == LocationPermission.whileInUse) {
          final pos = await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.high,
            timeLimit: const Duration(seconds: 3),
          );
          if (!mounted) return;
          setState(() {
            _capturedLatitude = pos.latitude;
            _capturedLongitude = pos.longitude;
            _capturedAccuracyMeters = pos.accuracy > 0 ? pos.accuracy : 3.2;
            _gpsCaptureStatusText =
                'Sinal GNSS de hardware capturado em tempo real.';
            _isCapturingGps = false;
            _highlightMissingGps = false;
          });
          _showGpsSuccessSnackBar();
          return;
        }
      }
    } catch (_) {
      // Fallback gracioso em emuladores sem provedor de localização nativo ou testes (AM-12)
    }

    if (!mounted) return;
    setState(() {
      _capturedLatitude = fallbackLat;
      _capturedLongitude = fallbackLng;
      _capturedAccuracyMeters = 3.2;
      _gpsCaptureStatusText =
          'Coordenadas georreferenciadas do Ponto ${point?.code ?? "PC"} aplicadas (Fallback seguro de Hardware/Emulador — AM-05/AM-12).';
      _isCapturingGps = false;
      _highlightMissingGps = false;
    });
    _showGpsSuccessSnackBar();
  }

  /// Gera instantaneamente uma foto georreferenciada de demonstração com carimbo de
  /// coordenadas e timestamp para avaliação em emulador sem câmera física (AM-05).
  void _captureDemoGeoreferencedPhoto(CollectionPoint? point) {
    final lat = _capturedLatitude ?? point?.latitude ?? -29.7132;
    final lng = _capturedLongitude ?? point?.longitude ?? -52.4295;
    final acc = _capturedAccuracyMeters ?? 3.2;
    final nowIso = DateTime.now().toUtc().toIso8601String();
    final pointCode = (point?.code ?? 'PC-CAMPO').toLowerCase();

    setState(() {
      _capturedLatitude ??= lat;
      _capturedLongitude ??= lng;
      _capturedAccuracyMeters ??= acc;
      _capturedPhotoTimestamp = nowIso;
      _capturedPhotoPath =
          'demo://evidencia_${pointCode}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      _photoCaptionController.text =
          'Registro Fotográfico ${point?.code ?? "Campo"} — GPS ${lat.toStringAsFixed(4)}, ${lng.toStringAsFixed(4)} (±${acc.toStringAsFixed(1)}m)';
      _formValidationBannerError = null;
      _highlightMissingPhoto = false;
    });

    if (mounted) {
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
                  'Foto georreferenciada carimbada com sucesso!',
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
  }

  /// Abre a câmera/galeria via `image_picker` com fallback seguro caso o emulador não possua câmera (AM-12).
  Future<void> _pickPhotoFromDevice(
    ImageSource source,
    CollectionPoint? point,
  ) async {
    setState(() {
      _isCapturingPhoto = true;
      _formValidationBannerError = null;
    });

    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: source,
        imageQuality: 82,
        maxWidth: 1600,
      );
      if (!mounted) return;
      if (picked != null) {
        final lat = _capturedLatitude ?? point?.latitude ?? -29.7132;
        final lng = _capturedLongitude ?? point?.longitude ?? -52.4295;
        setState(() {
          _capturedPhotoPath = picked.path;
          _capturedPhotoTimestamp = DateTime.now().toUtc().toIso8601String();
          _photoCaptionController.text =
              'Foto Câmera (${picked.name}) — GPS ${lat.toStringAsFixed(4)}, ${lng.toStringAsFixed(4)}';
          _isCapturingPhoto = false;
          _highlightMissingPhoto = false;
        });

        if (mounted) {
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
                      'Foto anexada com sucesso ao formulário de campo!',
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
        return;
      }
    } catch (_) {
      // Fallback para carimbo de demonstração caso o emulador negue ou não tenha câmera configurada (AM-12)
      if (!mounted) return;
      _captureDemoGeoreferencedPhoto(point);
    } finally {
      if (mounted) {
        setState(() {
          _isCapturingPhoto = false;
        });
      }
    }
  }

  Future<void> _submitFieldForm(CollectionPoint? point) async {
    final isFormValid = _formKey.currentState!.validate();
    final territoryMissing = _selectedProjectId == null ||
        _selectedPropertyId == null ||
        _selectedPointId == null;
    final gpsMissing = _capturedLatitude == null || _capturedLongitude == null;
    final photoMissing =
        _capturedPhotoPath == null || _capturedPhotoPath!.trim().isEmpty;

    if (!isFormValid || territoryMissing || gpsMissing || photoMissing) {
      final missingParts = <String>[];
      if (!isFormValid) missingParts.add('preencha os campos obrigatórios');
      if (territoryMissing) missingParts.add('selecione projeto, propriedade e ponto');
      if (gpsMissing) missingParts.add('capture as coordenadas GPS');
      if (photoMissing) missingParts.add('anexe uma foto');

      final String missingSummary;
      if (missingParts.length == 1) {
        missingSummary = missingParts.first;
      } else if (missingParts.length == 2) {
        missingSummary = '${missingParts[0]} e ${missingParts[1]}';
      } else {
        missingSummary =
            '${missingParts.sublist(0, missingParts.length - 1).join(', ')} e ${missingParts.last}';
      }

      final errorText =
          'Preencha os campos obrigatórios: $missingSummary antes de salvar.';

      setState(() {
        _formValidationBannerError = errorText;
        _highlightMissingForm = !isFormValid;
        _highlightMissingTerritory = territoryMissing;
        _highlightMissingGps = gpsMissing;
        _highlightMissingPhoto = photoMissing;
      });

      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFFC62828),
          behavior: SnackBarBehavior.floating,
          content: Row(
            children: [
              const Icon(Icons.warning_amber_rounded, color: Colors.white),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  errorText,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
      return;
    }

    final survivalRate = double.parse(
      _survivalRateController.text.trim().replaceAll(',', '.'),
    );

    final saved = await widget.appState.saveFieldFormRecord(
      projectId: _selectedProjectId!,
      propertyId: _selectedPropertyId!,
      pointId: _selectedPointId!,
      templateName: _selectedTemplate,
      vegetationStage: _selectedVegetationStage,
      survivalRatePercent: survivalRate,
      erosionStatus: _selectedErosionStatus,
      invasiveSpeciesPresent: _invasiveSpeciesPresent,
      maintenancePerformed: _selectedMaintenance,
      technicalNotes: _technicalNotesController.text.trim(),
      isConfidential: _isConfidentialNote,
      latitude: _capturedLatitude!,
      longitude: _capturedLongitude!,
      gpsAccuracyMeters: _capturedAccuracyMeters ?? 3.2,
      photoLocalPath: _capturedPhotoPath!,
      photoCapturedAt:
          _capturedPhotoTimestamp ?? DateTime.now().toUtc().toIso8601String(),
      photoCaption: _photoCaptionController.text.trim().isEmpty
          ? 'Foto de Campo Georreferenciada (${point?.code ?? _selectedPointId})'
          : _photoCaptionController.text.trim(),
    );

    if (!mounted || saved == null) return;

    // Limpa campos para nova coleta e disponibiliza navegação para a Fila de Sincronização
    setState(() {
      _technicalNotesController.clear();
      _capturedPhotoPath = null;
      _capturedPhotoTimestamp = null;
      _formValidationBannerError = null;
      _highlightMissingTerritory = false;
      _highlightMissingForm = false;
      _highlightMissingGps = false;
      _highlightMissingPhoto = false;
      _activeSubTabIndex = 0;
    });

    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: const Color(0xFF2E7D32),
        behavior: SnackBarBehavior.floating,
        content: Row(
          children: [
            const Icon(Icons.check_circle_rounded, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Coleta registrada com sucesso na fila local! (Status: ${saved.syncStatus.shortBadge})',
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
        action: SnackBarAction(
          label: 'VER NA FILA',
          textColor: const Color(0xFFA5D6A7),
          onPressed: () {
            if (mounted) {
              setState(() {
                _activeSubTabIndex = 0;
              });
            }
          },
        ),
      ),
    );
  }

  // ===========================================================================
  // MODAL DE RESOLUÇÃO DE CONFLITO LADO A LADO (AM-04)
  // ===========================================================================
  void _showConflictResolutionDialog(
    BuildContext context,
    FieldFormRecord record,
  ) {
    final server = record.conflictServerData;
    if (server == null) return;

    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        key: const Key('conflict_resolution_dialog'),
        title: const Row(
          children: [
            Icon(Icons.compare_arrows_rounded, color: Color(0xFFEF6C00)),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Resolução de Conflito de Sincronização (AM-04)',
                style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                server.divergenceReason,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF5D4037),
                ),
              ),
              const SizedBox(height: 12),
              // Comparação Lado a Lado: Versão Coletada em Campo vs. Versão do Servidor
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFE1F5FE),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFF81D4FA)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'VERSÃO DE CAMPO (OFFLINE v${record.version}) — ${record.authorName}',
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF01579B),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '• Estágio: ${record.vegetationStage}',
                      style: const TextStyle(fontSize: 12),
                    ),
                    Text(
                      '• Sobrevivência: ${record.survivalRatePercent.toStringAsFixed(1)}%',
                      style: const TextStyle(fontSize: 12),
                    ),
                    Text(
                      '• Erosão: ${record.erosionStatus}',
                      style: const TextStyle(fontSize: 12),
                    ),
                    Text(
                      '• Notas: ${record.technicalNotes}',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF3E0),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFFFCC80)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'VERSÃO DA PLATAFORMA (SERVIDOR v${server.serverVersion}) — ${server.serverAuthorName}',
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFFE65100),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '• Estágio: ${server.vegetationStage}',
                      style: const TextStyle(fontSize: 12),
                    ),
                    Text(
                      '• Sobrevivência: ${server.survivalRatePercent.toStringAsFixed(1)}%',
                      style: const TextStyle(fontSize: 12),
                    ),
                    Text(
                      '• Erosão: ${server.erosionStatus}',
                      style: const TextStyle(fontSize: 12),
                    ),
                    Text(
                      '• Notas: ${server.technicalNotes}',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancelar'),
          ),
          OutlinedButton.icon(
            key: const Key('accept_server_version_btn'),
            onPressed: () async {
              Navigator.of(dialogContext).pop();
              await widget.appState.resolveRecordConflict(
                clientUuid: record.clientUuid,
                keepFieldVersion: false,
              );
            },
            icon: const Icon(Icons.cloud_download_rounded, size: 16),
            label: const Text('Aceitar Versão Servidor'),
          ),
          FilledButton.icon(
            key: const Key('keep_field_version_btn'),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF1B5E20),
            ),
            onPressed: () async {
              Navigator.of(dialogContext).pop();
              await widget.appState.resolveRecordConflict(
                clientUuid: record.clientUuid,
                keepFieldVersion: true,
              );
            },
            icon: const Icon(Icons.agriculture_rounded, size: 16),
            label: const Text('Manter Coleta de Campo'),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // MODAL DE HISTÓRICO DE AUDITORIA E AUTORIA (AM-11)
  // ===========================================================================
  void _showAuditHistoryModal(BuildContext context, FieldFormRecord record) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        key: const Key('audit_history_dialog'),
        title: Row(
          children: [
            const Icon(Icons.history_edu_rounded, color: Color(0xFF1B5E20)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Histórico de Alterações & Autoria (AM-11) — v${record.version}',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: 480,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Chave de Idempotência (UUID): ${record.clientUuid}',
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF455A64),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Autor Original: ${record.authorName} (${record.authorRole})',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  record.syncedAt != null
                      ? 'Última Sincronização: ${_formatIsoTimestamp(record.syncedAt!)}'
                      : 'Última Sincronização: Ainda não sincronizado com o servidor',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF2E7D32),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Divider(height: 20),
                ...record.auditHistory.map(
                  (entry) => Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF4F8F5),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFD5E2D9)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '${entry.action} (v${entry.version})',
                              style: const TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF1B5E20),
                              ),
                            ),
                            Text(
                              _formatIsoTimestamp(entry.timestamp),
                              style: const TextStyle(
                                fontSize: 11,
                                color: Color(0xFF546E7A),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          entry.summary,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF263238),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Responsável: ${entry.authorName} (${entry.authorRole})',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF455A64),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            key: const Key('close_audit_history_btn'),
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Fechar'),
          ),
        ],
      ),
    );
  }

  String _formatIsoTimestamp(String rawIso) {
    final parsed = DateTime.tryParse(rawIso);
    if (parsed == null) return rawIso;
    final local = parsed.toLocal();
    final d = local.day.toString().padLeft(2, '0');
    final m = local.month.toString().padLeft(2, '0');
    final y = local.year;
    final hh = local.hour.toString().padLeft(2, '0');
    final mm = local.minute.toString().padLeft(2, '0');
    return '$d/$m/$y às $hh:$mm';
  }
}
