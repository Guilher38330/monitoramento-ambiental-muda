import 'package:flutter/material.dart';
import '../models/user_profile.dart';
import '../state/app_state.dart';
import 'field_forms_sync_screen.dart';
import 'interactive_map_screen.dart';
import 'projects_screen.dart';
import 'water_soil_analysis_screen.dart';

/// Shell principal pós-autenticação:
/// - AppBar com perfil ativo (ADMIN / TÉCNICO / EMPRESA), troca rápida de perfil e inspetor de Token JWT
/// - Barra Superior de Modo Demonstração (Online/Offline, Simular Falha de Rede AM-12, Simular Conflito AM-04, Fila Pendente + Sync Rápido)
/// - NavigationBar inferior com as 5 seções do sistema (Fases 1, 2 e 3 ativas)
class HomeShellScreen extends StatefulWidget {
  final AppState appState;

  const HomeShellScreen({
    super.key,
    required this.appState,
  });

  @override
  State<HomeShellScreen> createState() => _HomeShellScreenState();
}

class _HomeShellScreenState extends State<HomeShellScreen> {
  int _selectedTabIndex = 0;
  String? _focusedWaterPointId;

  @override
  Widget build(BuildContext context) {
    final user = widget.appState.currentUser!;

    return Scaffold(
      backgroundColor: const Color(0xFFF3F7F4),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1B5E20),
        foregroundColor: Colors.white,
        titleSpacing: 14,
        title: Row(
          children: [
            const Icon(Icons.eco_rounded, color: Color(0xFFA5D6A7), size: 22),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Monitoramento Muda & PSA',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    '${user.name} (${user.email})',
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11.5,
                      color: Color(0xFFC8E6C9),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          // Badge de Perfil (AM-01) com menu de troca rápida para demonstração
          PopupMenuButton<UserRole>(
            key: const Key('profile_switcher_menu'),
            tooltip: 'Trocar Perfil de Acesso (Demonstração AM-01)',
            onSelected: (role) {
              widget.appState.quickLoginAsRole(role);
            },
            itemBuilder: (context) => [
              const PopupMenuItem<UserRole>(
                enabled: false,
                child: Text(
                  'Alternar Perfil Instantaneamente (AM-01)',
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
                  key: Key('switch_role_${role.name}'),
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
              margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: user.role.badgeColor,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withValues(alpha: 0.5)),
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
          IconButton(
            key: const Key('jwt_inspector_button'),
            tooltip: 'Inspecionar Token JWT e Permissões',
            icon: const Icon(Icons.vpn_key_rounded, size: 20),
            onPressed: () => _showJwtInspectorDialog(context),
          ),
          IconButton(
            key: const Key('logout_button'),
            tooltip: 'Encerrar Sessão (Logout)',
            icon: const Icon(Icons.logout_rounded, size: 20),
            onPressed: () => widget.appState.logout(),
          ),
        ],
      ),
      body: Column(
        children: [
          _buildDemoModeTopBar(context),
          Expanded(
            child: _buildCurrentTabBody(context, user),
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        key: const Key('main_bottom_navigation'),
        selectedIndex: _selectedTabIndex,
        onDestinationSelected: (index) {
          setState(() {
            _selectedTabIndex = index;
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.folder_special_outlined),
            selectedIcon: Icon(Icons.folder_special_rounded),
            label: 'Projetos & Áreas',
          ),
          NavigationDestination(
            icon: Icon(Icons.add_location_alt_outlined),
            selectedIcon: Icon(Icons.add_location_alt_rounded),
            label: 'Coleta Campo',
          ),
          NavigationDestination(
            icon: Icon(Icons.sync_outlined),
            selectedIcon: Icon(Icons.sync_rounded),
            label: 'Coleta & Sync',
          ),
          NavigationDestination(
            icon: Icon(Icons.map_outlined),
            selectedIcon: Icon(Icons.map_rounded),
            label: 'Mapa & Histórico',
          ),
          NavigationDestination(
            icon: Icon(Icons.insights_outlined),
            selectedIcon: Icon(Icons.insights_rounded),
            label: 'Indicadores',
          ),
        ],
      ),
    );
  }

  /// Barra de Modo Demonstração (Online/Offline, Falha de Rede AM-12, Conflito AM-04 + Fila e Sync Rápido)
  Widget _buildDemoModeTopBar(BuildContext context) {
    final isOnline = widget.appState.isOnline;
    final simFail = widget.appState.simulateNetworkFailure;
    final simConflict = widget.appState.simulateConflictOnNextSync;
    final pendingCount = widget.appState.pendingSyncCount;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: isOnline ? const Color(0xFF0D3B1E) : const Color(0xFF4E342E),
        border: const Border(
          bottom: BorderSide(color: Color(0xFF1B5E20)),
        ),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            const Icon(
              Icons.science_outlined,
              color: Color(0xFFA5D6A7),
              size: 16,
            ),
            const SizedBox(width: 6),
            const Text(
              'MODO DEMONSTRAÇÃO:',
              style: TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.4,
              ),
            ),
            const SizedBox(width: 10),
            // Toggle Online / Offline
            _buildDemoToggleChip(
              chipKey: const Key('demo_toggle_online'),
              icon: isOnline ? Icons.cloud_done_rounded : Icons.cloud_off_rounded,
              label: isOnline ? 'Status: ONLINE' : 'Status: OFFLINE (Campo)',
              active: isOnline,
              activeColor: const Color(0xFF2E7D32),
              inactiveColor: const Color(0xFFD84315),
              onTap: () => widget.appState.toggleOnlineStatus(),
            ),
            const SizedBox(width: 8),
            // Badge ao vivo da Fila Local + Ação rápida de Sincronização (AM-04)
            _buildDemoToggleChip(
              chipKey: const Key('demo_quick_sync_badge'),
              icon: Icons.sync_rounded,
              label: 'Fila Offline: $pendingCount • Sync',
              active: pendingCount > 0,
              activeColor: const Color(0xFF0277BD),
              inactiveColor: const Color(0xFF37474F),
              onTap: () {
                setState(() {
                  _selectedTabIndex = 2;
                });
                widget.appState.synchronizePendingForms();
              },
            ),
            const SizedBox(width: 8),
            // Toggle Simular Falha de Rede (AM-12)
            _buildDemoToggleChip(
              chipKey: const Key('demo_toggle_net_fail'),
              icon: Icons.wifi_tethering_error_rounded,
              label: simFail
                  ? 'Falha Rede AM-12: ATIVA'
                  : 'Simular Falha Rede (AM-12)',
              active: simFail,
              activeColor: const Color(0xFFC62828),
              inactiveColor: const Color(0xFF37474F),
              onTap: () => widget.appState.toggleSimulateNetworkFailure(),
            ),
            const SizedBox(width: 8),
            // Toggle Simular Conflito de Sincronização (AM-04)
            _buildDemoToggleChip(
              chipKey: const Key('demo_toggle_conflict'),
              icon: Icons.merge_type_rounded,
              label: simConflict
                  ? 'Conflito Sync AM-04: ATIVO'
                  : 'Simular Conflito (AM-04)',
              active: simConflict,
              activeColor: const Color(0xFFEF6C00),
              inactiveColor: const Color(0xFF37474F),
              onTap: () => widget.appState.toggleSimulateConflictOnNextSync(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDemoToggleChip({
    required Key chipKey,
    required IconData icon,
    required String label,
    required bool active,
    required Color activeColor,
    required Color inactiveColor,
    required VoidCallback onTap,
  }) {
    return InkWell(
      key: chipKey,
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: active ? activeColor : inactiveColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: Colors.white),
            const SizedBox(width: 5),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCurrentTabBody(BuildContext context, AppUser user) {
    switch (_selectedTabIndex) {
      case 0:
        return ProjectsScreen(appState: widget.appState);
      case 1:
        return FieldFormsSyncScreen(
          key: const ValueKey('tab_field_form_new'),
          appState: widget.appState,
          initialSectionIndex: 1,
        );
      case 2:
        return FieldFormsSyncScreen(
          key: const ValueKey('tab_field_sync_queue'),
          appState: widget.appState,
          initialSectionIndex: 0,
        );
      case 3:
        return InteractiveMapScreen(
          key: const ValueKey('tab_interactive_map'),
          appState: widget.appState,
          onOpenWaterAnalysisForPoint: (pointId) {
            setState(() {
              _focusedWaterPointId = pointId;
              _selectedTabIndex = 4;
            });
          },
        );
      case 4:
      default:
        return WaterSoilAnalysisScreen(
          key: ValueKey('tab_water_soil_${_focusedWaterPointId ?? "all"}'),
          appState: widget.appState,
          initialPointId: _focusedWaterPointId,
        );
    }
  }

  void _showJwtInspectorDialog(BuildContext context) {
    final user = widget.appState.currentUser!;
    final token = widget.appState.activeJwtToken ?? '';
    final payload = JwtAuthSimulator.decodePayload(token);

    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.security_rounded, color: Color(0xFF1B5E20)),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Sessão JWT & Permissões (AM-01)',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
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
                'Usuário: ${user.name}',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              Text('Perfil Ativo: ${user.role.label} (${user.role.shortBadge})'),
              Text('Organização: ${user.organization}'),
              Text('Matrícula/Registro: ${user.registrationCode}'),
              const Divider(height: 20),
              const Text(
                'Escopos de Segurança no Payload JWT:',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
              ),
              const SizedBox(height: 6),
              Text(
                '• Acesso a Dados Sigilosos (AM-01): ${payload['confidential_access'] == true ? 'AUTORIZADO' : 'BLOQUEADO (Somente Dados Abertos)'}',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: payload['confidential_access'] == true
                      ? const Color(0xFF1B5E20)
                      : const Color(0xFFE65100),
                ),
              ),
              Text(
                '• Escrita e Coleta em Campo: ${payload['field_write_access'] == true ? 'HABILITADA' : 'SOMENTE LEITURA'}',
                style: const TextStyle(fontSize: 12.5),
              ),
              const SizedBox(height: 12),
              const Text(
                'Token JWT Assinado (HMAC-SHA256):',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5),
              ),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F2),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFD0DDD4)),
                ),
                child: SelectableText(
                  token,
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
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Fechar'),
          ),
        ],
      ),
    );
  }
}
