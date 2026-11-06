import 'package:flutter/material.dart';
import '../models/project_models.dart';
import '../models/user_profile.dart';
import '../services/database_service.dart';

/// Controlador de Estado Global da aplicação (ChangeNotifier).
/// Gerencia:
/// - Sessão de autenticação JWT e Perfil Ativo (AM-01)
/// - Barra de Modo Demonstração (Online/Offline, Falha de Rede AM-12, Conflito AM-04)
/// - Consulta de Projetos Muda/PSA, Propriedades, Áreas, Etapas, Cronogramas e Documentos (AM-02)
class AppState extends ChangeNotifier {
  final DatabaseService _dbService;

  AppState({DatabaseService? dbService})
      : _dbService = dbService ?? DatabaseService.instance;

  bool _isInitialized = false;
  bool _isLoading = false;
  String? _authError;

  AppUser? _currentUser;
  String? _activeJwtToken;

  // Controles da Barra de Modo Demonstração (para avaliação prática em sala de aula)
  bool _isOnline = true;
  bool _simulateNetworkFailure = false;
  bool _simulateConflictOnNextSync = false;

  // Filtros e dados de Projetos (AM-02)
  String _selectedProgramFilter = 'TODOS'; // 'TODOS', 'MUDA', 'PSA'
  String _searchQuery = '';

  List<EnvironmentalProject> _projects = [];
  List<RuralProperty> _properties = [];
  List<CollectionPoint> _collectionPoints = [];

  bool get isInitialized => _isInitialized;
  bool get isLoading => _isLoading;
  String? get authError => _authError;

  AppUser? get currentUser => _currentUser;
  String? get activeJwtToken => _activeJwtToken;
  bool get isAuthenticated =>
      _currentUser != null &&
      _activeJwtToken != null &&
      JwtAuthSimulator.validateToken(_activeJwtToken!);

  bool get isOnline => _isOnline;
  bool get simulateNetworkFailure => _simulateNetworkFailure;
  bool get simulateConflictOnNextSync => _simulateConflictOnNextSync;

  String get selectedProgramFilter => _selectedProgramFilter;
  String get searchQuery => _searchQuery;

  List<EnvironmentalProject> get projects => _projects;
  List<RuralProperty> get properties => _properties;
  List<CollectionPoint> get collectionPoints => _collectionPoints;

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
      await _loadDatabaseContent();
      final savedSession = await _dbService.getActiveSession();
      if (savedSession != null) {
        _currentUser = savedSession.user;
        _activeJwtToken = savedSession.jwtToken;
      }
      _isInitialized = true;
    } finally {
      _isLoading = false;
      _initializingFuture = null;
      notifyListeners();
    }
  }

  Future<void> _loadDatabaseContent() async {
    _projects = await _dbService.getProjects();
    _properties = await _dbService.getProperties();
    _collectionPoints = await _dbService.getCollectionPoints();
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

  /// Alterna entre Online e Offline na Barra de Modo Demonstração.
  void toggleOnlineStatus([bool? value]) {
    _isOnline = value ?? !_isOnline;
    if (!_isOnline) {
      _simulateNetworkFailure = false;
    }
    notifyListeners();
  }

  /// Ativa/desativa simulação de falha de rede durante sincronização (AM-12).
  void toggleSimulateNetworkFailure([bool? value]) {
    _simulateNetworkFailure = value ?? !_simulateNetworkFailure;
    if (_simulateNetworkFailure && !_isOnline) {
      _isOnline = true;
    }
    notifyListeners();
  }

  /// Ativa/desativa simulação de conflito de versões no servidor (AM-04).
  void toggleSimulateConflictOnNextSync([bool? value]) {
    _simulateConflictOnNextSync = value ?? !_simulateConflictOnNextSync;
    notifyListeners();
  }

  void setProgramFilter(String filter) {
    _selectedProgramFilter = filter.toUpperCase();
    notifyListeners();
  }

  void setSearchQuery(String query) {
    _searchQuery = query;
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
}
