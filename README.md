# EcoMonitor — Monitoramento Ambiental (Programas Muda & PSA)

Aplicativo móvel multiplataforma desenvolvido em **Flutter** para gestão integrada, coleta em campo *offline-first*, mapeamento georreferenciado (GIS/KML), análise hidrossedimentológica (**CONAMA nº 357/2005**), conservação do solo (**USLE**) e emissão de relatórios técnicos (**PDF** e **Excel/CSV**) dos programas **Muda** (Recomposição Florestal) e **PSA** (Pagamento por Serviços Ambientais).

---

## Sumário

1. [Instruções de Compilação e Execução (APK / AAB / Testes)](#1-instruções-de-compilação-e-execução-apk--aab--testes)
2. [Credenciais e Perfis de Acesso (RBAC & Sigilo AM-01)](#2-credenciais-e-perfis-de-acesso-rbac--sigilo-am-01)
3. [Barra de Modo Demonstração (Homologação em Sala de Aula)](#3-barra-de-modo-demonstração-homologação-em-sala-de-aula)
4. [Fluxos de Navegação e Documentação das Telas](#4-fluxos-de-navegação-e-documentação-das-telas)
5. [Matriz de Rastreabilidade dos Requisitos (AM-01 a AM-12 e Critérios de Aceite)](#5-matriz-de-rastreabilidade-dos-requisitos-am-01-a-am-12-e-critérios-de-aceite)
6. [Arquitetura de Dados Local (Schema SQLite `sqflite` v3)](#6-arquitetura-de-dados-local-schema-sqlite-sqflite-v3)
7. [API REST / JWT Simulada e Sincronização Idempotente](#7-api-rest--jwt-simulada-e-sincronização-idempotente)
8. [Permissões de Dispositivo Utilizadas](#8-permissões-de-dispositivo-utilizadas)

---

## 1. Instruções de Compilação e Execução (APK / AAB / Testes)

O aplicativo é **100% autônomo** e autocontido: não exige chaves de API pagas, configuração de servidor externo ou conexão obrigatória com a internet para avaliação. O banco SQLite local (`sqflite`) é inicializado automaticamente no primeiro uso com dados realistas (*Seed Data*) dos programas Muda e PSA.

### Pré-requisitos
- **Flutter SDK**: `>= 3.13.5` (Dart 3)
- **Android SDK**: API 21+ (Android 5.0 Lollipop ou superior)

### Comandos Principais

```bash
# 1. Instalar dependências do projeto
flutter pub get

# 2. Executar análise estática de código (0 erros / 0 warnings)
flutter analyze

# 3. Executar a suíte completa de testes automatizados (Unitários + Widget Tests das Fases 1, 2, 3 e 4)
flutter test

# 4. Executar o aplicativo em um emulador ou dispositivo físico conectado
flutter run

# 5. Compilar APK de Debug para instalação direta em dispositivos Android de avaliação
flutter build apk --debug
# Caminho gerado: build/app/outputs/flutter-apk/app-debug.apk

# 6. Compilar APK de Release ou Android App Bundle (AAB)
flutter build apk --release
flutter build appbundle --release
```

---

## 2. Credenciais e Perfis de Acesso (RBAC & Sigilo AM-01)

Na tela de login (`LoginScreen`), o avaliador pode autenticar digitando e-mail/senha ou utilizando os **botões de Login Rápido (1 toque)**, além de poder alternar de perfil em tempo real no topo de qualquer tela para inspecionar o bloqueio/liberação de dados sigilosos (**AM-01**):

| Perfil (`UserRole`) | E-mail | Senha Padrão | Escopo de Permissões e Controle de Sigilo (AM-01) |
| :--- | :--- | :--- | :--- |
| **Administrador** (`admin`) | `admin@muda.org.br` | `123456` | **Acesso Total**: visualiza dados abertos e sigilosos (CPF, código CAR, repasses financeiros mensais PSA, contratos, laudos laboratoriais confidenciais e acordos individuais), realiza coletas em campo, sincroniza fila e resolve conflitos. |
| **Equipe Técnica** (`tecnico`) | `tecnico@muda.org.br` | `123456` | **Operação Técnica & Campo**: visualiza dados técnicos e sigilosos autorizados, registra formulários de campo offline com GPS e fotos, cadastra laudos CONAMA 357 e unidades de solo, sincroniza fila e resolve conflitos. |
| **Empresa Contratante** (`empresa`) | `empresa@parceira.com.br` | `123456` | **Acesso Restrito (Somente Dados Abertos)**: consulta cronogramas, indicadores consolidados e relatórios com **mascaramento automático** de CPF (`•••.•••.•••-••`), CAR, orçamento/repasses PSA, notas técnicas restritas e acordos de proprietários (LGPD / Sigilo Contratual). Bloqueado para escrita em campo. |

---

## 3. Barra de Modo Demonstração (Homologação em Sala de Aula)

Presente no topo do `HomeShellScreen`, permite testar todos os cenários críticos de campo sem sair da tela:

1. **Status `ONLINE` / `OFFLINE (Campo)`**: simula perda total de sinal de internet em áreas rurais remotas (**AM-04**). Quando `OFFLINE`, novos formulários são gravados localmente no SQLite com status `PENDENTE OFFLINE`.
2. **Badge `Fila Offline: N • Sync`**: exibe em tempo real o número de registros aguardando envio e permite disparar a sincronização imediata.
3. **Botão `Simular Falha Rede (AM-12)`**: força um erro `HTTP 503 Service Unavailable / Gateway Timeout` na próxima sincronização, demonstrando que nenhum dado ou foto local é perdido e os itens permanecem protegidos na fila para reenvio (**AM-12**).
4. **Botão `Simular Conflito (AM-04)`**: força uma divergência de versão (`HTTP 409 Conflict`) com a plataforma central no próximo envio, habilitando o modal comparativo lado a lado (*Versão de Campo* vs *Versão da Plataforma*) com registro no histórico de auditoria (**AM-04** e **AM-11**).
5. **Inspetor de Token JWT (`vpn_key`)**: exibe no cabeçalho o token JWT (`HS256`) assinado localmente e os escopos decodificados (`confidential_access`, `field_write_access`, `exp`).

---

## 4. Fluxos de Navegação e Documentação das Telas

A navegação principal pós-login é estruturada em **5 abas inferiores (`NavigationBar`)**:

### Aba 1 — Projetos & Áreas (`lib/screens/projects_screen.dart`)
- **Requisitos atendidos**: `AM-01`, `AM-02`.
- Lista projetos dos programas **Muda** e **PSA**, com filtro por programa (`TODOS`, `MUDA`, `PSA`) e busca textual por nome, código, bacia hidrográfica ou propriedade rural.
- Ao abrir um projeto (`ProjectDetailScreen`), apresenta 4 sub-abas:
  1. **Visão Geral & Sigilo**: resumo público, metas de área/mudas e bloco de informações contratuais sigilosas (visível apenas para Admin/Técnico).
  2. **Propriedades & Áreas**: fichas das propriedades rurais, tipo de solo, área de restauração e proteção LGPD sobre CPF, CAR e valor mensal PSA.
  3. **Etapas & Cronograma**: linha do tempo das etapas físicas do projeto com percentual de avanço e entregáveis.
  4. **Documentos Autorizados**: licenças, termos de adesão PSA, planos técnicos e laudos com controle de sigilo por documento.

### Aba 2 — Coleta Campo (`lib/screens/field_forms_sync_screen.dart` — Seção Nova Coleta)
- **Requisitos atendidos**: `AM-01`, `AM-03`, `AM-05`, `AM-11`.
- Formulário estruturado conforme modelos da plataforma (*Vistoria de Sobrevivência de Mudas*, *Monitoramento de APP e Nascente*, *Inspeção de Erosão e Cercamento*).
- **Validação obrigatória de campos**: percentual de sobrevivência (`0%` a `100%`), estágio da vegetação, status de erosão, presença de exóticas invasoras, manutenção realizada e observações técnicas.
- **Captura de Coordenadas GPS e Fotos Georreferenciadas (`AM-05`)**: suporta captura via hardware (`geolocator` + `image_picker`) e modo de **Captura Georreferenciada de Demonstração** com carimbo de latitude, longitude, precisão em metros e timestamp UTC.
- Para o perfil `Empresa Contratante`, exibe banner de bloqueio somente leitura (**AM-01**).

### Aba 3 — Coleta & Sync (`lib/screens/field_forms_sync_screen.dart` — Central de Sincronização)
- **Requisitos atendidos**: `AM-04`, `AM-11`, `AM-12`, **1º e 2º Critérios de Aceite**.
- Painel da fila local SQLite com filtros (`TODOS`, `NA FILA`, `SINCRONIZADOS`, `CONFLITOS`).
- **Sincronização Idempotente**: cada coleta recebe um `clientUuid` único gerado offline; reenvios repetidos atualizam o mesmo registro sem jamais duplicar entradas.
- **Resolução de Conflitos (`AM-04`)**: modal comparativo lado a lado permitindo escolher entre *Manter Versão de Campo* ou *Aceitar Versão da Plataforma*.
- **Trilha de Auditoria e Autoria (`AM-11`)**: modal detalhando todas as operações (`CRIACAO_OFFLINE`, `FALHA_REDE_AM12`, `CONFLITO_DETECTADO`, `SINCRONIZADO_SERVIDOR`) com autor, perfil, versão e data/hora de sincronização.

### Aba 4 — Mapa & Histórico (`lib/screens/interactive_map_screen.dart`)
- **Requisitos atendidos**: `AM-06`, `AM-07`.
- Mapa interativo (`flutter_map`) exibindo:
  - Polígonos georreferenciados das propriedades rurais e áreas de restauração;
  - **Camadas KML Processadas** e traçado da rede hidrográfica;
  - **Croqui Técnico Esquemático** (`CustomPaint`) e inspetor do código XML KML processado (`SIRGAS 2000 / UTM 22S`);
  - Marcadores clicáveis dos **Pontos de Coleta** com ficha consolidada de histórico de vistorias, qualidade da água e botão de salto rápido para os laudos do ponto.

### Aba 5 — Indicadores & Relatórios (`lib/screens/dashboard_reports_screen.dart` + `lib/screens/water_soil_analysis_screen.dart`)
- **Requisitos atendidos**: `AM-07`, `AM-08`, `AM-09`, `AM-10`, **3º Critério de Aceite**.
- Possui seletor superior alternando entre duas visões complementares:
  1. **Dashboards & Relatórios (`AM-08` / `AM-09`)**:
     - Filtro por programa (`Todos`, `Programa Muda`, `Programa PSA`);
     - **Cards de KPIs**: Hectares em restauração, Mudas & sobrevivência média (%), Conformidade CONAMA 357/2005 (%), Área de conservação do solo e abatimento USLE (t/ano);
     - **3 Gráficos Interativos (`fl_chart`)**:
       - `BarChart`: evolução da taxa de sobrevivência de mudas por vistoria frente à meta de 80%;
       - `LineChart`: evolução de Oxigênio Dissolvido (OD mg/L) por ponto frente ao limite mínimo CONAMA 357/2005 (`>= 5,0 mg/L`);
       - `PieChart` + Barras de Progresso: proporção de conformidade ambiental e avanço físico do cronograma dos projetos;
     - **Geração e Compartilhamento no Celular (`AM-09`)**:
       - Botão **"Visualizar / Compartilhar Relatório PDF"**: gera documento PDF multipágina (`pdf` + `printing`) com cabeçalho institucional, KPIs, cronograma, tabela CONAMA 357, unidades de solo e vistorias de campo (respeitando o sigilo `AM-01`);
       - Botão **"Exportar Planilha Excel/CSV"**: formata e compartilha planilha `.csv` (`share_plus`) compatível com Excel contendo todas as seções técnicas (respeitando o sigilo `AM-01`).
  2. **Laudos Água CONAMA 357 & Conservação do Solo (`AM-07` / `AM-10`)**:
     - Avaliador automático dos 6 parâmetros da **Resolução CONAMA nº 357/2005 (Classe 2)**: pH (`6,0–9,0`), Turbidez (`<= 100 UNT`), OD (`>= 5,0 mg/L`), DBO (`<= 5,0 mg/L`), Fósforo Total (`<= 0,050 mg/L`) e Coliformes Termotolerantes (`<= 1000 NMP/100mL`);
     - Comparativo histórico entre 1ª Campanha (Linha de Base) e 2ª Campanha (Monitoramento), evidenciando a recuperação hidroambiental;
     - Cadastro e consulta de **Unidades Modelo de Conservação do Solo (`AM-10`)** com práticas conservacionistas e cálculo automático de abatimento de erosão hídrica (**USLE** em `t/ha/ano` e `%`).

---

## 5. Matriz de Rastreabilidade dos Requisitos (AM-01 a AM-12 e Critérios de Aceite)

| Código | Descrição do Requisito | Arquivos Principais de Implementação |
| :--- | :--- | :--- |
| **AM-01** | Perfis Administrador, Equipe Técnica e Empresa com proteção de dados sigilosos e abertos | `lib/models/user_profile.dart`, `lib/screens/login_screen.dart`, `lib/screens/projects_screen.dart`, `lib/services/report_export_service.dart` |
| **AM-02** | Consulta de projetos Muda/PSA, propriedades, áreas, etapas, cronogramas e documentos | `lib/models/project_models.dart`, `lib/screens/projects_screen.dart`, `lib/services/database_service.dart` |
| **AM-03** | Registro de dados de campo via formulários configurados com validação de campos | `lib/models/field_form_record.dart`, `lib/screens/field_forms_sync_screen.dart` |
| **AM-04** | Coleta offline com armazenamento local, fila de sincronização e tratamento de conflitos | `lib/services/mock_api_sync_service.dart`, `lib/screens/field_forms_sync_screen.dart`, `lib/state/app_state.dart` |
| **AM-05** | Captura de coordenadas GPS e fotos georreferenciadas associadas ao ponto de coleta | `lib/screens/field_forms_sync_screen.dart`, `lib/models/field_form_record.dart` |
| **AM-06** | Visualização em mapa interativo das propriedades, áreas, camadas KML, croqui e pontos | `lib/screens/interactive_map_screen.dart`, `lib/models/water_soil_models.dart` |
| **AM-07** | Registro e consulta de análises de água por ponto com comparativo histórico e CONAMA 357 | `lib/models/water_soil_models.dart`, `lib/screens/water_soil_analysis_screen.dart` |
| **AM-08** | Dashboards com indicadores de monitoramento por projeto ou conjunto de projetos | `lib/screens/dashboard_reports_screen.dart`, `lib/services/report_export_service.dart` |
| **AM-09** | Geração e compartilhamento de relatórios em PDF e planilhas Excel/CSV no celular | `lib/services/report_export_service.dart`, `lib/screens/dashboard_reports_screen.dart` |
| **AM-10** | Registro e acompanhamento de unidades modelo de conservação do solo | `lib/models/water_soil_models.dart`, `lib/screens/water_soil_analysis_screen.dart` |
| **AM-11** | Histórico de alterações, autoria e data/hora de sincronização por registro | `lib/models/field_form_record.dart`, `lib/screens/field_forms_sync_screen.dart` |
| **AM-12** | Tratamento de falhas de sincronização sem perda dos dados locais | `lib/services/mock_api_sync_service.dart`, `lib/screens/home_shell_screen.dart` |

---

## 6. Arquitetura de Dados Local (Schema SQLite `sqflite` v3)

O banco de dados local `muda_psa_monitoring_v3.db` é gerenciado por `DatabaseService` (`lib/services/database_service.dart`) e possui **8 tabelas relacionais**:

1. `users`: credenciais locais com senha protegida por hash `SHA-256` com *salt* (`id`, `name`, `email`, `password_hash`, `organization`, `registration_code`, `role`).
2. `active_session`: persistência da sessão autenticada e token JWT (`id`, `user_id`, `jwt_token`, `login_timestamp`).
3. `projects`: projetos dos programas Muda e PSA (`id`, `code`, `name`, `program_type`, `watershed`, `municipality_hub`, `overall_progress`, `total_target_area_ha`, `target_seedlings_count`, `confidential_total_budget`, `confidential_contract_code`, `stages_json`, `documents_json`).
4. `properties`: propriedades rurais georreferenciadas e dados protegidos por LGPD (`id`, `project_id`, `code`, `name`, `total_area_ha`, `restoration_area_ha`, `polygon_json`, `owner_name`, `owner_cpf`, `car_registry_code`, `psa_monthly_value`).
5. `collection_points`: pontos de coleta georreferenciados (`id`, `project_id`, `property_id`, `code`, `name`, `point_type`, `latitude`, `longitude`, `altitude_meters`, `monitoring_status`).
6. `field_forms_local`: formulários coletados em campo e fila de sincronização idempotente (`client_uuid PRIMARY KEY`, `project_id`, `property_id`, `point_id`, `template_name`, `survival_rate_percent`, `latitude`, `longitude`, `gps_accuracy_meters`, `photo_local_path`, `sync_status`, `version`, `author_id`, `created_at`, `synced_at`, `conflict_server_json`, `audit_history_json`).
7. `water_analyses`: laudos laboratoriais de qualidade da água CONAMA 357/2005 (`id`, `project_id`, `property_id`, `point_id`, `report_code`, `sample_date`, `campaign_name`, `ph`, `turbidity_unt`, `dissolved_oxygen_mgl`, `dbo_mgl`, `total_phosphorus_mgl`, `thermotolerant_coliforms_nmp`, `flow_rate_ls`, `is_confidential_report`, `confidential_lab_notes`).
8. `soil_conservation_units`: unidades modelo de conservação do solo e abatimento USLE (`id`, `project_id`, `property_id`, `point_id`, `code`, `name`, `area_ha`, `slope_percent`, `adopted_practices_json`, `vegetal_cover_percent`, `baseline_erosion_ton_ha_year`, `current_erosion_ton_ha_year`, `erosion_abatement_ton_ha_year`, `confidential_owner_agreement`).

---

## 7. API REST / JWT Simulada e Sincronização Idempotente

A camada `MockApiSyncService` (`lib/services/mock_api_sync_service.dart`) e `JwtAuthSimulator` (`lib/models/user_profile.dart`) simulam localmente a plataforma central REST:

- `POST /api/v1/auth/login`: autentica credenciais contra o banco e emite token JWT assinado via `HMAC-SHA256` contendo `sub`, `role`, `confidential_access`, `field_write_access`, `iat` e `exp`.
- `POST /api/v1/sync/field-forms` (Upsert Idempotente por `clientUuid`):
  - Valida assinatura e validade temporal do header `Authorization: Bearer <jwt>`;
  - Verifica permissão de escrita do perfil (`field_write_access == true`);
  - Retorna `HTTP 200 OK` incrementando versão e gravando carimbo `syncedAt` e log `SINCRONIZADO_SERVIDOR`;
  - Retorna `HTTP 503 Service Unavailable` quando a falha de rede está ativa (`AM-12`), preservando os registros na fila SQLite local;
  - Retorna `HTTP 409 Conflict` quando detecta divergência de versão (`AM-04`), anexando o `ConflictServerPayload` para decisão do usuário.

---

## 8. Permissões de Dispositivo Utilizadas

Configuradas para operação em dispositivos Android/iOS:
- `ACCESS_FINE_LOCATION` e `ACCESS_COARSE_LOCATION` (`geolocator`): captura de coordenadas GPS de alta precisão nos pontos de coleta em campo (`AM-05`).
- `CAMERA` e leitura de mídia (`image_picker`): registro fotográfico georreferenciado de nascentes, talhões de mudas e feições erosivas (`AM-05`).
- `INTERNET`: carregamento opcional de tiles cartográficos OpenStreetMap quando online e compartilhamento de arquivos PDF/CSV (`printing` / `share_plus`). O aplicativo opera integralmente em modo *offline* caso não haja conectividade.
