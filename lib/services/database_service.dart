import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import '../models/field_form_record.dart';
import '../models/project_models.dart';
import '../models/user_profile.dart';

/// Serviço de persistência SQLite local (Premissas Comuns + AM-01 a AM-05, AM-11, AM-12).
/// Contém o Seed Data inicial realista dos Projetos Muda e PSA e da Fila de Coleta Offline.
class DatabaseService {
  static final DatabaseService instance = DatabaseService._internal();
  DatabaseService._internal();

  Database? _database;

  Future<Database> get database async {
    if (_database != null && _database!.isOpen) {
      return _database!;
    }
    _database = await _initDatabase();
    return _database!;
  }

  /// Permite inicializar em um caminho customizado (ex.: inMemoryDatabasePath em testes automatizados).
  Future<void> initializeForTest(String customPath) async {
    if (_database != null && _database!.isOpen) {
      await _database!.close();
    }
    _database = await openDatabase(
      customPath,
      version: 2,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<Database> _initDatabase() async {
    final dbRoot = await getDatabasesPath();
    final dbPath = p.join(dbRoot, 'muda_psa_monitoring_v2.db');
    return openDatabase(
      dbPath,
      version: 2,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await _createFieldFormsTable(db);
      final existing = await db.query('field_forms_local', limit: 1);
      if (existing.isEmpty) {
        for (final record in _buildSeedFieldForms()) {
          await db.insert(
            'field_forms_local',
            record.toDbMap(),
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
      }
    }
  }

  Future<void> _createFieldFormsTable(Database db) async {
    // 6. Tabela local de formulários de campo e fila de sincronização idempotente por client_uuid (AM-03, AM-04, AM-05, AM-11, AM-12)
    await db.execute('''
      CREATE TABLE IF NOT EXISTS field_forms_local (
        client_uuid TEXT PRIMARY KEY,
        project_id TEXT NOT NULL,
        property_id TEXT NOT NULL,
        point_id TEXT NOT NULL,
        template_name TEXT NOT NULL,
        vegetation_stage TEXT NOT NULL,
        survival_rate_percent REAL NOT NULL,
        erosion_status TEXT NOT NULL,
        invasive_species_present INTEGER NOT NULL,
        maintenance_performed TEXT NOT NULL,
        technical_notes TEXT NOT NULL,
        is_confidential INTEGER NOT NULL,
        latitude REAL NOT NULL,
        longitude REAL NOT NULL,
        gps_accuracy_meters REAL NOT NULL,
        photo_local_path TEXT NOT NULL,
        photo_captured_at TEXT NOT NULL,
        photo_caption TEXT NOT NULL,
        sync_status TEXT NOT NULL,
        sync_error_message TEXT,
        version INTEGER NOT NULL,
        author_id TEXT NOT NULL,
        author_name TEXT NOT NULL,
        author_role TEXT NOT NULL,
        created_at TEXT NOT NULL,
        synced_at TEXT,
        conflict_server_json TEXT,
        audit_history_json TEXT NOT NULL
      )
    ''');
  }

  Future<void> _onCreate(Database db, int version) async {
    // 1. Tabela de usuários locais (proteção de credenciais com hash SHA-256)
    await db.execute('''
      CREATE TABLE users (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        email TEXT NOT NULL UNIQUE,
        password_hash TEXT NOT NULL,
        organization TEXT NOT NULL,
        registration_code TEXT NOT NULL,
        role TEXT NOT NULL
      )
    ''');

    // 2. Tabela de projetos (Muda e PSA) com etapas e documentos autorizados
    await db.execute('''
      CREATE TABLE projects (
        id TEXT PRIMARY KEY,
        code TEXT NOT NULL,
        name TEXT NOT NULL,
        program_type TEXT NOT NULL,
        watershed TEXT NOT NULL,
        municipality_hub TEXT NOT NULL,
        period TEXT NOT NULL,
        status TEXT NOT NULL,
        overall_progress REAL NOT NULL,
        total_target_area_ha REAL NOT NULL,
        target_seedlings_count INTEGER NOT NULL,
        public_summary TEXT NOT NULL,
        partner_company TEXT NOT NULL,
        confidential_total_budget REAL NOT NULL,
        confidential_contract_code TEXT NOT NULL,
        confidential_technical_notes TEXT NOT NULL,
        stages_json TEXT NOT NULL,
        documents_json TEXT NOT NULL
      )
    ''');

    // 3. Tabela de propriedades rurais e áreas monitoradas
    await db.execute('''
      CREATE TABLE properties (
        id TEXT PRIMARY KEY,
        project_id TEXT NOT NULL,
        code TEXT NOT NULL,
        name TEXT NOT NULL,
        municipality TEXT NOT NULL,
        total_area_ha REAL NOT NULL,
        restoration_area_ha REAL NOT NULL,
        area_description TEXT NOT NULL,
        main_soil_type TEXT NOT NULL,
        conservation_status TEXT NOT NULL,
        center_latitude REAL NOT NULL,
        center_longitude REAL NOT NULL,
        polygon_json TEXT NOT NULL,
        owner_name TEXT NOT NULL,
        owner_cpf TEXT NOT NULL,
        car_registry_code TEXT NOT NULL,
        psa_monthly_value REAL NOT NULL,
        bank_account_summary TEXT NOT NULL
      )
    ''');

    // 4. Tabela de pontos de coleta georreferenciados
    await db.execute('''
      CREATE TABLE collection_points (
        id TEXT PRIMARY KEY,
        project_id TEXT NOT NULL,
        property_id TEXT NOT NULL,
        code TEXT NOT NULL,
        name TEXT NOT NULL,
        point_type TEXT NOT NULL,
        latitude REAL NOT NULL,
        longitude REAL NOT NULL,
        altitude_meters REAL NOT NULL,
        reference_area_name TEXT NOT NULL,
        last_inspection_date TEXT NOT NULL,
        monitoring_status TEXT NOT NULL
      )
    ''');

    // 5. Tabela de sessão ativa (JWT persistido localmente)
    await db.execute('''
      CREATE TABLE active_session (
        id INTEGER PRIMARY KEY CHECK (id = 1),
        user_id TEXT NOT NULL,
        jwt_token TEXT NOT NULL,
        login_timestamp TEXT NOT NULL
      )
    ''');

    // 6. Tabela local de formulários de campo e fila de sincronização (Fase 2)
    await _createFieldFormsTable(db);

    await _seedInitialData(db);
  }

  Future<void> _seedInitialData(Database db) async {
    // Seed de Usuários para os 3 Perfis (AM-01)
    // Senha padrão para todos os perfis de demonstração: "123456"
    final defaultPassHash = JwtAuthSimulator.hashPassword('123456');
    for (final demoUser in AppUser.demoUsers) {
      await db.insert('users', {
        'id': demoUser.id,
        'name': demoUser.name,
        'email': demoUser.email.toLowerCase(),
        'password_hash': defaultPassHash,
        'organization': demoUser.organization,
        'registration_code': demoUser.registrationCode,
        'role': demoUser.role.name,
      });
    }

    // Seed de Projetos Muda e PSA (AM-02)
    for (final project in _buildSeedProjects()) {
      await db.insert('projects', project.toDbMap());
    }

    // Seed de Propriedades Rurais e Áreas (AM-02)
    for (final prop in _buildSeedProperties()) {
      await db.insert('properties', prop.toDbMap());
    }

    // Seed de Pontos de Coleta (AM-02 / AM-05)
    for (final point in _buildSeedCollectionPoints()) {
      await db.insert('collection_points', point.toDbMap());
    }

    // Seed de Formulários de Campo e Fila de Sincronização (AM-03, AM-04, AM-05, AM-11)
    for (final form in _buildSeedFieldForms()) {
      await db.insert(
        'field_forms_local',
        form.toDbMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
  }

  /// Autentica usuário validando e-mail e hash da senha no SQLite.
  Future<AppUser?> authenticate(String email, String password) async {
    final db = await database;
    final cleanEmail = email.trim().toLowerCase();
    final passHash = JwtAuthSimulator.hashPassword(password.trim());

    final rows = await db.query(
      'users',
      where: 'email = ? AND password_hash = ?',
      whereArgs: [cleanEmail, passHash],
      limit: 1,
    );

    if (rows.isEmpty) return null;
    final row = rows.first;
    return AppUser(
      id: row['id'] as String,
      name: row['name'] as String,
      email: row['email'] as String,
      organization: row['organization'] as String,
      registrationCode: row['registration_code'] as String,
      role: UserRole.fromString(row['role'] as String),
    );
  }

  /// Salva a sessão local com Token JWT assinado.
  Future<void> saveSession(AppUser user, String jwtToken) async {
    final db = await database;
    await db.insert(
      'active_session',
      {
        'id': 1,
        'user_id': user.id,
        'jwt_token': jwtToken,
        'login_timestamp': DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Recupera a sessão ativa caso o token JWT ainda seja válido.
  Future<({AppUser user, String jwtToken})?> getActiveSession() async {
    final db = await database;
    final sessionRows = await db.query('active_session', where: 'id = 1');
    if (sessionRows.isEmpty) return null;

    final userId = sessionRows.first['user_id'] as String;
    final jwtToken = sessionRows.first['jwt_token'] as String;

    if (!JwtAuthSimulator.validateToken(jwtToken)) {
      await clearSession();
      return null;
    }

    final userRows = await db.query(
      'users',
      where: 'id = ?',
      whereArgs: [userId],
      limit: 1,
    );
    if (userRows.isEmpty) return null;

    final row = userRows.first;
    final user = AppUser(
      id: row['id'] as String,
      name: row['name'] as String,
      email: row['email'] as String,
      organization: row['organization'] as String,
      registrationCode: row['registration_code'] as String,
      role: UserRole.fromString(row['role'] as String),
    );

    return (user: user, jwtToken: jwtToken);
  }

  Future<void> clearSession() async {
    final db = await database;
    await db.delete('active_session');
  }

  Future<List<EnvironmentalProject>> getProjects() async {
    final db = await database;
    final rows = await db.query('projects', orderBy: 'code ASC');
    return rows.map(EnvironmentalProject.fromDbMap).toList();
  }

  Future<List<RuralProperty>> getProperties({String? projectId}) async {
    final db = await database;
    final rows = projectId == null
        ? await db.query('properties', orderBy: 'code ASC')
        : await db.query(
            'properties',
            where: 'project_id = ?',
            whereArgs: [projectId],
            orderBy: 'code ASC',
          );
    return rows.map(RuralProperty.fromDbMap).toList();
  }

  Future<List<CollectionPoint>> getCollectionPoints({
    String? projectId,
    String? propertyId,
  }) async {
    final db = await database;
    String? whereClause;
    List<Object?>? whereArgs;

    if (projectId != null && propertyId != null) {
      whereClause = 'project_id = ? AND property_id = ?';
      whereArgs = [projectId, propertyId];
    } else if (projectId != null) {
      whereClause = 'project_id = ?';
      whereArgs = [projectId];
    } else if (propertyId != null) {
      whereClause = 'property_id = ?';
      whereArgs = [propertyId];
    }

    final rows = await db.query(
      'collection_points',
      where: whereClause,
      whereArgs: whereArgs,
      orderBy: 'code ASC',
    );
    return rows.map(CollectionPoint.fromDbMap).toList();
  }

  /// Lista todos os formulários de campo armazenados localmente no SQLite (AM-04, AM-11).
  Future<List<FieldFormRecord>> getFieldForms({
    String? projectId,
    String? pointId,
  }) async {
    final db = await database;
    String? whereClause;
    List<Object?>? whereArgs;

    if (projectId != null && pointId != null) {
      whereClause = 'project_id = ? AND point_id = ?';
      whereArgs = [projectId, pointId];
    } else if (projectId != null) {
      whereClause = 'project_id = ?';
      whereArgs = [projectId];
    } else if (pointId != null) {
      whereClause = 'point_id = ?';
      whereArgs = [pointId];
    }

    final rows = await db.query(
      'field_forms_local',
      where: whereClause,
      whereArgs: whereArgs,
      orderBy: 'created_at DESC',
    );
    return rows.map(FieldFormRecord.fromDbMap).toList();
  }

  /// Busca um registro específico pela chave de idempotência `clientUuid`.
  Future<FieldFormRecord?> getFieldFormByUuid(String clientUuid) async {
    final db = await database;
    final rows = await db.query(
      'field_forms_local',
      where: 'client_uuid = ?',
      whereArgs: [clientUuid],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return FieldFormRecord.fromDbMap(rows.first);
  }

  /// Insere ou atualiza de forma idempotente pelo `client_uuid` (PRIMARY KEY),
  /// garantindo que reenvios ou sincronizações repetidas nunca dupliquem o registro
  /// (1º Critério de Aceite + AM-04).
  Future<void> upsertFieldForm(FieldFormRecord record) async {
    final db = await database;
    await db.insert(
      'field_forms_local',
      record.toDbMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // ===========================================================================
  // SEED DATA REALISTA: PROJETOS MUDA E PSA (AM-02)
  // ===========================================================================
  List<EnvironmentalProject> _buildSeedProjects() {
    return [
      EnvironmentalProject(
        id: 'proj-muda-01',
        code: 'MUDA-2026-RP01',
        name: 'Recomposição Florestal e Proteção de Nascentes — Alto Rio Pardo',
        programType: 'MUDA',
        watershed: 'Bacia Hidrográfica do Rio Pardo (Sub-bacia Ribeirão São João)',
        municipalityHub: 'Santa Cruz do Sul / Vale do Rio Pardo - RS',
        period: 'Jan/2026 a Dez/2027 (24 meses)',
        status: 'Em Execução',
        overallProgress: 68.5,
        totalTargetAreaHa: 142.0,
        targetSeedlingsCount: 85000,
        publicSummary:
            'Projeto de restauração ecológica de Áreas de Preservação Permanente (APP) e nascentes degradadas por meio do plantio de 85 mil mudas nativas da Mata Atlântica/Estacional Decidual, cercamento de proteção hidroambiental e monitoramento trimestral de sobrevivência e regeneração.',
        partnerCompany: 'HidroEnergia S.A. & Consórcio Ambiental VerdeVale',
        confidentialTotalBudget: 1485000.00,
        confidentialContractCode: 'CT-SIG-MUDA-2026/0042-A',
        confidentialTechnicalNotes:
            'NOTA TÉCNICA SIGILOSA: Gleba Norte da Fazenda Santa Inês apresenta passivo de autuação ambiental (Processo IBAMA/FEPAM nº 88219/2024 - Termo de Compromisso Ambiental em sigilo judicial). Priorizar adensamento de Inga vera e Schinus terebinthifolius nos talhões T-02 e T-03.',
        stages: const [
          ProjectStage(
            id: 'stg-muda-1',
            title: 'Etapa 1 — Diagnóstico Hidroambiental e Cercamento de APPs',
            description:
                'Mapeamento aerofotogramétrico das nascentes, isolamento das faixas ciliares (30m) com cerca de 4 fios e retirada de fatores de degradação.',
            startDate: '10/01/2026',
            endDate: '30/04/2026',
            status: 'Concluída',
            progressPercent: 100.0,
            responsibleTeam: 'Equipe de Geoprocessamento e Campo (Eng. Lucas Albuquerque)',
            targetDeliverable: '18,4 km de cercas instaladas e 12 nascentes isoladas',
          ),
          ProjectStage(
            id: 'stg-muda-2',
            title: 'Etapa 2 — Preparo de Solo, Controle de Invasoras e Plantio de Mudas',
            description:
                'Coroamento, controle seletivo de gramíneas exóticas (Urochloa decumbens), coveamento 40x40x40cm e plantio de espécies pioneiras e secundárias.',
            startDate: '02/05/2026',
            endDate: '30/09/2026',
            status: 'Concluída',
            progressPercent: 100.0,
            responsibleTeam: 'Brigada Florestal Muda & Viveiro Regional',
            targetDeliverable: '64.500 mudas nativas plantadas com hidrogel e adubação de base',
          ),
          ProjectStage(
            id: 'stg-muda-3',
            title: 'Etapa 3 — Monitoramento de Pegamento, Replantio e Coleta Hidrológica',
            description:
                'Avaliação de sobrevivência das mudas (meta >= 85%), coroamento de manutenção, combate a formigas cortadeiras e medição de vazão/turbidez nas nascentes.',
            startDate: '01/10/2026',
            endDate: '30/04/2027',
            status: 'Em Andamento',
            progressPercent: 58.0,
            responsibleTeam: 'Equipe Técnica de Monitoramento (Eng. Lucas Albuquerque)',
            targetDeliverable: 'Taxa de sobrevivência aferida em 18 parcelas permanentes',
          ),
          ProjectStage(
            id: 'stg-muda-4',
            title: 'Etapa 4 — Avaliação de Cobertura de Dossel e Certificação Final',
            description:
                'Mensuração de altura média, diâmetro de colo, índice de cobertura do solo e emissão de Laudo de Conformidade Florestal.',
            startDate: '01/05/2027',
            endDate: '15/12/2027',
            status: 'Planejada',
            progressPercent: 15.0,
            responsibleTeam: 'Coordenação Científica (Dra. Helena Vasconcelos)',
            targetDeliverable: 'Relatório Consolidado de Restauração Ecológica',
          ),
        ],
        documents: const [
          AuthorizedDocument(
            id: 'doc-muda-01',
            code: 'PRAD-MUDA-001',
            title: 'Plano Técnico de Recomposição Florestal (PRAD Bacia Rio Pardo)',
            category: 'Plano Técnico',
            issueDate: '12/01/2026',
            version: 'v2.3 Aprovada',
            fileSize: '4,2 MB (PDF)',
            summary:
                'Especificação florística de 42 espécies nativas, espaçamento 3x2m, cronograma físico e metodologia de monitoramento por parcelas.',
            isConfidential: false,
            confidentialContent:
                'Documento público disponível para consulta aberta de parceiros e auditoria externa.',
          ),
          AuthorizedDocument(
            id: 'doc-muda-02',
            code: 'LIC-FEPAM-892',
            title: 'Autorização Especial de Intervenção e Manejo em APP',
            category: 'Licença Ambiental',
            issueDate: '05/02/2026',
            version: 'v1.0 Vigente',
            fileSize: '1,8 MB (PDF)',
            summary:
                'Autorização do órgão ambiental estadual para intervenção restaurativa e manejo de espécies exóticas invasoras nas faixas ciliares.',
            isConfidential: false,
            confidentialContent:
                'Licença pública sem restrições de confidencialidade.',
          ),
          AuthorizedDocument(
            id: 'doc-muda-03',
            code: 'TCA-SIG-042',
            title: 'Termo de Compromisso Ambiental, CAR e Custos Unitários por Propriedade',
            category: 'Termo Sigiloso / Jurídico',
            issueDate: '18/02/2026',
            version: 'v1.4 Restrito',
            fileSize: '6,7 MB (PDF Criptografado)',
            summary:
                'Contém dados pessoais dos proprietários rurais (CPF, matrícula imobiliária, CAR detalhado) e memória de cálculo financeira de insumos.',
            isConfidential: true,
            confidentialContent:
                'CONTEÚDO SIGILOSO (ACESSO ADMIN/TÉCNICO): Matrícula Imobiliária nº 19.402 e nº 22.811. Custo efetivo por muda implantada: R\$ 14,80. Cláusula de penalidade contratual: R\$ 180.000,00 em caso de mortalidade superior a 20% não replantada.',
          ),
        ],
      ),
      EnvironmentalProject(
        id: 'proj-psa-02',
        code: 'PSA-2026-TQ02',
        name: 'Programa Produtor de Água & PSA — Mananciais do Rio Taquari',
        programType: 'PSA',
        watershed: 'Bacia Hidrográfica Taquari-Antas (Microbacia Arroio Castelhano)',
        municipalityHub: 'Venâncio Aires / Lajeado - RS',
        period: 'Mar/2026 a Fev/2028 (24 meses)',
        status: 'Em Execução',
        overallProgress: 74.0,
        totalTargetAreaHa: 215.5,
        targetSeedlingsCount: 42000,
        publicSummary:
            'Programa de Pagamento por Serviços Ambientais (PSA Hídrico e Biodiversidade) voltado a produtores rurais familiares que conservam remanescentes florestais, implantam terraços de infiltração, saneamento rural ecológico e proteção de olho-d\'água.',
        partnerCompany: 'HidroEnergia S.A. & Comitê de Bacia Taquari-Antas',
        confidentialTotalBudget: 1920000.00,
        confidentialContractCode: 'CT-SIG-PSA-2026/0118-B',
        confidentialTechnicalNotes:
            'NOTA TÉCNICA SIGILOSA: Repasses financeiros semestrais condicionados ao Índice de Qualidade Ambiental da Propriedade (IQAP >= 0.75). Auditoria bancária interna programada para Nov/2026 nas propriedades Sítio Boa Esperança e Chácara Água Limpa.',
        stages: const [
          ProjectStage(
            id: 'stg-psa-1',
            title: 'Etapa 1 — Chamada Pública, Habilitação Técnica e Valoração de PSA',
            description:
                'Vistoria de linha de base nas propriedades inscritas, cálculo de URE (Unidade de Referência de Ecossistema) e assinatura dos contratos individuais.',
            startDate: '01/03/2026',
            endDate: '31/05/2026',
            status: 'Concluída',
            progressPercent: 100.0,
            responsibleTeam: 'Comissão Técnica PSA (Dra. Helena Vasconcelos)',
            targetDeliverable: '100% das propriedades habilitadas e georreferenciadas',
          ),
          ProjectStage(
            id: 'stg-psa-2',
            title: 'Etapa 2 — Práticas Conservacionistas de Solo e Bacias de Contenção',
            description:
                'Construção de barraginhas de infiltração pluvial, terraceamento agrícola em nível e recuperação de estradas vicinais críticas.',
            startDate: '01/06/2026',
            endDate: '15/10/2026',
            status: 'Concluída',
            progressPercent: 100.0,
            responsibleTeam: 'Equipe de Engenharia Agronômica e Hidrologia',
            targetDeliverable: '45 bacias de infiltração concluídas e 92 ha com manejo conservacionista',
          ),
          ProjectStage(
            id: 'stg-psa-3',
            title: 'Etapa 3 — Vistoria Semestral de Verificação de Serviços Ambientais (1º Ciclo)',
            description:
                'Inspeção técnica in loco dos indicadores de conservação de solo, cobertura vegetal, turbidez da água e cumprimento das metas para liberação do PSA.',
            startDate: '16/10/2026',
            endDate: '31/05/2027',
            status: 'Em Andamento',
            progressPercent: 65.0,
            responsibleTeam: 'Equipe Técnica de Campo (Eng. Lucas Albuquerque)',
            targetDeliverable: 'Laudos individuais de aferição para pagamento do 1º e 2º lotes PSA',
          ),
          ProjectStage(
            id: 'stg-psa-4',
            title: 'Etapa 4 — Monitoramento Hidrossedimentológico Anual e Renovação PSA',
            description:
                'Análise comparativa de abatimento de erosão (USLE), ganho de vazão de base na estação seca e relatório público de impacto socioambiental.',
            startDate: '01/06/2027',
            endDate: '28/02/2028',
            status: 'Planejada',
            progressPercent: 20.0,
            responsibleTeam: 'Coordenação Geral & Hidrologia',
            targetDeliverable: 'Balanço Hídrico de Abatimento de Sedimentos (t/ha/ano)',
          ),
        ],
        documents: const [
          AuthorizedDocument(
            id: 'doc-psa-01',
            code: 'EDT-PSA-2026',
            title: 'Edital Técnico e Metodologia de Valoração de Serviços Ecossistêmicos',
            category: 'Plano Técnico',
            issueDate: '02/03/2026',
            version: 'v1.2 Oficial',
            fileSize: '3,1 MB (PDF)',
            summary:
                'Critérios públicos de pontuação ambiental (proteção de nascentes, cobertura florestal, práticas agrícolas sustentáveis) por hectare/ano.',
            isConfidential: false,
            confidentialContent:
                'Metodologia aberta para consulta de financiadores, produtores e sociedade civil.',
          ),
          AuthorizedDocument(
            id: 'doc-psa-02',
            code: 'LAU-HID-019',
            title: 'Boletim Trimestral de Qualidade da Água e Vazão de Mananciais',
            category: 'Laudo Hidrológico',
            issueDate: '15/09/2026',
            version: 'v3.0 Consolidado',
            fileSize: '5,4 MB (PDF)',
            summary:
                'Resultados agregados de pH, turbidez (NTU), oxigênio dissolvido e vazão específica nas microbacias monitoradas.',
            isConfidential: false,
            confidentialContent:
                'Dados consolidados abertos para prestação de contas ESG.',
          ),
          AuthorizedDocument(
            id: 'doc-psa-03',
            code: 'CTR-PSA-SIG-09',
            title: 'Contratos Individuais de Adesão PSA, Dados Bancários e Folha de Repasse',
            category: 'Termo de Adesão PSA',
            issueDate: '25/05/2026',
            version: 'v2.0 Confidencial LGPD',
            fileSize: '8,9 MB (PDF Restrito)',
            summary:
                'Relação nominal dos proprietários beneficiários, CPFs, códigos do CAR, contas bancárias e valores individuais de repasse financeiro.',
            isConfidential: true,
            confidentialContent:
                'CONTEÚDO SIGILOSO (ACESSO ADMIN/TÉCNICO): Beneficiário 1: João Batista Silveira (R\$ 2.450,00/mês - Sicredi Ag 0155). Beneficiário 2: Cooperativa Familiar Água Limpa (R\$ 3.180,00/mês - Banrisul Ag 0410). Retenção técnica de 5% para fundo de contingência climática.',
          ),
        ],
      ),
    ];
  }

  List<RuralProperty> _buildSeedProperties() {
    return const [
      // Propriedades do Projeto 1 (MUDA)
      RuralProperty(
        id: 'prop-muda-01',
        projectId: 'proj-muda-01',
        code: 'PROP-RP-01',
        name: 'Fazenda Santa Inês (Gleba Nascentes do Pardo)',
        municipality: 'Santa Cruz do Sul - RS',
        totalAreaHa: 185.0,
        restorationAreaHa: 54.5,
        areaDescription:
            '3 talhões de restauração ecológica (APP de cabeceira + mata ciliar de 50m + corredor ecológico de encosta).',
        mainSoilType: 'Argissolo Vermelho-Amarelo Eutrófico',
        conservationStatus: 'Em Restauração Ativa (Pegamento 89%)',
        centerLatitude: -29.7145,
        centerLongitude: -52.4280,
        polygonCoordinates: [
          GeoCoordinate(latitude: -29.7110, longitude: -52.4320),
          GeoCoordinate(latitude: -29.7115, longitude: -52.4240),
          GeoCoordinate(latitude: -29.7180, longitude: -52.4245),
          GeoCoordinate(latitude: -29.7175, longitude: -52.4325),
        ],
        ownerName: 'Antônio Carlos Dorneles',
        ownerCpf: '418.920.330-53',
        carRegistryCode: 'RS-4316808-9F82A140B71E4C928A1D',
        psaMonthlyValue: 1850.00,
        bankAccountSummary: 'Banco do Brasil — Ag. 0340-9 / CC 44.910-X',
      ),
      RuralProperty(
        id: 'prop-muda-02',
        projectId: 'proj-muda-01',
        code: 'PROP-RP-02',
        name: 'Sítio Vale das Araucárias',
        municipality: 'Sinimbu - RS',
        totalAreaHa: 92.0,
        restorationAreaHa: 38.0,
        areaDescription:
            '2 áreas de recomposição com enriquecimento florestal e nucleação (poleiros artificiais + plantio adensado em APP hídrica).',
        mainSoilType: 'Cambissolo Háplico Ta Eutrófico',
        conservationStatus: 'Estabilizada / Manutenção de Coroamento',
        centerLatitude: -29.5412,
        centerLongitude: -52.5194,
        polygonCoordinates: [
          GeoCoordinate(latitude: -29.5385, longitude: -52.5230),
          GeoCoordinate(latitude: -29.5390, longitude: -52.5155),
          GeoCoordinate(latitude: -29.5440, longitude: -52.5160),
          GeoCoordinate(latitude: -29.5435, longitude: -52.5235),
        ],
        ownerName: 'Beatriz Helena Kaufmann',
        ownerCpf: '602.145.880-15',
        carRegistryCode: 'RS-4320651-3C19D884E02A47B19F66',
        psaMonthlyValue: 1420.00,
        bankAccountSummary: 'Sicredi Vale — Ag. 0119 / CC 88.204-3',
      ),

      // Propriedades do Projeto 2 (PSA)
      RuralProperty(
        id: 'prop-psa-01',
        projectId: 'proj-psa-02',
        code: 'PROP-TQ-01',
        name: 'Sítio Boa Esperança das Águas',
        municipality: 'Venâncio Aires - RS',
        totalAreaHa: 110.0,
        restorationAreaHa: 64.0,
        areaDescription:
            'Área certificada no Programa Produtor de Água: 4 nascentes protegidas com caxambu, 18 bacias de contenção e 42 ha de mata nativa conservada.',
        mainSoilType: 'Neossolo Litólico / Chernossolo Argilúvico',
        conservationStatus: 'Conservação Alta (IQAP 0.88 - Elegível PSA Máximo)',
        centerLatitude: -29.6058,
        centerLongitude: -52.1932,
        polygonCoordinates: [
          GeoCoordinate(latitude: -29.6020, longitude: -52.1970),
          GeoCoordinate(latitude: -29.6025, longitude: -52.1895),
          GeoCoordinate(latitude: -29.6095, longitude: -52.1900),
          GeoCoordinate(latitude: -29.6090, longitude: -52.1975),
        ],
        ownerName: 'João Batista Silveira',
        ownerCpf: '295.774.110-04',
        carRegistryCode: 'RS-4322608-7A44E910C55B4D208E31',
        psaMonthlyValue: 2450.00,
        bankAccountSummary: 'Sicredi — Ag. 0155 / CC 19.302-7',
      ),
      RuralProperty(
        id: 'prop-psa-02',
        projectId: 'proj-psa-02',
        code: 'PROP-TQ-02',
        name: 'Chácara Agroecológica Água Limpa',
        municipality: 'Lajeado - RS',
        totalAreaHa: 145.5,
        restorationAreaHa: 78.5,
        areaDescription:
            'Sistema agroflorestal biodiverso em zona de recarga de aquífero + faixa ciliar integral no Arroio Castelhano.',
        mainSoilType: 'Latossolo Vermelho Distrófico',
        conservationStatus: 'Excelente (IQAP 0.92 - Referência Regional)',
        centerLatitude: -29.4650,
        centerLongitude: -51.9645,
        polygonCoordinates: [
          GeoCoordinate(latitude: -29.4615, longitude: -51.9685),
          GeoCoordinate(latitude: -29.4620, longitude: -51.9605),
          GeoCoordinate(latitude: -29.4685, longitude: -51.9610),
          GeoCoordinate(latitude: -29.4680, longitude: -51.9690),
        ],
        ownerName: 'Cláudio Renato Bruxel & Família',
        ownerCpf: '519.830.640-91',
        carRegistryCode: 'RS-4311403-1B90F332A88C4E179D04',
        psaMonthlyValue: 3180.00,
        bankAccountSummary: 'Banrisul — Ag. 0410 / CC 06.19283.0-8',
      ),
    ];
  }

  List<CollectionPoint> _buildSeedCollectionPoints() {
    return const [
      CollectionPoint(
        id: 'pt-muda-01',
        projectId: 'proj-muda-01',
        propertyId: 'prop-muda-01',
        code: 'PC-MUDA-01',
        name: 'Nascente Principal São João (Cabeceira Norte)',
        pointType: 'Nascente Hidrológica',
        latitude: -29.7132,
        longitude: -52.4295,
        altitudeMeters: 412.0,
        referenceAreaName: 'Talhão T-01 — APP Cabeceira Cercada',
        lastInspectionDate: '18/10/2026',
        monitoringStatus: 'Ativo — Vazão Estável (3,8 L/s)',
      ),
      CollectionPoint(
        id: 'pt-muda-02',
        projectId: 'proj-muda-01',
        propertyId: 'prop-muda-01',
        code: 'PC-MUDA-02',
        name: 'Parcela Permanente de Mudas #04 (Mata Ciliar)',
        pointType: 'Parcela de Mudas',
        latitude: -29.7158,
        longitude: -52.4264,
        altitudeMeters: 388.5,
        referenceAreaName: 'Talhão T-02 — Margem Direita Rio Pardo',
        lastInspectionDate: '20/10/2026',
        monitoringStatus: 'Ativo — Sobrevivência 91,4%',
      ),
      CollectionPoint(
        id: 'pt-muda-03',
        projectId: 'proj-muda-01',
        propertyId: 'prop-muda-02',
        code: 'PC-MUDA-03',
        name: 'Parcela de Regeneração e Nucleação #02',
        pointType: 'Parcela de Mudas',
        latitude: -29.5408,
        longitude: -52.5188,
        altitudeMeters: 520.0,
        referenceAreaName: 'Gleba Encosta das Araucárias',
        lastInspectionDate: '12/10/2026',
        monitoringStatus: 'Atenção — Controle de Formigas Programado',
      ),
      CollectionPoint(
        id: 'pt-psa-01',
        projectId: 'proj-psa-02',
        propertyId: 'prop-psa-01',
        code: 'PC-PSA-01',
        name: 'Olho d\'Água Pedra Branca (Caxambu Protegido)',
        pointType: 'Nascente Hidrológica',
        latitude: -29.6049,
        longitude: -52.1941,
        altitudeMeters: 345.0,
        referenceAreaName: 'Zonas de Recarga Hídrica Sul',
        lastInspectionDate: '25/10/2026',
        monitoringStatus: 'Excelente — Turbidez 1,9 NTU / pH 6,8',
      ),
      CollectionPoint(
        id: 'pt-psa-02',
        projectId: 'proj-psa-02',
        propertyId: 'prop-psa-01',
        code: 'PC-PSA-02',
        name: 'Bacia de Contenção e Terraço Agrícola #12',
        pointType: 'Conservação de Solo',
        latitude: -29.6071,
        longitude: -52.1918,
        altitudeMeters: 329.0,
        referenceAreaName: 'Encosta Agrícola Conservacionista',
        lastInspectionDate: '25/10/2026',
        monitoringStatus: 'Ativo — Sem Feições Erosivas',
      ),
      CollectionPoint(
        id: 'pt-psa-03',
        projectId: 'proj-psa-02',
        propertyId: 'prop-psa-02',
        code: 'PC-PSA-03',
        name: 'Estação Fluviométrica Arroio Castelhano (SAF)',
        pointType: 'Nascente Hidrológica',
        latitude: -29.4642,
        longitude: -51.9652,
        altitudeMeters: 274.0,
        referenceAreaName: 'Corredor Agroflorestal Ciliar',
        lastInspectionDate: '28/10/2026',
        monitoringStatus: 'Excelente — Vazão de Base +14% vs. Linha Base',
      ),
    ];
  }

  // ===========================================================================
  // SEED DATA REALISTA: FORMULÁRIOS DE CAMPO E FILA OFFLINE (FASE 2)
  // Inclui: 1 Sincronizado com trilha de auditoria, 1 Pendente Offline e 1 em Conflito
  // ===========================================================================
  List<FieldFormRecord> _buildSeedFieldForms() {
    return const [
      FieldFormRecord(
        clientUuid: 'uuid-seed-synced-001',
        projectId: 'proj-muda-01',
        propertyId: 'prop-muda-01',
        pointId: 'pt-muda-02',
        templateName: 'Vistoria de Sobrevivência de Mudas (Muda)',
        vegetationStage:
            'Estágio Intermediário — Fechamento de Entrelinhas (1 a 3 anos)',
        survivalRatePercent: 91.4,
        erosionStatus: 'Ausente — Solo Estabilizado com Cobertura Vegetal',
        invasiveSpeciesPresent: false,
        maintenancePerformed:
            'Coroamento Manual + Controle de Formigas Cortadeiras',
        technicalNotes:
            'Pegamento excelente de Inga vera e Cedrela fissilis na parcela #04. Nota sigilosa: verificado marco divisório do TCA judicial sem invasão de gado.',
        isConfidential: true,
        latitude: -29.7158,
        longitude: -52.4264,
        gpsAccuracyMeters: 3.4,
        photoLocalPath: 'demo://foto_campo_pc_muda_02_parcela04.jpg',
        photoCapturedAt: '2026-10-20T09:40:00Z',
        photoCaption:
            'Vista panorâmica da Parcela Permanente #04 — Coordenadas -29.7158, -52.4264 (±3,4m)',
        syncStatus: SyncStatus.synced,
        version: 2,
        authorId: 'usr-tec-01',
        authorName: 'Eng. Lucas Albuquerque',
        authorRole: 'Equipe Técnica',
        createdAt: '2026-10-20T09:42:15Z',
        syncedAt: '2026-10-20T18:15:04Z',
        auditHistory: [
          AuditLogEntry(
            id: 'aud-seed-1a',
            action: 'CRIACAO_OFFLINE',
            summary:
                'Formulário registrado em campo sem internet com GPS (±3,4m) e foto georreferenciada.',
            authorId: 'usr-tec-01',
            authorName: 'Eng. Lucas Albuquerque',
            authorRole: 'Equipe Técnica',
            timestamp: '2026-10-20T09:42:15Z',
            version: 1,
          ),
          AuditLogEntry(
            id: 'aud-seed-1b',
            action: 'SINCRONIZADO_SERVIDOR',
            summary:
                'Sincronizado de forma idempotente (UUID uuid-seed-synced-001) com a plataforma Muda/PSA.',
            authorId: 'usr-tec-01',
            authorName: 'Eng. Lucas Albuquerque',
            authorRole: 'Equipe Técnica',
            timestamp: '2026-10-20T18:15:04Z',
            version: 2,
            syncedAt: '2026-10-20T18:15:04Z',
          ),
        ],
      ),
      FieldFormRecord(
        clientUuid: 'uuid-seed-pending-002',
        projectId: 'proj-psa-02',
        propertyId: 'prop-psa-01',
        pointId: 'pt-psa-01',
        templateName: 'Monitoramento de APP e Nascente (PSA)',
        vegetationStage:
            'Estágio Avançado — Formação de Dossel e Regeneração Natural',
        survivalRatePercent: 94.0,
        erosionStatus: 'Ausente — Solo Estabilizado com Cobertura Vegetal',
        invasiveSpeciesPresent: false,
        maintenancePerformed:
            'Desassoreamento de Bacia de Contenção / Olho d\'Água (PSA)',
        technicalNotes:
            'Olho d\'Água Pedra Branca com proteção de caxambu íntegra, água cristalina (turbidez 1,9 NTU) e vazão contínua para cálculo de URE/PSA.',
        isConfidential: false,
        latitude: -29.6049,
        longitude: -52.1941,
        gpsAccuracyMeters: 4.1,
        photoLocalPath: 'demo://foto_campo_pc_psa_01_caxambu.jpg',
        photoCapturedAt: '2026-10-25T14:20:00Z',
        photoCaption:
            'Inspeção da Nascente Pedra Branca — Coordenadas -29.6049, -52.1941 (±4,1m)',
        syncStatus: SyncStatus.pending,
        version: 1,
        authorId: 'usr-tec-01',
        authorName: 'Eng. Lucas Albuquerque',
        authorRole: 'Equipe Técnica',
        createdAt: '2026-10-25T14:22:30Z',
        auditHistory: [
          AuditLogEntry(
            id: 'aud-seed-2a',
            action: 'CRIACAO_OFFLINE',
            summary:
                'Coleta realizada em modo offline na microbacia Arroio Castelhano. Aguardando conexão na fila SQLite.',
            authorId: 'usr-tec-01',
            authorName: 'Eng. Lucas Albuquerque',
            authorRole: 'Equipe Técnica',
            timestamp: '2026-10-25T14:22:30Z',
            version: 1,
          ),
        ],
      ),
      FieldFormRecord(
        clientUuid: 'uuid-seed-conflict-003',
        projectId: 'proj-muda-01',
        propertyId: 'prop-muda-02',
        pointId: 'pt-muda-03',
        templateName: 'Inspeção de Erosão e Cercamento',
        vegetationStage:
            'Estágio Inicial — Pegamento de Mudas (0 a 12 meses)',
        survivalRatePercent: 79.5,
        erosionStatus: 'Laminar Leve — Sem Sulcos Ativos',
        invasiveSpeciesPresent: true,
        maintenancePerformed:
            'Roçada Seletiva de Gramíneas Exóticas + Adubação de Cobertura',
        technicalNotes:
            'Vistoria de campo identificou reinfestação focal de braquiária na borda leste e necessidade de replantio de 120 mudas no talhão de encosta.',
        isConfidential: false,
        latitude: -29.5408,
        longitude: -52.5188,
        gpsAccuracyMeters: 2.9,
        photoLocalPath: 'demo://foto_campo_pc_muda_03_encosta.jpg',
        photoCapturedAt: '2026-10-26T10:55:00Z',
        photoCaption:
            'Parcela de Regeneração #02 Sinimbu — Coordenadas -29.5408, -52.5188 (±2,9m)',
        syncStatus: SyncStatus.conflict,
        syncErrorMessage:
            'Conflito de versão detectado (HTTP 409): a plataforma central possui revisão concorrente v2 registrada pela Coordenação.',
        version: 1,
        authorId: 'usr-tec-01',
        authorName: 'Eng. Lucas Albuquerque',
        authorRole: 'Equipe Técnica',
        createdAt: '2026-10-26T11:00:00Z',
        conflictServerData: ConflictServerPayload(
          serverVersion: 2,
          serverAuthorName: 'Dra. Helena Vasconcelos',
          serverAuthorRole: 'Administrador',
          serverUpdatedAt: '2026-10-26T11:30:00Z',
          vegetationStage:
              'Área sob Replantio / Adensamento Emergencial',
          survivalRatePercent: 84.0,
          erosionStatus: 'Sulcos Erosivos Moderados — Requer Contenção',
          invasiveSpeciesPresent: true,
          maintenancePerformed:
              'Manutenção de Cercamento de APP + Limpeza de Aceiro',
          technicalNotes:
              'Revisão via aerofotogrametria/plataforma: classificado como área sob replantio prioritário com taxa estimada de 84,0% após reposição parcial.',
          divergenceReason:
              'Registro editado simultaneamente no painel web administrativo enquanto a equipe técnica operava offline em campo.',
        ),
        auditHistory: [
          AuditLogEntry(
            id: 'aud-seed-3a',
            action: 'CRIACAO_OFFLINE',
            summary:
                'Coleta em campo registrada sem conectividade no Sítio Vale das Araucárias.',
            authorId: 'usr-tec-01',
            authorName: 'Eng. Lucas Albuquerque',
            authorRole: 'Equipe Técnica',
            timestamp: '2026-10-26T11:00:00Z',
            version: 1,
          ),
          AuditLogEntry(
            id: 'aud-seed-3b',
            action: 'CONFLITO_DETECTADO',
            summary:
                'Tentativa de sincronização detectou divergência (v1 local vs v2 servidor — Dra. Helena Vasconcelos). Aguardando decisão técnica (AM-04).',
            authorId: 'usr-tec-01',
            authorName: 'Eng. Lucas Albuquerque',
            authorRole: 'Equipe Técnica',
            timestamp: '2026-10-26T17:05:12Z',
            version: 1,
          ),
        ],
      ),
    ];
  }
}

