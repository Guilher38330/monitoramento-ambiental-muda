import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../models/field_form_record.dart';
import '../models/project_models.dart';
import '../models/user_profile.dart';
import '../models/water_soil_models.dart';
import '../services/database_service.dart';
import '../services/mock_api_sync_service.dart';

/// Controlador de Estado Global da aplicação (ChangeNotifier).
/// Gerencia:
/// - Sessão de autenticação JWT e Perfil Ativo (AM-01)
/// - Barra de Modo Demonstração (Online/Offline, Falha de Rede AM-12, Conflito AM-04)
/// - Consulta de Projetos Muda/PSA, Propriedades, Áreas, Etapas, Cronogramas e Documentos (AM-02)
/// - Coleta em Campo Offline, GPS, Fotos Georreferenciadas, Fila de Sincronização, Conflitos e Auditoria (AM-03, AM-04, AM-05, AM-11, AM-12)
/// - Mapa Interativo (Polígonos, KML, Croqui Técnico e Pontos), Análises de Água CONAMA 357/2005 e Unidades Modelo de Conservação do Solo (AM-06, AM-07, AM-10)
class AppState extends ChangeNotifier {
  final DatabaseService _dbService;
  final MockApiSyncService _syncService;
  static const Uuid _uuid = Uuid();

  AppState({
    DatabaseService? dbService,
    MockApiSyncService? syncService,
  })  : _dbService = dbService ?? DatabaseService.instance,
        _syncService = syncService ??
            MockApiSyncService(
              dbService: dbService ?? DatabaseService.instance,
            );

  bool _isInitialized = false;
  bool _isLoading = false;
  bool _isSyncing = false;
  String? _authError;
  String? _initError;
  String? get initError => _initError;
  String? _lastSyncMessage;

  AppUser? _currentUser;
  String? _activeJwtToken;

  // Controles da Barra de Modo Demonstração (para avaliação prática em sala de aula)
  static const String prefShowDemoQuickBarKey = 'pref_show_demo_quick_bar';
  bool _isDemoModeEnabled = false;
  bool _showDemoQuickBar = true;
  bool _isOnline = true;
  bool _simulateNetworkFailure = false;
  bool _simulateConflictOnNextSync = false;

  // Filtros e dados de Projetos (AM-02)
  String _selectedProgramFilter = 'TODOS'; // 'TODOS', 'MUDA', 'PSA'
  String _searchQuery = '';

  // Filtro da Fila de Sincronização & Registros de Campo (Fase 2)
  String _selectedSyncFilter = 'TODOS'; // 'TODOS', 'FILA', 'SINCRONIZADOS', 'CONFLITOS'

  List<EnvironmentalProject> _projects = [];
  List<RuralProperty> _properties = [];
  List<CollectionPoint> _collectionPoints = [];
  List<FieldFormRecord> _fieldForms = [];
  List<WaterQualityAnalysis> _waterAnalyses = [];
  List<SoilConservationUnit> _soilUnits = [];
  List<ProcessedKmlOverlay> _kmlOverlays = [];

  bool get isInitialized => _isInitialized;
  bool get isLoading => _isLoading;
  bool get isSyncing => _isSyncing;
  String? get authError => _authError;
  String? get lastSyncMessage => _lastSyncMessage;

  AppUser? get currentUser => _currentUser;
  String? get activeJwtToken => _activeJwtToken;
  bool get isAuthenticated =>
      _currentUser != null &&
      _activeJwtToken != null &&
      JwtAuthSimulator.validateToken(_activeJwtToken!);

  bool get isDemoModeEnabled => _isDemoModeEnabled;
  bool get isOnline => _isOnline;
  bool get simulateNetworkFailure => _simulateNetworkFailure;
  bool get simulateConflictOnNextSync => _simulateConflictOnNextSync;
  bool get showDemoQuickBar => _showDemoQuickBar;
  bool get hasActiveSimulations =>
      _simulateNetworkFailure || _simulateConflictOnNextSync;

  String get selectedProgramFilter => _selectedProgramFilter;
  String get searchQuery => _searchQuery;
  String get selectedSyncFilter => _selectedSyncFilter;

  List<EnvironmentalProject> get projects => _projects;
  List<RuralProperty> get properties => _properties;
  List<CollectionPoint> get collectionPoints => _collectionPoints;
  List<FieldFormRecord> get fieldForms => _fieldForms;
  List<WaterQualityAnalysis> get waterAnalyses => _waterAnalyses;
  List<SoilConservationUnit> get soilUnits => _soilUnits;
  List<ProcessedKmlOverlay> get kmlOverlays => _kmlOverlays;

  /// Quantidade de registros pendentes ou com falha de rede na fila local (AM-04 / AM-12).
  int get pendingSyncCount =>
      _fieldForms.where((r) => r.isPendingOrFailed).length;

  /// Quantidade de registros com conflito de versão aguardando decisão (AM-04).
  int get conflictCount => _fieldForms.where((r) => r.hasConflict).length;

  /// Quantidade de registros já sincronizados com o servidor.
  int get syncedCount =>
      _fieldForms.where((r) => r.syncStatus == SyncStatus.synced).length;

  /// Lista de formulários de campo filtrada pelo chip selecionado na Central de Sincronização.
  List<FieldFormRecord> get filteredFieldForms {
    switch (_selectedSyncFilter) {
      case 'FILA':
        return _fieldForms.where((r) => r.isPendingOrFailed).toList();
      case 'SINCRONIZADOS':
        return _fieldForms
            .where((r) => r.syncStatus == SyncStatus.synced)
            .toList();
      case 'CONFLITOS':
        return _fieldForms.where((r) => r.hasConflict).toList();
      case 'TODOS':
      default:
        return _fieldForms;
    }
  }

  /// Lista de projetos filtrada por tipo de programa ('TODOS', 'MUDA', 'PSA') e busca textual.
  List<EnvironmentalProject> get filteredProjects {
    return _projects.where((project) {
      final matchesProgram = _selectedProgramFilter == 'TODOS' ||
          project.programType.toUpperCase() == _selectedProgramFilter;

      if (!matchesProgram) return false;

      if (_searchQuery.trim().isEmpty) return true;
      final q = _searchQuery.toLowerCase();
      final matchesProject = project.name.toLowerCase().contains(q) ||
          project.code.toLowerCase().contains(q) ||
          project.watershed.toLowerCase().contains(q) ||
          project.municipalityHub.toLowerCase().contains(q);

      if (matchesProject) return true;

      // Também permite buscar pelo nome/município de uma propriedade vinculada ao projeto
      final projectProps = getPropertiesForProject(project.id);
      return projectProps.any(
        (prop) =>
            prop.name.toLowerCase().contains(q) ||
            prop.municipality.toLowerCase().contains(q) ||
            prop.code.toLowerCase().contains(q),
      );
    }).toList();
  }

  Future<void>? _initializingFuture;

  /// Inicializa o banco SQLite, carrega os dados de seed e restaura sessão JWT se existir.
  Future<void> initialize() {
    if (_isInitialized) return Future.value();
    if (_initializingFuture != null) return _initializingFuture!;
    _initializingFuture = _performInitialize();
    return _initializingFuture!;
  }

  Future<void> _performInitialize() async {
    _isLoading = true;
    notifyListeners();

    try {
      try {
        final prefs = await SharedPreferences.getInstance();
        if (prefs.containsKey(prefShowDemoQuickBarKey)) {
          _showDemoQuickBar =
              prefs.getBool(prefShowDemoQuickBarKey) ?? _showDemoQuickBar;
        }
      } catch (e) {
        debugPrint('Erro ao carregar SharedPreferences: $e');
      }

      await _loadDatabaseContent();
      final savedSession = await _dbService.getActiveSession();
      if (savedSession != null) {
        _currentUser = savedSession.user;
        _activeJwtToken = savedSession.jwtToken;
      }
      _isInitialized = true;
      _initError = null;
    } catch (e, stack) {
      debugPrint('Erro na inicializacao SQLite: $e\n$stack');
      _initError = e.toString();
    } finally {
      _isLoading = false;
      _initializingFuture = null;
      notifyListeners();
    }
  }

  /// Reinicia o banco SQLite local com os dados originais de seed caso ocorra algum erro
  Future<void> resetDatabaseAndReload() async {
    _isLoading = true;
    _initError = null;
    notifyListeners();

    try {
      await _dbService.resetDatabase();
      if (_currentUser != null && _activeJwtToken != null) {
        await _dbService.saveSession(_currentUser!, _activeJwtToken!);
      }
      await _loadDatabaseContent();
      _isInitialized = true;
      _initError = null;
    } catch (e, stack) {
      debugPrint('Erro ao reiniciar banco SQLite: $e\n$stack');
      _initError = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _loadDatabaseContent() async {
    _projects = await _dbService.getProjects();
    _properties = await _dbService.getProperties();
    _collectionPoints = await _dbService.getCollectionPoints();
    _fieldForms = await _dbService.getFieldForms();
    _waterAnalyses = await _dbService.getWaterAnalyses();
    _soilUnits = await _dbService.getSoilConservationUnits();
    _kmlOverlays = _dbService.getProcessedKmlOverlays();
  }

  /// Login via e-mail e senha validado contra o banco SQLite + emissão de Token JWT (AM-01).
  Future<bool> loginWithCredentials(String email, String password) async {
    _isLoading = true;
    _authError = null;
    notifyListeners();

    try {
      final user = await _dbService.authenticate(email, password);
      if (user == null) {
        _authError =
            'Credenciais inválidas. Verifique o e-mail e a senha (padrão demo: 123456).';
        return false;
      }

      final token = JwtAuthSimulator.generateToken(user);
      await _dbService.saveSession(user, token);
      _currentUser = user;
      _activeJwtToken = token;
      await _loadDatabaseContent();
      return true;
    } catch (e) {
      _authError = 'Erro ao autenticar no banco local: $e';
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Login rápido com 1 toque para demonstração dos 3 perfis exigidos em AM-01.
  Future<bool> quickLoginAsRole(UserRole role) async {
    final targetUser = AppUser.demoUsers.firstWhere(
      (u) => u.role == role,
      orElse: () => AppUser.demoUsers.first,
    );
    final token = JwtAuthSimulator.generateToken(targetUser);
    _currentUser = targetUser;
    _activeJwtToken = token;
    _authError = null;
    notifyListeners();
    await _dbService.saveSession(targetUser, token);
    return true;
  }

  /// Encerra a sessão ativa e invalida o token JWT local.
  Future<void> logout() async {
    await _dbService.clearSession();
    _currentUser = null;
    _activeJwtToken = null;
    _authError = null;
    notifyListeners();
  }

  /// Alterna o Modo Demonstração (Simulações de Erro e Testes de Campo).
  /// Quando desativado, restaura instantaneamente o comportamento normal de produção:
  /// dispositivo online, sem falhas de rede forçadas e sem conflitos de versão simulados.
  void toggleDemoMode([bool? value]) {
    _isDemoModeEnabled = value ?? !_isDemoModeEnabled;
    if (!_isDemoModeEnabled) {
      _isOnline = true;
      _simulateNetworkFailure = false;
      _simulateConflictOnNextSync = false;
      _lastSyncMessage =
          'Modo Demonstração desativado: sistema operando no modo de produção padrão.';
    } else {
      _lastSyncMessage =
          'Modo Demonstração ATIVADO: controles e botões de simulação liberados.';
    }
    notifyListeners();
  }

  /// Alterna entre Online e Offline na Barra de Modo Demonstração.
  void toggleOnlineStatus([bool? value]) {
    _isOnline = value ?? !_isOnline;
    if (!_isOnline) {
      _simulateNetworkFailure = false;
      _lastSyncMessage =
          'Modo OFFLINE ativado: novos formulários serão gravados localmente na fila SQLite (AM-04).';
    } else {
      _lastSyncMessage =
          'Modo ONLINE restabelecido: $pendingSyncCount registro(s) na fila prontos para sincronização.';
    }
    notifyListeners();
  }

  /// Ativa/desativa simulação de falha de rede durante sincronização (AM-12).
  void toggleSimulateNetworkFailure([bool? value]) {
    _simulateNetworkFailure = value ?? !_simulateNetworkFailure;
    if (_simulateNetworkFailure && !_isOnline) {
      _isOnline = true;
    }
    _lastSyncMessage = _simulateNetworkFailure
        ? 'Simulação de Falha de Rede (HTTP 503 - AM-12) ATIVA: o próximo envio testará a proteção da fila local.'
        : 'Simulação de Falha de Rede desativada.';
    notifyListeners();
  }

  /// Ativa/desativa simulação de conflito de versões no servidor (AM-04).
  void toggleSimulateConflictOnNextSync([bool? value]) {
    _simulateConflictOnNextSync = value ?? !_simulateConflictOnNextSync;
    _lastSyncMessage = _simulateConflictOnNextSync
        ? 'Simulação de Conflito (AM-04) ATIVA: o próximo envio gerará divergência de versão com o servidor.'
        : 'Simulação de Conflito desativada.';
    notifyListeners();
  }

  /// Alterna a visibilidade da barra rápida horizontal no topo e persiste a preferência.
  Future<void> toggleDemoQuickBar() async {
    _showDemoQuickBar = !_showDemoQuickBar;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(prefShowDemoQuickBarKey, _showDemoQuickBar);
    } catch (e) {
      debugPrint('Erro ao salvar $prefShowDemoQuickBarKey: $e');
    }
  }

  void setProgramFilter(String filter) {
    _selectedProgramFilter = filter.toUpperCase();
    notifyListeners();
  }

  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  void setSyncFilter(String filter) {
    _selectedSyncFilter = filter.toUpperCase();
    notifyListeners();
  }

  List<RuralProperty> getPropertiesForProject(String projectId) {
    return _properties.where((p) => p.projectId == projectId).toList();
  }

  List<CollectionPoint> getPointsForProject(String projectId) {
    return _collectionPoints.where((pt) => pt.projectId == projectId).toList();
  }

  List<CollectionPoint> getPointsForProperty(String propertyId) {
    return _collectionPoints.where((pt) => pt.propertyId == propertyId).toList();
  }

  EnvironmentalProject? getProjectById(String projectId) {
    for (final p in _projects) {
      if (p.id == projectId) return p;
    }
    return null;
  }

  RuralProperty? getPropertyById(String propertyId) {
    for (final prop in _properties) {
      if (prop.id == propertyId) return prop;
    }
    return null;
  }

  CollectionPoint? getPointById(String pointId) {
    for (final pt in _collectionPoints) {
      if (pt.id == pointId) return pt;
    }
    return null;
  }

  // ===========================================================================
  // MÉTODOS DA FASE 2: COLETA EM CAMPO OFFLINE, FILA E SINCRONIZAÇÃO
  // (AM-03, AM-04, AM-05, AM-11, AM-12 + 1º Critério de Aceite)
  // ===========================================================================

  /// Cria ou atualiza de forma idempotente (por `clientUuid`) um formulário de campo
  /// com coordenadas GPS e foto georreferenciada na fila SQLite local.
  /// Se `customClientUuid` for informado (ex.: reenvio/teste de idempotência), reutiliza a mesma chave.
  Future<FieldFormRecord?> saveFieldFormRecord({
    String? customClientUuid,
    required String projectId,
    required String propertyId,
    required String pointId,
    required String templateName,
    required String vegetationStage,
    required double survivalRatePercent,
    required String erosionStatus,
    required bool invasiveSpeciesPresent,
    required String maintenancePerformed,
    required String technicalNotes,
    required bool isConfidential,
    required double latitude,
    required double longitude,
    required double gpsAccuracyMeters,
    required String photoLocalPath,
    required String photoCapturedAt,
    required String photoCaption,
    bool autoSyncWhenOnline = false,
  }) async {
    final user = _currentUser;
    if (user == null || !user.canRegisterFieldData) {
      _lastSyncMessage =
          'Operação bloqueada (AM-01): O perfil atual não possui permissão para registrar dados de campo.';
      notifyListeners();
      return null;
    }

    final clientUuid = (customClientUuid != null && customClientUuid.trim().isNotEmpty)
        ? customClientUuid.trim()
        : _uuid.v4();

    final nowIso = DateTime.now().toUtc().toIso8601String();
    final existing = await _dbService.getFieldFormByUuid(clientUuid);

    final initialAudit = AuditLogEntry(
      id: 'aud-create-${DateTime.now().microsecondsSinceEpoch}',
      action: existing == null ? 'CRIACAO_OFFLINE' : 'ATUALIZACAO_IDEMPOTENTE',
      summary: existing == null
          ? 'Formulário registrado (${_isOnline ? "Online -> Fila Local" : "Modo Offline sem internet"}) com GPS ($latitude, $longitude ±${gpsAccuracyMeters.toStringAsFixed(1)}m) e foto georreferenciada.'
          : 'Upsert idempotente pelo mesmo clientUuid ($clientUuid) sem duplicar registro na base.',
      authorId: user.id,
      authorName: user.name,
      authorRole: user.role.label,
      timestamp: nowIso,
      version: existing != null ? existing.version : 1,
    );

    final record = FieldFormRecord(
      clientUuid: clientUuid,
      projectId: projectId,
      propertyId: propertyId,
      pointId: pointId,
      templateName: templateName,
      vegetationStage: vegetationStage,
      survivalRatePercent: survivalRatePercent,
      erosionStatus: erosionStatus,
      invasiveSpeciesPresent: invasiveSpeciesPresent,
      maintenancePerformed: maintenancePerformed,
      technicalNotes: technicalNotes,
      isConfidential: isConfidential,
      latitude: latitude,
      longitude: longitude,
      gpsAccuracyMeters: gpsAccuracyMeters,
      photoLocalPath: photoLocalPath,
      photoCapturedAt: photoCapturedAt,
      photoCaption: photoCaption,
      syncStatus: SyncStatus.pending,
      version: existing != null ? existing.version : 1,
      authorId: user.id,
      authorName: user.name,
      authorRole: user.role.label,
      createdAt: existing?.createdAt ?? nowIso,
      syncedAt: existing?.syncedAt,
      auditHistory: [
        if (existing != null) ...existing.auditHistory,
        initialAudit,
      ],
    );

    await _dbService.upsertFieldForm(record);
    _fieldForms = await _dbService.getFieldForms();

    _lastSyncMessage = _isOnline
        ? 'Formulário salvo na fila local (UUID ${clientUuid.substring(0, 8)}...). Pronto para sincronizar!'
        : 'Formulário salvo OFFLINE no SQLite local (UUID ${clientUuid.substring(0, 8)}...). Aguardando internet para sincronizar.';
    notifyListeners();

    if (autoSyncWhenOnline && _isOnline) {
      await synchronizePendingForms();
      return _dbService.getFieldFormByUuid(clientUuid);
    }

    return record;
  }

  /// Dispara a sincronização da fila local contra a API simulada (AM-04, AM-11, AM-12).
  Future<SyncBatchResult> synchronizePendingForms() async {
    final user = _currentUser;
    if (user == null) {
      const res = SyncBatchResult(
        success: false,
        syncedCount: 0,
        conflictCount: 0,
        failedCount: 0,
        message: 'Nenhum usuário autenticado.',
      );
      _lastSyncMessage = res.message;
      notifyListeners();
      return res;
    }

    _isSyncing = true;
    notifyListeners();

    try {
      final result = await _syncService.processSyncQueue(
        currentUser: user,
        jwtToken: _activeJwtToken,
        isOnline: _isOnline,
        simulateNetworkFailure: _simulateNetworkFailure,
        simulateConflict: _simulateConflictOnNextSync,
      );

      // Desarma o gatilho de conflito único após disparar 1 vez para facilitar o fluxo de aula
      if (_simulateConflictOnNextSync && result.conflictCount > 0) {
        _simulateConflictOnNextSync = false;
      }

      _fieldForms = await _dbService.getFieldForms();
      _lastSyncMessage = result.message;
      return result;
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
  }

  /// Simula imediatamente um conflito de versão em um registro existente (AM-04).
  Future<void> triggerConflictOnRecord(String clientUuid) async {
    final user = _currentUser;
    if (user == null || !user.canResolveSyncConflicts) return;

    final target = await _dbService.getFieldFormByUuid(clientUuid);
    if (target == null) return;

    await _syncService.forceConflictOnRecord(
      record: target,
      currentUser: user,
    );
    _fieldForms = await _dbService.getFieldForms();
    _lastSyncMessage =
        'Conflito de versão simulado no registro ${target.pointId} (AM-04). Clique em "Resolver Conflito" para comparar as versões.';
    notifyListeners();
  }

  /// Resolve um conflito de versão escolhendo entre manter dados de campo ou aceitar revisão do servidor (AM-04, AM-11).
  Future<FieldFormRecord?> resolveRecordConflict({
    required String clientUuid,
    required bool keepFieldVersion,
  }) async {
    final user = _currentUser;
    if (user == null || !user.canResolveSyncConflicts) {
      _lastSyncMessage =
          'Acesso negado (AM-01): O perfil ${user?.role.label ?? ""} não pode resolver conflitos de sincronização.';
      notifyListeners();
      return null;
    }

    final target = await _dbService.getFieldFormByUuid(clientUuid);
    if (target == null) return null;

    final resolved = await _syncService.resolveConflict(
      record: target,
      keepFieldVersion: keepFieldVersion,
      currentUser: user,
    );

    _fieldForms = await _dbService.getFieldForms();
    _lastSyncMessage = keepFieldVersion
        ? 'Conflito resolvido (AM-04): Mantida a versão coletada em campo (v${resolved.version}) e registrada autoria no histórico (AM-11).'
        : 'Conflito resolvido (AM-04): Aceita a revisão da plataforma central (v${resolved.version}) e registrada autoria no histórico (AM-11).';
    notifyListeners();
    return resolved;
  }

  // ===========================================================================
  // MÉTODOS DA FASE 3: MAPA INTERATIVO (AM-06), QUALIDADE DA ÁGUA CONAMA 357/2005 (AM-07)
  // E UNIDADES MODELO DE CONSERVAÇÃO DO SOLO (AM-10)
  // ===========================================================================

  List<WaterQualityAnalysis> getWaterAnalysesForPoint(String pointId) {
    return _waterAnalyses.where((w) => w.pointId == pointId).toList();
  }

  List<WaterQualityAnalysis> getWaterAnalysesForProject(String projectId) {
    return _waterAnalyses.where((w) => w.projectId == projectId).toList();
  }

  List<SoilConservationUnit> getSoilUnitsForProject(String projectId) {
    return _soilUnits.where((u) => u.projectId == projectId).toList();
  }

  List<SoilConservationUnit> getSoilUnitsForProperty(String propertyId) {
    return _soilUnits.where((u) => u.propertyId == propertyId).toList();
  }

  List<FieldFormRecord> getFieldFormsForPoint(String pointId) {
    return _fieldForms.where((f) => f.pointId == pointId).toList();
  }

  ProcessedKmlOverlay? getKmlOverlayForProperty(String propertyId) {
    for (final kml in _kmlOverlays) {
      if (kml.propertyId == propertyId) return kml;
    }
    return null;
  }

  /// Registra um novo laudo de análise de qualidade da água (CONAMA 357/2005 - AM-07).
  Future<WaterQualityAnalysis?> saveWaterQualityAnalysis({
    required String projectId,
    required String propertyId,
    required String pointId,
    required String reportCode,
    required String sampleDate,
    required String campaignName,
    required String laboratoryName,
    required double ph,
    required double turbidityUnt,
    required double dissolvedOxygenMgL,
    required double dboMgL,
    required double totalPhosphorusMgL,
    required int thermotolerantColiformsNmp,
    required double waterTemperatureC,
    required double flowRateLs,
    required String technicalConclusion,
    required bool isConfidentialReport,
    required String confidentialLabNotes,
  }) async {
    final user = _currentUser;
    if (user == null || !user.canRegisterFieldData) {
      _lastSyncMessage =
          'Operação bloqueada (AM-01): O perfil atual não possui permissão para registrar laudos de água.';
      notifyListeners();
      return null;
    }

    final analysis = WaterQualityAnalysis(
      id: 'wat-${DateTime.now().microsecondsSinceEpoch}',
      projectId: projectId,
      propertyId: propertyId,
      pointId: pointId,
      reportCode: reportCode,
      sampleDate: sampleDate,
      campaignName: campaignName,
      laboratoryName: laboratoryName,
      ph: ph,
      turbidityUnt: turbidityUnt,
      dissolvedOxygenMgL: dissolvedOxygenMgL,
      dboMgL: dboMgL,
      totalPhosphorusMgL: totalPhosphorusMgL,
      thermotolerantColiformsNmp: thermotolerantColiformsNmp,
      waterTemperatureC: waterTemperatureC,
      flowRateLs: flowRateLs,
      technicalConclusion: technicalConclusion,
      isConfidentialReport: isConfidentialReport,
      confidentialLabNotes: confidentialLabNotes,
      responsibleAnalyst: '${user.name} (${user.registrationCode})',
      createdAt: DateTime.now().toUtc().toIso8601String(),
    );

    await _dbService.upsertWaterAnalysis(analysis);
    _waterAnalyses = await _dbService.getWaterAnalyses();
    _lastSyncMessage = analysis.isConamaCompliant
        ? 'Laudo ${analysis.reportCode} registrado (AM-07): 100% CONFORME CONAMA 357/2005 Classe 2.'
        : 'Laudo ${analysis.reportCode} registrado (AM-07): ALERTA — ${analysis.violations.length} parâmetro(s) acima do limite CONAMA 357/2005.';
    notifyListeners();
    return analysis;
  }

  /// Registra uma nova Unidade Modelo de Conservação do Solo (AM-10).
  Future<SoilConservationUnit?> saveSoilConservationUnit({
    required String projectId,
    required String propertyId,
    required String pointId,
    required String code,
    required String name,
    required double areaHa,
    required String soilClass,
    required double slopePercent,
    required List<String> adoptedPractices,
    required double vegetalCoverPercent,
    required double baselineErosionTonHaYear,
    required double currentErosionTonHaYear,
    required int infiltrationBasinsCount,
    required String conservationLevel,
    required String lastEvaluationDate,
    required String technicalNotes,
    required String confidentialOwnerAgreement,
  }) async {
    final user = _currentUser;
    if (user == null || !user.canRegisterFieldData) {
      _lastSyncMessage =
          'Operação bloqueada (AM-01): O perfil atual não possui permissão para cadastrar unidades de conservação do solo.';
      notifyListeners();
      return null;
    }

    final abatement = (baselineErosionTonHaYear - currentErosionTonHaYear)
        .clamp(0.0, double.infinity);

    final unit = SoilConservationUnit(
      id: 'soil-${DateTime.now().microsecondsSinceEpoch}',
      projectId: projectId,
      propertyId: propertyId,
      pointId: pointId,
      code: code,
      name: name,
      areaHa: areaHa,
      soilClass: soilClass,
      slopePercent: slopePercent,
      adoptedPractices: adoptedPractices,
      vegetalCoverPercent: vegetalCoverPercent,
      baselineErosionTonHaYear: baselineErosionTonHaYear,
      currentErosionTonHaYear: currentErosionTonHaYear,
      erosionAbatementTonHaYear: abatement,
      infiltrationBasinsCount: infiltrationBasinsCount,
      conservationLevel: conservationLevel,
      lastEvaluationDate: lastEvaluationDate,
      technicalNotes: technicalNotes,
      confidentialOwnerAgreement: confidentialOwnerAgreement,
      responsibleTechnician: user.name,
    );

    await _dbService.upsertSoilConservationUnit(unit);
    _soilUnits = await _dbService.getSoilConservationUnits();
    _lastSyncMessage =
        'Unidade Modelo de Solo ${unit.code} registrada (AM-10): abatimento de ${unit.erosionAbatementTonHaYear.toStringAsFixed(1)} t/ha/ano (${unit.erosionReductionPercent.toStringAsFixed(1)}%).';
    notifyListeners();
    return unit;
  }
}

