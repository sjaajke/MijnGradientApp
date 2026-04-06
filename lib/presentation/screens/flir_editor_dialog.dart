import 'dart:io';

import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/flir_extract_service.dart';

/// Full-screen dialog for editing a FLIR radiometric image using the Atlas SDK.
///
/// Features: palette selection, color distribution, temperature scale,
/// thermal parameters, measurement tools (spot, rect, ellipse, line),
/// isotherms, and pixel temperature readout.
class FlirEditorDialog extends StatefulWidget {
  final String imagePath;
  final FlirExtractResult? initialInfo;

  const FlirEditorDialog({
    super.key,
    required this.imagePath,
    this.initialInfo,
  });

  static Future<void> show(BuildContext context, String imagePath, {FlirExtractResult? info}) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => FlirEditorDialog(imagePath: imagePath, initialInfo: info),
    );
  }

  @override
  State<FlirEditorDialog> createState() => _FlirEditorDialogState();
}

class _FlirEditorDialogState extends State<FlirEditorDialog> {
  // ── State ────────────────────────────────────────────────────────────
  FlirExtractResult? _info;
  String? _renderPath;
  bool _loading = true;
  String? _statusMessage;

  // Current settings
  FlirPalette _palette = FlirPalette.iron;
  FlirColorDist _colorDist = FlirColorDist.linear;
  double _scaleMin = 20;
  double _scaleMax = 50;
  bool _customScale = false;

  // Thermal params
  late double _emissivity;
  late double _distance;
  late double _reflectedTemp;
  late double _humidity;

  // Cursor temperature
  double? _cursorTemp;
  int? _cursorX;
  int? _cursorY;

  // Measurement tool
  _MeasurementTool _activeTool = _MeasurementTool.none;

  // Dragging spot state
  int? _draggingSpotId;
  Offset? _dragOffset;

  // Zoom
  final TransformationController _zoomController = TransformationController();
  double _zoomLevel = 1.0;

  int _renderCounter = 0;

  /// Unique session ID to avoid file collisions between editor instances.
  late final String _sessionId;

  /// Working copy of the FLIR file – all mutations happen on this copy.
  late String _workingPath;

  String get _renderFile =>
      '${Directory.systemTemp.path}/flir_editor_${_sessionId}_$_renderCounter.ppm';

  @override
  void initState() {
    super.initState();
    _sessionId = DateTime.now().millisecondsSinceEpoch.toString();
    // Create a working copy so the original stays untouched
    final ext = widget.imagePath.contains('.')
        ? widget.imagePath.substring(widget.imagePath.lastIndexOf('.'))
        : '.jpg';
    _workingPath = '${Directory.systemTemp.path}/flir_editor_work_$_sessionId$ext';
    File(widget.imagePath).copySync(_workingPath);

    _info = widget.initialInfo;
    final tp = _info?.thermalParams;
    _emissivity = tp?.emissivity ?? 0.95;
    _distance = tp?.objectDistance ?? 1.0;
    _reflectedTemp = tp?.reflectedTemperature ?? 20.0;
    _humidity = tp?.relativeHumidity ?? 50.0;
    if (_info?.scale != null) {
      _scaleMin = _info!.scale!.min;
      _scaleMax = _info!.scale!.max;
    }
    _doInitialRender();
  }

  void _closeEditor() {
    // Copy working file back to original so changes persist
    try { File(_workingPath).copySync(widget.imagePath); } catch (_) {}
    Navigator.of(context).pop();
  }

  @override
  void dispose() {
    _zoomController.dispose();
    try { File(_workingPath).deleteSync(); } catch (_) {}
    super.dispose();
  }

  void _setZoom(double level) {
    setState(() => _zoomLevel = level.clamp(0.25, 4.0));
    final matrix = Matrix4.diagonal3Values(_zoomLevel, _zoomLevel, 1.0);
    _zoomController.value = matrix;
  }

  Future<void> _doInitialRender() async {
    if (_info == null) {
      final info = await FlirExtractService.extract(_workingPath);
      if (!mounted) return;
      if (info == null || !info.ok) {
        setState(() {
          _loading = false;
          _statusMessage = 'Kan FLIR-data niet laden.';
        });
        return;
      }
      _info = info;
      final tp = info.thermalParams;
      _emissivity = tp?.emissivity ?? 0.95;
      _distance = tp?.objectDistance ?? 1.0;
      _reflectedTemp = tp?.reflectedTemperature ?? 20.0;
      _humidity = tp?.relativeHumidity ?? 50.0;
      if (info.scale != null) {
        _scaleMin = info.scale!.min;
        _scaleMax = info.scale!.max;
      }
    }
    await _render();
  }

  Future<void> _render() async {
    setState(() => _loading = true);
    _renderCounter++;
    final outPath = _renderFile;

    final result = await FlirExtractService.render(
      _workingPath,
      outPath,
      palette: _palette,
      colorDist: _colorDist,
      scaleMin: _customScale ? _scaleMin : null,
      scaleMax: _customScale ? _scaleMax : null,
    );

    if (!mounted) return;
    setState(() {
      _loading = false;
      _renderPath = result;
    });
  }

  Future<void> _onPaletteChanged(FlirPalette p) async {
    _palette = p;
    await _render();
  }

  Future<void> _onColorDistChanged(FlirColorDist d) async {
    _colorDist = d;
    await _render();
  }

  Future<void> _onScaleChanged() async {
    await _render();
  }

  Future<void> _onParamsApply() async {
    setState(() => _loading = true);
    _renderCounter++;
    final outPath = _renderFile;

    final result = await FlirExtractService.setParams(
      _workingPath,
      outPath,
      emissivity: _emissivity,
      distance: _distance,
      reflectedTemp: _reflectedTemp,
      humidity: _humidity,
      palette: _palette,
    );

    if (!mounted) return;

    // Re-read info to get updated spot temps
    final info = await FlirExtractService.extract(_workingPath);

    if (!mounted) return;
    setState(() {
      _loading = false;
      if (result?['ok'] == true) {
        _renderPath = outPath;
        _statusMessage = 'Thermische parameters toegepast';
      }
      if (info != null && info.ok) _info = info;
    });
  }

  Future<void> _onImageTap(Offset localPosition, Size imageSize) async {
    final info = _info;
    if (info == null) return;

    final x = (localPosition.dx / imageSize.width * info.width).round();
    final y = (localPosition.dy / imageSize.height * info.height).round();

    if (_activeTool == _MeasurementTool.spot) {
      setState(() => _loading = true);
      _renderCounter++;
      final outPath = _renderFile;
      final result = await FlirExtractService.addSpot(_workingPath, outPath, x, y);
      if (!mounted) return;

      // Re-read info so the new spot appears in the overlay
      final updatedInfo = await FlirExtractService.extract(_workingPath);

      if (!mounted) return;
      setState(() {
        _loading = false;
        if (result?['ok'] == true) {
          _renderPath = outPath;
          _statusMessage = 'Spot toegevoegd: ${(result!['temperature'] as num?)?.toStringAsFixed(1)} °C';
        }
        if (updatedInfo != null && updatedInfo.ok) _info = updatedInfo;
      });
      return;
    }

    // Default: show temperature at cursor
    final temp = await FlirExtractService.getTemperatureAt(_workingPath, x, y);
    if (!mounted) return;
    setState(() {
      _cursorTemp = temp;
      _cursorX = x;
      _cursorY = y;
    });
  }

  Future<void> _onAddIsotherm(FlirIsothermType type, double temp1, double? temp2) async {
    setState(() => _loading = true);
    _renderCounter++;
    final outPath = _renderFile;
    await FlirExtractService.addIsotherm(
      _workingPath, outPath, type, temp1,
      temp2: temp2, palette: _palette,
    );
    if (!mounted) return;
    setState(() {
      _loading = false;
      _renderPath = outPath;
      _statusMessage = 'Isotherm toegevoegd';
    });
  }

  // ── Remove Spot ──────────────────────────────────────────────────────

  Future<void> _onRemoveSpot(int spotId) async {
    setState(() => _loading = true);
    _renderCounter++;
    final outPath = _renderFile;
    final result = await FlirExtractService.removeSpot(
      _workingPath, outPath, spotId,
    );
    if (!mounted) return;

    final updatedInfo = await FlirExtractService.extract(_workingPath);
    if (!mounted) return;

    setState(() {
      _loading = false;
      if (result?['ok'] == true) {
        _renderPath = outPath;
        _statusMessage = 'Spot $spotId verwijderd';
      }
      if (updatedInfo != null && updatedInfo.ok) _info = updatedInfo;
    });
  }

  // ── Move Spot ────────────────────────────────────────────────────────

  Future<void> _onMoveSpot(int spotId, int newX, int newY) async {
    setState(() => _loading = true);
    _renderCounter++;
    final outPath = _renderFile;
    final result = await FlirExtractService.moveSpot(
      _workingPath, outPath, spotId, newX, newY,
    );
    if (!mounted) return;

    final updatedInfo = await FlirExtractService.extract(_workingPath);
    if (!mounted) return;

    setState(() {
      _loading = false;
      _draggingSpotId = null;
      _dragOffset = null;
      if (result?['ok'] == true) {
        _renderPath = outPath;
        _statusMessage = 'Spot $spotId verplaatst naar ($newX, $newY): '
            '${(result!['temperature'] as num?)?.toStringAsFixed(1)} °C';
      }
      if (updatedInfo != null && updatedInfo.ok) _info = updatedInfo;
    });
  }

  // ── Save As ──────────────────────────────────────────────────────────

  Future<void> _saveAs() async {
    // Determine default output name next to the original file
    final srcFile = File(widget.imagePath);
    final dir = srcFile.parent.path;
    final srcName = srcFile.uri.pathSegments.last;
    final dotIdx = srcName.lastIndexOf('.');
    final baseName = dotIdx > 0 ? srcName.substring(0, dotIdx) : srcName;
    final ext = dotIdx > 0 ? srcName.substring(dotIdx) : '.jpg';
    final defaultName = '${baseName}_edited$ext';

    final nameCtrl = TextEditingController(text: defaultName);

    final chosenName = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Opslaan als'),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Map: $dir', style: const TextStyle(fontSize: 12, color: Colors.black54)),
              const SizedBox(height: 12),
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Bestandsnaam',
                  border: OutlineInputBorder(),
                ),
                autofocus: true,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuleren')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, nameCtrl.text.trim()),
            child: const Text('Opslaan'),
          ),
        ],
      ),
    );

    if (chosenName == null || chosenName.isEmpty) return;

    final outPath = '$dir/$chosenName';
    setState(() {
      _loading = true;
      _statusMessage = 'Opslaan…';
    });

    // Determine format from extension
    final outExt = chosenName.contains('.') ? chosenName.split('.').last.toLowerCase() : 'jpeg';
    final format = outExt == 'png' ? 'png' : 'jpeg';

    final ok = await FlirExtractService.save(_workingPath, outPath, format: format);

    if (!mounted) return;
    setState(() {
      _loading = false;
      _statusMessage = ok ? 'Opgeslagen als $chosenName' : 'Opslaan mislukt';
    });
  }

  // ── Build ────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Dialog.fullscreen(
      child: Scaffold(
        appBar: AppBar(
          title: Text('FLIR Editor — ${Uri.file(widget.imagePath).pathSegments.last}'),
          leading: IconButton(
            icon: const Icon(Icons.close),
            onPressed: _closeEditor,
          ),
          actions: [
            if (_statusMessage != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Center(
                  child: Text(
                    _statusMessage!,
                    style: const TextStyle(fontSize: 12, color: Colors.white70),
                  ),
                ),
              ),
            IconButton(
              icon: const Icon(Icons.save_as),
              tooltip: 'Opslaan als…',
              onPressed: _loading ? null : _saveAs,
            ),
            if (_loading)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: SizedBox(
                  width: 18, height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                ),
              ),
          ],
        ),
        body: Row(
          children: [
            // Left: rendered image
            Expanded(
              flex: 3,
              child: _buildImagePanel(),
            ),
            // Right: controls
            SizedBox(
              width: 340,
              child: _buildControlPanel(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImagePanel() {
    return Container(
      color: Colors.black87,
      child: Column(
        children: [
          // Cursor temperature readout
          Container(
            height: 32,
            color: Colors.black,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                const Icon(Icons.thermostat, size: 16, color: Colors.white54),
                const SizedBox(width: 6),
                if (_cursorTemp != null)
                  Text(
                    '${_cursorTemp!.toStringAsFixed(2)} °C  ($_cursorX, $_cursorY)',
                    style: const TextStyle(color: Colors.white, fontFamily: 'monospace', fontSize: 13),
                  )
                else
                  const Text('Klik op de afbeelding voor temperatuur',
                      style: TextStyle(color: Colors.white38, fontSize: 12)),
                const Spacer(),
                Text(
                  'Palet: ${_palette.displayName}  |  ${_colorDist.displayName}',
                  style: const TextStyle(color: Colors.white38, fontSize: 11),
                ),
              ],
            ),
          ),
          // Image with spot overlays – native size, scrollable
          Expanded(
            child: _renderPath != null
                ? Builder(
                    builder: (context) {
                      final file = File(_renderPath!);
                      if (!file.existsSync()) {
                        return const Center(child: Text('Render niet gevonden', style: TextStyle(color: Colors.white54)));
                      }
                      final info = _info;
                      final imgW = info?.width.toDouble() ?? 1;
                      final imgH = info?.height.toDouble() ?? 1;

                      return InteractiveViewer(
                        transformationController: _zoomController,
                        constrained: false,
                        boundaryMargin: const EdgeInsets.all(20),
                        minScale: 0.25,
                        maxScale: 4.0,
                        onInteractionEnd: (_) {
                          final scale = _zoomController.value.getMaxScaleOnAxis();
                          setState(() => _zoomLevel = scale);
                        },
                        child: Listener(
                          onPointerDown: (event) {
                            final lx = event.localPosition.dx;
                            final ly = event.localPosition.dy;
                            if (lx < 0 || ly < 0 || lx > imgW || ly > imgH) return;
                            _onImageTap(
                              Offset(lx, ly),
                              Size(imgW, imgH),
                            );
                          },
                          child: SizedBox(
                            width: imgW,
                            height: imgH,
                            child: Stack(
                              children: [
                                Image.file(
                                  file,
                                  key: ValueKey(_renderPath),
                                  width: imgW,
                                  height: imgH,
                                  gaplessPlayback: true,
                                ),
                                // Spot markers – draggable
                                if (info != null)
                                  for (final spot in info.spots)
                                    if (spot.isValid)
                                      Positioned(
                                        left: (_draggingSpotId == spot.id && _dragOffset != null
                                            ? _dragOffset!.dx
                                            : spot.x.toDouble()) - 6,
                                        top: (_draggingSpotId == spot.id && _dragOffset != null
                                            ? _dragOffset!.dy
                                            : spot.y.toDouble()) - 6,
                                        child: GestureDetector(
                                          onPanStart: (_) {
                                            setState(() {
                                              _draggingSpotId = spot.id;
                                              _dragOffset = Offset(spot.x.toDouble(), spot.y.toDouble());
                                            });
                                          },
                                          onPanUpdate: (details) {
                                            setState(() {
                                              _dragOffset = Offset(
                                                (_dragOffset!.dx + details.delta.dx).clamp(0, imgW),
                                                (_dragOffset!.dy + details.delta.dy).clamp(0, imgH),
                                              );
                                            });
                                          },
                                          onPanEnd: (_) {
                                            if (_dragOffset != null && _draggingSpotId != null) {
                                              final nx = _dragOffset!.dx.round();
                                              final ny = _dragOffset!.dy.round();
                                              // Don't clear drag state here – _onMoveSpot clears it after update
                                              _onMoveSpot(_draggingSpotId!, nx, ny);
                                            }
                                          },
                                          child: _SpotMarker(
                                            spot: spot,
                                            isDragging: _draggingSpotId == spot.id,
                                          ),
                                        ),
                                      ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  )
                : const Center(child: CircularProgressIndicator()),
          ),
          // Zoom controls
          Container(
            height: 36,
            color: Colors.black,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.remove, size: 16, color: Colors.white70),
                  onPressed: () => _setZoom(_zoomLevel - 0.25),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                  tooltip: 'Uitzoomen',
                ),
                Expanded(
                  child: Slider(
                    value: _zoomLevel.clamp(0.25, 4.0),
                    min: 0.25,
                    max: 4.0,
                    divisions: 15,
                    onChanged: _setZoom,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.add, size: 16, color: Colors.white70),
                  onPressed: () => _setZoom(_zoomLevel + 0.25),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                  tooltip: 'Inzoomen',
                ),
                const SizedBox(width: 4),
                Text(
                  '${(_zoomLevel * 100).round()}%',
                  style: const TextStyle(color: Colors.white70, fontSize: 11, fontFamily: 'monospace'),
                ),
                const SizedBox(width: 4),
                IconButton(
                  icon: const Icon(Icons.fit_screen, size: 16, color: Colors.white70),
                  onPressed: () => _setZoom(1.0),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                  tooltip: '100%',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildControlPanel() {
    return Container(
      color: const Color(0xFFF5F7FB),
      child: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          _buildSection('Kleurpalet', _buildPaletteSelector()),
          _buildSection('Kleurverdeling', _buildColorDistSelector()),
          _buildSection('Temperatuurschaal', _buildScaleControls()),
          _buildSection('Thermische parameters', _buildParamsControls()),
          _buildSection('Meetgereedschap', _buildMeasurementTools()),
          _buildSection('Isothermen', _buildIsothermControls()),
          _buildSection('Meetpunten', _buildSpotList()),
        ],
      ),
    );
  }

  Widget _buildSection(String title, Widget child) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ExpansionTile(
        title: Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
        initiallyExpanded: title == 'Kleurpalet',
        childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        children: [child],
      ),
    );
  }

  // ── Palette ──────────────────────────────────────────────────────────

  Widget _buildPaletteSelector() {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: FlirPalette.values.map((p) {
        final selected = p == _palette;
        return ChoiceChip(
          label: Text(p.displayName, style: const TextStyle(fontSize: 11)),
          selected: selected,
          onSelected: (_) => _onPaletteChanged(p),
          visualDensity: VisualDensity.compact,
        );
      }).toList(),
    );
  }

  // ── Color distribution ───────────────────────────────────────────────

  Widget _buildColorDistSelector() {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: FlirColorDist.values.map((d) {
        final selected = d == _colorDist;
        return ChoiceChip(
          label: Text(d.displayName, style: const TextStyle(fontSize: 11)),
          selected: selected,
          onSelected: (_) => _onColorDistChanged(d),
          visualDensity: VisualDensity.compact,
        );
      }).toList(),
    );
  }

  // ── Scale ────────────────────────────────────────────────────────────

  Widget _buildScaleControls() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SwitchListTile(
          title: const Text('Handmatige schaal', style: TextStyle(fontSize: 13)),
          value: _customScale,
          dense: true,
          contentPadding: EdgeInsets.zero,
          onChanged: (v) {
            setState(() => _customScale = v);
            _onScaleChanged();
          },
        ),
        if (_customScale) ...[
          Row(
            children: [
              const Text('Min:', style: TextStyle(fontSize: 12)),
              Expanded(
                child: Slider(
                  value: _scaleMin,
                  min: -40, max: 150,
                  label: '${_scaleMin.toStringAsFixed(0)} °C',
                  onChanged: (v) => setState(() => _scaleMin = v),
                  onChangeEnd: (_) => _onScaleChanged(),
                ),
              ),
              SizedBox(
                width: 50,
                child: Text('${_scaleMin.toStringAsFixed(0)} °C',
                    style: const TextStyle(fontSize: 11, fontFamily: 'monospace')),
              ),
            ],
          ),
          Row(
            children: [
              const Text('Max:', style: TextStyle(fontSize: 12)),
              Expanded(
                child: Slider(
                  value: _scaleMax,
                  min: -40, max: 150,
                  label: '${_scaleMax.toStringAsFixed(0)} °C',
                  onChanged: (v) => setState(() => _scaleMax = v),
                  onChangeEnd: (_) => _onScaleChanged(),
                ),
              ),
              SizedBox(
                width: 50,
                child: Text('${_scaleMax.toStringAsFixed(0)} °C',
                    style: const TextStyle(fontSize: 11, fontFamily: 'monospace')),
              ),
            ],
          ),
        ],
      ],
    );
  }

  // ── Thermal parameters ───────────────────────────────────────────────

  Widget _buildParamsControls() {
    return Column(
      children: [
        _paramRow('Emissiviteit', _emissivity, 0.01, 1.0, (v) => _emissivity = v, decimals: 2),
        _paramRow('Afstand (m)', _distance, 0.1, 100, (v) => _distance = v, decimals: 1),
        _paramRow('Geref. temp. (°C)', _reflectedTemp, -40, 150, (v) => _reflectedTemp = v, decimals: 0),
        _paramRow('Luchtvocht. (%)', _humidity, 0, 100, (v) => _humidity = v, decimals: 0),
        const SizedBox(height: 8),
        FilledButton.icon(
          onPressed: _onParamsApply,
          icon: const Icon(Icons.refresh, size: 16),
          label: const Text('Toepassen', style: TextStyle(fontSize: 12)),
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(36)),
        ),
      ],
    );
  }

  Widget _paramRow(String label, double value, double min, double max, ValueChanged<double> onChanged, {int decimals = 1}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(
            width: 120,
            child: Text(label, style: const TextStyle(fontSize: 11)),
          ),
          Expanded(
            child: Slider(
              value: value.clamp(min, max),
              min: min, max: max,
              onChanged: (v) => setState(() => onChanged(v)),
            ),
          ),
          SizedBox(
            width: 45,
            child: Text(
              value.toStringAsFixed(decimals),
              style: const TextStyle(fontSize: 11, fontFamily: 'monospace'),
            ),
          ),
        ],
      ),
    );
  }

  // ── Measurement tools ────────────────────────────────────────────────

  Widget _buildMeasurementTools() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Klik op de afbeelding na het selecteren van een tool.',
            style: TextStyle(fontSize: 11, color: Colors.grey)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            _toolButton(_MeasurementTool.none, Icons.mouse, 'Temperatuur'),
            _toolButton(_MeasurementTool.spot, Icons.location_on, 'Spot'),
          ],
        ),
      ],
    );
  }

  Widget _toolButton(_MeasurementTool tool, IconData icon, String label) {
    final selected = _activeTool == tool;
    return ChoiceChip(
      avatar: Icon(icon, size: 16),
      label: Text(label, style: const TextStyle(fontSize: 11)),
      selected: selected,
      onSelected: (_) => setState(() => _activeTool = tool),
      visualDensity: VisualDensity.compact,
    );
  }

  // ── Isotherms ────────────────────────────────────────────────────────

  Widget _buildIsothermControls() {
    return _IsothermForm(onAdd: _onAddIsotherm);
  }

  // ── Spot list ────────────────────────────────────────────────────────

  Widget _buildSpotList() {
    final spots = _info?.spots ?? [];
    if (spots.isEmpty) {
      return const Text('Geen meetpunten beschikbaar.', style: TextStyle(fontSize: 12, color: Colors.grey));
    }
    return Column(
      children: spots.map((s) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(
            children: [
              Container(
                width: 24, height: 24,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text('${s.id}', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.primary)),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(s.label.isNotEmpty ? s.label : 'Sp${s.id}',
                    style: const TextStyle(fontSize: 12)),
              ),
              Text(
                '${s.temperature.toStringAsFixed(2)} °C',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, fontFamily: 'monospace'),
              ),
              const SizedBox(width: 4),
              IconButton(
                icon: const Icon(Icons.delete_outline, size: 16, color: Colors.red),
                tooltip: 'Spot verwijderen',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                onPressed: _loading ? null : () => _onRemoveSpot(s.id),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

// ── Isotherm form ──────────────────────────────────────────────────────────

class _IsothermForm extends StatefulWidget {
  final Future<void> Function(FlirIsothermType type, double temp1, double? temp2) onAdd;
  const _IsothermForm({required this.onAdd});

  @override
  State<_IsothermForm> createState() => _IsothermFormState();
}

class _IsothermFormState extends State<_IsothermForm> {
  FlirIsothermType _type = FlirIsothermType.above;
  final _temp1Ctrl = TextEditingController(text: '40');
  final _temp2Ctrl = TextEditingController(text: '45');

  @override
  void dispose() {
    _temp1Ctrl.dispose();
    _temp2Ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SegmentedButton<FlirIsothermType>(
          segments: const [
            ButtonSegment(value: FlirIsothermType.above, label: Text('Boven', style: TextStyle(fontSize: 11))),
            ButtonSegment(value: FlirIsothermType.below, label: Text('Onder', style: TextStyle(fontSize: 11))),
            ButtonSegment(value: FlirIsothermType.interval, label: Text('Interval', style: TextStyle(fontSize: 11))),
          ],
          selected: {_type},
          onSelectionChanged: (s) => setState(() => _type = s.first),
          style: SegmentedButton.styleFrom(visualDensity: VisualDensity.compact),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _temp1Ctrl,
                decoration: InputDecoration(
                  labelText: _type == FlirIsothermType.interval ? 'Min °C' : 'Temp °C',
                  isDense: true,
                  border: const OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
              ),
            ),
            if (_type == FlirIsothermType.interval) ...[
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _temp2Ctrl,
                  decoration: const InputDecoration(
                    labelText: 'Max °C',
                    isDense: true,
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 8),
        FilledButton.icon(
          onPressed: () {
            final t1 = double.tryParse(_temp1Ctrl.text);
            if (t1 == null) return;
            final t2 = _type == FlirIsothermType.interval
                ? double.tryParse(_temp2Ctrl.text)
                : null;
            widget.onAdd(_type, t1, t2);
          },
          icon: const Icon(Icons.add, size: 16),
          label: const Text('Isotherm toevoegen', style: TextStyle(fontSize: 12)),
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(36)),
        ),
      ],
    );
  }
}

// ── Measurement tool enum ──────────────────────────────────────────────────

enum _MeasurementTool { none, spot }

// ── Spot marker overlay widget ────────────────────────────────────────────

class _SpotMarker extends StatelessWidget {
  final FlirSpot spot;
  final bool isDragging;
  const _SpotMarker({required this.spot, this.isDragging = false});

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.grab,
      child: Tooltip(
        message: '${spot.label}: ${spot.temperature.toStringAsFixed(2)} °C',
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: isDragging ? 16 : 12,
              height: isDragging ? 16 : 12,
              decoration: BoxDecoration(
                color: isDragging
                    ? Colors.orange.withValues(alpha: 0.95)
                    : Colors.yellow.withValues(alpha: 0.85),
                shape: BoxShape.circle,
                border: Border.all(
                  color: isDragging ? Colors.white : Colors.black,
                  width: isDragging ? 2 : 1.5,
                ),
              ),
              child: Center(
                child: Text(
                  '${spot.id}',
                  style: TextStyle(
                    fontSize: isDragging ? 9 : 7,
                    fontWeight: FontWeight.bold,
                    color: isDragging ? Colors.white : Colors.black,
                    height: 1,
                  ),
                ),
              ),
            ),
            Container(
              margin: const EdgeInsets.only(top: 1),
              padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
              decoration: BoxDecoration(
                color: Colors.black87,
                borderRadius: BorderRadius.circular(3),
              ),
              child: Text(
                '${spot.temperature.toStringAsFixed(1)}°',
                style: const TextStyle(
                  fontSize: 9,
                  color: Colors.yellow,
                  fontFamily: 'monospace',
                  height: 1.2,
                ),
            ),
          ),
          ],
        ),
      ),
    );
  }
}
