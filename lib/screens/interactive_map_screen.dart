import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' hide Path;
import '../models/project_models.dart';
import '../models/user_profile.dart';
import '../models/water_soil_models.dart';
import '../state/app_state.dart';

/// Tela de Mapa Interativo Georreferenciado (AM-06):
/// - Plota polígonos das Propriedades Rurais e Áreas Monitoradas (Muda e PSA)
/// - Plota Camadas KML Processadas e Malha Hidrográfica
/// - Exibe Croqui Técnico Georreferenciado + Inspetor do XML KML Processado
/// - Marcadores clicáveis dos Pontos de Coleta com ficha consolidada (histórico de vistorias, água CONAMA 357/2005 e solo)
class InteractiveMapScreen extends StatefulWidget {
  final AppState appState;
  final void Function(String pointId)? onOpenWaterAnalysisForPoint;

  const InteractiveMapScreen({
    super.key,
    required this.appState,
    this.onOpenWaterAnalysisForPoint,
  });

  @override
  State<InteractiveMapScreen> createState() => _InteractiveMapScreenState();
}

class _InteractiveMapScreenState extends State<InteractiveMapScreen> {
  final MapController _mapController = MapController();

  bool _showPropertyPolygons = true;
  bool _showKmlProcessedLayer = true;
  bool _showTechnicalCroquiGrid = true;
  bool _showCollectionPoints = true;

  String _selectedProgramFilter = 'TODOS'; // 'TODOS', 'MUDA', 'PSA'
  RuralProperty? _selectedProperty;
  CollectionPoint? _selectedPoint;

  @override
  void initState() {
    super.initState();
    if (widget.appState.properties.isNotEmpty) {
      _selectedProperty = widget.appState.properties.first;
    }
    if (widget.appState.collectionPoints.isNotEmpty) {
      _selectedPoint = widget.appState.collectionPoints.first;
    }
  }

  List<RuralProperty> get _visibleProperties {
    return widget.appState.properties.where((prop) {
      if (_selectedProgramFilter == 'TODOS') return true;
      final proj = widget.appState.getProjectById(prop.projectId);
      return proj?.programType.toUpperCase() == _selectedProgramFilter;
    }).toList();
  }

  List<CollectionPoint> get _visiblePoints {
    return widget.appState.collectionPoints.where((pt) {
      if (_selectedProgramFilter == 'TODOS') return true;
      final proj = widget.appState.getProjectById(pt.projectId);
      return proj?.programType.toUpperCase() == _selectedProgramFilter;
    }).toList();
  }

  List<ProcessedKmlOverlay> get _visibleKmlOverlays {
    return widget.appState.kmlOverlays.where((kml) {
      if (_selectedProgramFilter == 'TODOS') return true;
      final proj = widget.appState.getProjectById(kml.projectId);
      return proj?.programType.toUpperCase() == _selectedProgramFilter;
    }).toList();
  }

  void _focusOnProperty(RuralProperty prop) {
    setState(() {
      _selectedProperty = prop;
      final pts = widget.appState.getPointsForProperty(prop.id);
      if (pts.isNotEmpty) {
        _selectedPoint = pts.first;
      }
    });
    try {
      _mapController.move(
        LatLng(prop.centerLatitude, prop.centerLongitude),
        14.2,
      );
    } catch (_) {
      // Ignora caso o MapController ainda não esteja anexado no ambiente de teste headless
    }
  }

  void _focusOnPoint(CollectionPoint pt) {
    final prop = widget.appState.getPropertyById(pt.propertyId);
    setState(() {
      _selectedPoint = pt;
      if (prop != null) {
        _selectedProperty = prop;
      }
    });
    try {
      _mapController.move(LatLng(pt.latitude, pt.longitude), 15.0);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.appState.currentUser!;
    final visibleProps = _visibleProperties;
    final visiblePts = _visiblePoints;
    final visibleKmls = _visibleKmlOverlays;

    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        // 1. Barra de Controle de Camadas GIS, KML e Croqui Técnico (AM-06)
        _buildLayerControlCard(visibleProps, visiblePts, visibleKmls),
        const SizedBox(height: 12),

        // 2. Canvas do Mapa Interativo Georreferenciado (`flutter_map`)
        _buildInteractiveMapCanvas(
          context,
          visibleProps: visibleProps,
          visiblePts: visiblePts,
          visibleKmls: visibleKmls,
        ),
        const SizedBox(height: 12),

        // 3. Seletor Rápido de Propriedades e Pontos Georreferenciados
        _buildQuickJumpBar(visibleProps, visiblePts),
        const SizedBox(height: 12),

        // 4. Painel de Detalhes do Ponto Selecionado + Croqui Técnico e KML (AM-06 / AM-07 / AM-10)
        if (_selectedPoint != null)
          _buildSelectedPointInspectorCard(context, _selectedPoint!, user),
      ],
    );
  }

  Widget _buildLayerControlCard(
    List<RuralProperty> visibleProps,
    List<CollectionPoint> visiblePts,
    List<ProcessedKmlOverlay> visibleKmls,
  ) {
    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: Color(0xFFD5E2D9)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.layers_rounded,
                  color: Color(0xFF1B5E20),
                  size: 20,
                ),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'SIG & Mapa Interativo: Polígonos, Camada KML Processada e Croqui Técnico (AM-06)',
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF16301D),
                    ),
                  ),
                ),
                OutlinedButton.icon(
                  key: const Key('open_kml_croqui_inspector_button'),
                  onPressed: () => _showKmlAndTechnicalCroquiDialog(context),
                  icon: const Icon(Icons.architecture_rounded, size: 16),
                  label: const Text(
                    'Croqui Técnico & KML',
                    style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                FilterChip(
                  key: const Key('toggle_layer_properties'),
                  label: Text('Propriedades (${visibleProps.length})'),
                  selected: _showPropertyPolygons,
                  onSelected: (v) => setState(() => _showPropertyPolygons = v),
                ),
                FilterChip(
                  key: const Key('toggle_layer_kml'),
                  label: Text('Camada KML Processada (${visibleKmls.length})'),
                  selected: _showKmlProcessedLayer,
                  onSelected: (v) => setState(() => _showKmlProcessedLayer = v),
                ),
                FilterChip(
                  key: const Key('toggle_layer_croqui'),
                  label: const Text('Malha Croqui Técnico'),
                  selected: _showTechnicalCroquiGrid,
                  onSelected: (v) =>
                      setState(() => _showTechnicalCroquiGrid = v),
                ),
                FilterChip(
                  key: const Key('toggle_layer_points'),
                  label: Text('Pontos de Coleta (${visiblePts.length})'),
                  selected: _showCollectionPoints,
                  onSelected: (v) => setState(() => _showCollectionPoints = v),
                ),
                const SizedBox(width: 6),
                ChoiceChip(
                  key: const Key('map_program_TODOS'),
                  label: const Text('Todos'),
                  selected: _selectedProgramFilter == 'TODOS',
                  onSelected: (_) =>
                      setState(() => _selectedProgramFilter = 'TODOS'),
                ),
                ChoiceChip(
                  key: const Key('map_program_MUDA'),
                  label: const Text('Muda'),
                  selected: _selectedProgramFilter == 'MUDA',
                  onSelected: (_) =>
                      setState(() => _selectedProgramFilter = 'MUDA'),
                ),
                ChoiceChip(
                  key: const Key('map_program_PSA'),
                  label: const Text('PSA'),
                  selected: _selectedProgramFilter == 'PSA',
                  onSelected: (_) =>
                      setState(() => _selectedProgramFilter = 'PSA'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInteractiveMapCanvas(
    BuildContext context, {
    required List<RuralProperty> visibleProps,
    required List<CollectionPoint> visiblePts,
    required List<ProcessedKmlOverlay> visibleKmls,
  }) {
    final initialCenter = _selectedProperty != null
        ? LatLng(
            _selectedProperty!.centerLatitude,
            _selectedProperty!.centerLongitude,
          )
        : const LatLng(-29.6058, -52.1932);

    return Container(
      key: const Key('interactive_flutter_map_container'),
      height: 360,
      decoration: BoxDecoration(
        color: const Color(0xFFE4EFE7),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF81C784), width: 1.5),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: initialCenter,
              initialZoom: 11.2,
              minZoom: 7.0,
              maxZoom: 18.0,
            ),
            children: [
              // Fundo Cartográfico Técnico Autônomo (Funciona 100% Offline sem internet)
              if (_showTechnicalCroquiGrid)
                Positioned.fill(
                  child: CustomPaint(
                    painter: _TechnicalCartographicGridPainter(),
                  ),
                ),

              // Camada 1: Polígonos das Propriedades Rurais (AM-06)
              if (_showPropertyPolygons)
                PolygonLayer(
                  polygons: visibleProps.map((prop) {
                    final isSelected = _selectedProperty?.id == prop.id;
                    final isMuda = prop.projectId.contains('muda');
                    return Polygon(
                      points: prop.polygonCoordinates
                          .map((c) => LatLng(c.latitude, c.longitude))
                          .toList(),
                      color: isMuda
                          ? const Color(0xFF2E7D32).withValues(
                              alpha: isSelected ? 0.35 : 0.20,
                            )
                          : const Color(0xFF0277BD).withValues(
                              alpha: isSelected ? 0.35 : 0.20,
                            ),
                      borderStrokeWidth: isSelected ? 3.0 : 1.8,
                      borderColor: isMuda
                          ? const Color(0xFF1B5E20)
                          : const Color(0xFF01579B),
                      label: '${prop.code} (${prop.restorationAreaHa} ha)',
                      labelStyle: const TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF16301D),
                      ),
                    );
                  }).toList(),
                ),

              // Camada 2: Polígonos e Hidrografia da Camada KML Processada (AM-06)
              if (_showKmlProcessedLayer) ...[
                PolygonLayer(
                  polygons: visibleKmls.map((kml) {
                    return Polygon(
                      points: kml.overlayPolygon
                          .map((c) => LatLng(c.latitude, c.longitude))
                          .toList(),
                      color: const Color(0xFFEF6C00).withValues(alpha: 0.22),
                      borderStrokeWidth: 2.0,
                      borderColor: const Color(0xFFE65100),
                      label: 'KML: ${kml.layerCategory}',
                      labelStyle: const TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFFBF360C),
                      ),
                    );
                  }).toList(),
                ),
                PolylineLayer(
                  polylines: visibleKmls.map((kml) {
                    return Polyline(
                      points: kml.hydrographyPolyline
                          .map((c) => LatLng(c.latitude, c.longitude))
                          .toList(),
                      strokeWidth: 3.0,
                      color: const Color(0xFF0288D1),
                    );
                  }).toList(),
                ),
              ],

              // Camada 3: Marcadores Clicáveis dos Pontos de Coleta (AM-06)
              if (_showCollectionPoints)
                MarkerLayer(
                  markers: visiblePts.map((pt) {
                    final isSelected = _selectedPoint?.id == pt.id;
                    final ptWater =
                        widget.appState.getWaterAnalysesForPoint(pt.id);
                    final hasViolation = ptWater.isNotEmpty &&
                        !ptWater.first.isConamaCompliant;

                    return Marker(
                      point: LatLng(pt.latitude, pt.longitude),
                      width: 130,
                      height: 70,
                      child: GestureDetector(
                        key: Key('map_marker_${pt.id}'),
                        onTap: () => _focusOnPoint(pt),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 7,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? const Color(0xFF1B5E20)
                                    : Colors.white,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: hasViolation
                                      ? const Color(0xFFC62828)
                                      : const Color(0xFF1B5E20),
                                  width: 1.5,
                                ),
                                boxShadow: const [
                                  BoxShadow(
                                    color: Colors.black26,
                                    blurRadius: 3,
                                    offset: Offset(0, 1),
                                  ),
                                ],
                              ),
                              child: Text(
                                pt.code,
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w900,
                                  color: isSelected
                                      ? Colors.white
                                      : const Color(0xFF16301D),
                                ),
                              ),
                            ),
                            Icon(
                              pt.pointType.contains('Nascente')
                                  ? Icons.water_drop_rounded
                                  : pt.pointType.contains('Solo')
                                      ? Icons.landscape_rounded
                                      : Icons.park_rounded,
                              size: isSelected ? 26 : 22,
                              color: hasViolation
                                  ? const Color(0xFFC62828)
                                  : isSelected
                                      ? const Color(0xFF1B5E20)
                                      : const Color(0xFF0277BD),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
            ],
          ),

          // Legenda Cartográfica e Coordenadas SIRGAS 2000 no Canto Superior Esquerdo
          Positioned(
            top: 10,
            left: 10,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.92),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFB0BEC5)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'DATUM: SIRGAS 2000 / UTM 22S • BASE VETORIAL OFFLINE',
                    style: TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF1B5E20),
                    ),
                  ),
                  if (_selectedProperty != null)
                    Text(
                      'Foco: ${_selectedProperty!.code} (${_selectedProperty!.centerLatitude.toStringAsFixed(4)}, ${_selectedProperty!.centerLongitude.toStringAsFixed(4)})',
                      style: const TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF37474F),
                      ),
                    ),
                ],
              ),
            ),
          ),

          // Controles de Zoom no Canto Inferior Direito
          Positioned(
            bottom: 10,
            right: 10,
            child: Column(
              children: [
                FloatingActionButton.small(
                  heroTag: 'map_zoom_in',
                  backgroundColor: Colors.white,
                  foregroundColor: const Color(0xFF1B5E20),
                  onPressed: () {
                    try {
                      final cam = _mapController.camera;
                      _mapController.move(cam.center, cam.zoom + 1);
                    } catch (_) {}
                  },
                  child: const Icon(Icons.add_rounded),
                ),
                const SizedBox(height: 6),
                FloatingActionButton.small(
                  heroTag: 'map_zoom_out',
                  backgroundColor: Colors.white,
                  foregroundColor: const Color(0xFF1B5E20),
                  onPressed: () {
                    try {
                      final cam = _mapController.camera;
                      _mapController.move(cam.center, cam.zoom - 1);
                    } catch (_) {}
                  },
                  child: const Icon(Icons.remove_rounded),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickJumpBar(
    List<RuralProperty> visibleProps,
    List<CollectionPoint> visiblePts,
  ) {
    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: Color(0xFFD5E2D9)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Navegação Georreferenciada Rápida (Propriedades & Pontos de Coleta):',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: Color(0xFF16301D),
              ),
            ),
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  ...visibleProps.map(
                    (prop) => Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ActionChip(
                        key: Key('jump_property_${prop.id}'),
                        avatar: const Icon(Icons.fence_rounded, size: 15),
                        backgroundColor: _selectedProperty?.id == prop.id
                            ? const Color(0xFFE8F5E9)
                            : null,
                        label: Text(
                          '${prop.code}: ${prop.name}',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        onPressed: () => _focusOnProperty(prop),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  ...visiblePts.map(
                    (pt) => Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        key: Key('select_point_chip_${pt.id}'),
                        label: Text(
                          '${pt.code} (${pt.pointType})',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        selected: _selectedPoint?.id == pt.id,
                        onSelected: (_) => _focusOnPoint(pt),
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

  Widget _buildSelectedPointInspectorCard(
    BuildContext context,
    CollectionPoint point,
    AppUser user,
  ) {
    final prop = widget.appState.getPropertyById(point.propertyId);
    final proj = widget.appState.getProjectById(point.projectId);
    final kml = prop != null
        ? widget.appState.getKmlOverlayForProperty(prop.id)
        : null;
    final pointWater = widget.appState.getWaterAnalysesForPoint(point.id);
    final pointForms = widget.appState.getFieldFormsForPoint(point.id);
    final propSoilUnits = prop != null
        ? widget.appState.getSoilUnitsForProperty(prop.id)
        : <SoilConservationUnit>[];

    return Card(
      key: Key('selected_point_inspector_${point.id}'),
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFF81C784), width: 1.4),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8F5E9),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.place_rounded,
                    color: Color(0xFF1B5E20),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${point.code} — ${point.name}',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF16301D),
                        ),
                      ),
                      Text(
                        'Tipo: ${point.pointType} • Coordenadas: ${point.latitude.toStringAsFixed(4)}, ${point.longitude.toStringAsFixed(4)} • Alt: ${point.altitudeMeters}m',
                        style: const TextStyle(
                          fontSize: 11.5,
                          color: Color(0xFF455A64),
                        ),
                      ),
                    ],
                  ),
                ),
                if (widget.onOpenWaterAnalysisForPoint != null)
                  FilledButton.tonalIcon(
                    key: const Key('jump_to_water_soil_from_map_btn'),
                    onPressed: () =>
                        widget.onOpenWaterAnalysisForPoint!(point.id),
                    icon: const Icon(Icons.science_rounded, size: 16),
                    label: const Text(
                      'Ver Laudos CONAMA & Solo',
                      style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800),
                    ),
                  ),
              ],
            ),
            const Divider(height: 20),

            if (prop != null) ...[
              Text(
                'Propriedade Rural: ${prop.name} (${prop.municipality}) • Projeto ${proj?.code ?? ""}',
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1B5E20),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Solo Predominante: ${prop.mainSoilType} • Área Total: ${prop.totalAreaHa} ha (Restauração: ${prop.restorationAreaHa} ha) • '
                'CAR: ${user.formatConfidentialText(prop.carRegistryCode)}',
                style: const TextStyle(fontSize: 11.5, color: Color(0xFF37474F)),
              ),
            ],

            if (kml != null) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF3E0),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFFFB74D)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Camada KML Processada & Croqui Técnico Vinculado: ${kml.kmlFileName}',
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFFE65100),
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${kml.technicalCroquiSummary} (CRS: ${kml.datumcrs})',
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF4E342E),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 10),
            Wrap(
              spacing: 10,
              runSpacing: 8,
              children: [
                _buildPointBadge(
                  icon: Icons.water_drop_rounded,
                  label: pointWater.isEmpty
                      ? 'Laudos Água: 0'
                      : 'Último Laudo Água: ${pointWater.first.complianceStatusLabel}',
                  color: pointWater.isEmpty
                      ? const Color(0xFF546E7A)
                      : pointWater.first.isConamaCompliant
                          ? const Color(0xFF2E7D32)
                          : const Color(0xFFC62828),
                ),
                _buildPointBadge(
                  icon: Icons.landscape_rounded,
                  label:
                      'Unidades de Solo na Propriedade: ${propSoilUnits.length}',
                  color: const Color(0xFF5D4037),
                ),
                _buildPointBadge(
                  icon: Icons.assignment_turned_in_rounded,
                  label: 'Vistorias de Campo no Ponto: ${pointForms.length}',
                  color: const Color(0xFF0277BD),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPointBadge({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  /// Modal de Inspeção do Croqui Técnico Esquemático e Camada KML Processada (AM-06).
  void _showKmlAndTechnicalCroquiDialog(BuildContext context) {
    final prop = _selectedProperty ?? widget.appState.properties.first;
    final kml = widget.appState.getKmlOverlayForProperty(prop.id) ??
        widget.appState.kmlOverlays.first;

    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        key: const Key('kml_croqui_inspector_dialog'),
        title: Row(
          children: [
            const Icon(Icons.architecture_rounded, color: Color(0xFF1B5E20)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Croqui Técnico & Camada KML Processada — ${prop.code} (AM-06)',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
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
                'Arquivo KML Processado: ${kml.kmlFileName}',
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF1B5E20),
                ),
              ),
              Text(
                'Sistema de Referência: ${kml.datumcrs} • Área Mapeada: ${kml.mappedAreaHa} ha',
                style: const TextStyle(fontSize: 11.5, color: Color(0xFF455A64)),
              ),
              const SizedBox(height: 10),

              // Croqui Técnico Vetorial Esquemático da Propriedade (Talhões, APP e Hidrografia)
              Container(
                key: const Key('technical_croqui_schematic_canvas'),
                height: 170,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F8E9),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF2E7D32)),
                ),
                child: CustomPaint(
                  painter: _PropertyTechnicalCroquiPainter(
                    propertyCode: prop.code,
                    layerTitle: kml.title,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Memorial do Croqui Técnico: ${kml.technicalCroquiSummary}',
                style: const TextStyle(fontSize: 12, color: Color(0xFF263238)),
              ),
              const SizedBox(height: 10),
              const Text(
                'Estrutura XML / KML Processada (OGC KML 2.2):',
                style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 4),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF263238),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: SelectableText(
                  kml.rawKmlSnippet,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 10.5,
                    color: Color(0xFFA5D6A7),
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            key: const Key('close_kml_croqui_dialog_btn'),
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Fechar Croqui & KML'),
          ),
        ],
      ),
    );
  }
}

/// Pintor de grade cartográfica UTM/SIRGAS 2000 para visualização offline no mapa.
class _TechnicalCartographicGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = const Color(0xFFB0BEC5).withValues(alpha: 0.35)
      ..strokeWidth = 1.0;

    const step = 40.0;
    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Pintor do Croqui Técnico Esquemático da Propriedade (Talhões, Curvas de Nível e APP Ciliar).
class _PropertyTechnicalCroquiPainter extends CustomPainter {
  final String propertyCode;
  final String layerTitle;

  const _PropertyTechnicalCroquiPainter({
    required this.propertyCode,
    required this.layerTitle,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final borderPaint = Paint()
      ..color = const Color(0xFF2E7D32)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    final appFillPaint = Paint()
      ..color = const Color(0xFF81C784).withValues(alpha: 0.35)
      ..style = PaintingStyle.fill;

    final riverPaint = Paint()
      ..color = const Color(0xFF0288D1)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5;

    final poly = Path()
      ..moveTo(size.width * 0.12, size.height * 0.18)
      ..lineTo(size.width * 0.88, size.height * 0.22)
      ..lineTo(size.width * 0.82, size.height * 0.84)
      ..lineTo(size.width * 0.16, size.height * 0.80)
      ..close();

    canvas.drawPath(poly, appFillPaint);
    canvas.drawPath(poly, borderPaint);

    final river = Path()
      ..moveTo(size.width * 0.15, size.height * 0.72)
      ..quadraticBezierTo(
        size.width * 0.48,
        size.height * 0.40,
        size.width * 0.85,
        size.height * 0.30,
      );
    canvas.drawPath(river, riverPaint);

    final tp = TextPainter(
      text: TextSpan(
        text: 'CROQUI TÉCNICO VETORIAL — $propertyCode\n$layerTitle\n[Faixa APP 30m/50m • Talhões • Hidrografia KML]',
        style: const TextStyle(
          color: Color(0xFF1B5E20),
          fontSize: 11,
          fontWeight: FontWeight.w800,
          height: 1.3,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: size.width - 24);

    tp.paint(canvas, const Offset(12, 12));
  }

  @override
  bool shouldRepaint(covariant _PropertyTechnicalCroquiPainter oldDelegate) =>
      oldDelegate.propertyCode != propertyCode;
}
