import 'dart:convert';
import 'dart:io';
import 'dart:math' show sqrt;
import 'dart:ui' as ui;

import 'package:desktop_drop/desktop_drop.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/di/injection_container.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/excel_export_service.dart';
import '../../core/utils/flir_extract_service.dart';
import '../../core/utils/thermal_indicator_session.dart';
import '../../core/utils/thermal_measurement.dart';
import 'flir_editor_dialog.dart';

/// Screen for computing the normalized thermal indicator K = ΔT / I²
/// and comparing two measurement points to detect bad electrical connections.
class ThermalIndicatorScreen extends StatefulWidget {
  const ThermalIndicatorScreen({super.key});

  @override
  State<ThermalIndicatorScreen> createState() =>
      _ThermalIndicatorScreenState();
}

class _ThermalIndicatorScreenState extends State<ThermalIndicatorScreen> {
  static const String _flirImagePath =
      '/Users/sjaaj/Downloads/§flir/IR_12078 (1).jpg';
  static const String _recentImagesKey = 'thermal_indicator_recent_images_v1';

  // ── Controllers meting 1 ─────────────────────────────────────────────────
  final _i1Ctrl = TextEditingController(text: '100');
  final _t1Ctrl = TextEditingController(text: '41.0');
  final _di1Ctrl = TextEditingController(text: '1');
  final _dt1Ctrl = TextEditingController(text: '0.5');

  // ── Controllers meting 2 ─────────────────────────────────────────────────
  final _i2Ctrl = TextEditingController(text: '100');
  final _t2Ctrl = TextEditingController(text: '37.3');
  final _di2Ctrl = TextEditingController(text: '1');
  final _dt2Ctrl = TextEditingController(text: '0.5');

  // ── Controllers meting 3 ─────────────────────────────────────────────────
  final _i3Ctrl = TextEditingController(text: '100');
  final _t3Ctrl = TextEditingController(text: '40.1');
  final _di3Ctrl = TextEditingController(text: '1');
  final _dt3Ctrl = TextEditingController(text: '0.5');

  // ── Controllers meting 4 ─────────────────────────────────────────────────
  final _i4Ctrl = TextEditingController(text: '100');
  final _t4Ctrl = TextEditingController(text: '38.7');
  final _di4Ctrl = TextEditingController(text: '1');
  final _dt4Ctrl = TextEditingController(text: '0.5');

  // ── Controllers meting 5 ─────────────────────────────────────────────────
  final _i5Ctrl = TextEditingController(text: '100');
  final _t5Ctrl = TextEditingController(text: '37.7');
  final _di5Ctrl = TextEditingController(text: '1');
  final _dt5Ctrl = TextEditingController(text: '0.5');

  // ── Controllers meting 6 ─────────────────────────────────────────────────
  final _i6Ctrl = TextEditingController(text: '100');
  final _t6Ctrl = TextEditingController(text: '37.5');
  final _di6Ctrl = TextEditingController(text: '1');
  final _dt6Ctrl = TextEditingController(text: '0.5');

  // ── Gedeelde omgevingstemperatuur ────────────────────────────────────────
  final _tambCtrl = TextEditingController(text: '20');

  static const _defaultFlirData = _ExtractedFlirData(
    imagePath: _flirImagePath,
    fileName: 'IR_12078 (1).jpg',
    fileSize: '512.8 KB',
    cameraModel: 'Teledyne FLIR E95',
    software: 'FLIR WebEdit 3.4.24+12',
    captureDate: '2026-03-30 15:59:29',
    resolution: '640 x 480',
    palette: 'iron',
    direction: '212° SW',
    minTemp: 31.2,
    maxTemp: 41.0,
    note:
        'Zichtbare overlay-data uit de aangeleverde JPEG. Volledige radiometrische pixeldata is in dit exportbestand niet bevestigd.',
    mappedPoints: [
      _ExtractedThermalPoint(spot: 'Sp1', label: 'Meetpunt A1', temperature: 41.0),
      _ExtractedThermalPoint(spot: 'Sp2', label: 'Meetpunt A2', temperature: 40.1),
      _ExtractedThermalPoint(spot: 'Sp3', label: 'Meetpunt A3', temperature: 37.7),
      _ExtractedThermalPoint(spot: 'Sp4', label: 'Meetpunt B1', temperature: 37.3),
      _ExtractedThermalPoint(spot: 'Sp5', label: 'Meetpunt B2', temperature: 38.7),
      _ExtractedThermalPoint(spot: 'Sp6', label: 'Meetpunt B3', temperature: 37.5),
    ],
    extraPoints: [
      _ExtractedThermalPoint(spot: 'Sp7', label: 'Extra punt 1', temperature: 39.3),
      _ExtractedThermalPoint(spot: 'Sp8', label: 'Extra punt 2', temperature: 36.7),
    ],
  );

  _ExtractedFlirData _flirData = _defaultFlirData;
  List<_RecentImageEntry> _recentImages = const [];
  bool _isDragActive = false;
  String _measurement1Source = 'Meetpunt A1 (Sp1)';
  String _measurement2Source = 'Meetpunt B1 (Sp4)';
  String _measurement3Source = 'Meetpunt A2 (Sp2)';
  String _measurement4Source = 'Meetpunt B2 (Sp5)';
  String _measurement5Source = 'Meetpunt A3 (Sp3)';
  String _measurement6Source = 'Meetpunt B3 (Sp6)';
  final Map<int, String> _assignedSpotByMeasurement = {
    1: 'Sp1',
    2: 'Sp4',
    3: 'Sp2',
    4: 'Sp5',
    5: 'Sp3',
    6: 'Sp6',
  };
  List<_ComparisonBlockResult> _results = const [];
  _CrossComparisonResult? _crossComparison;
  bool _isExporting = false;

  List<TextEditingController> get _allMeasurementCtrls => [
        _i1Ctrl, _t1Ctrl, _di1Ctrl, _dt1Ctrl,
        _i2Ctrl, _t2Ctrl, _di2Ctrl, _dt2Ctrl,
        _i3Ctrl, _t3Ctrl, _di3Ctrl, _dt3Ctrl,
        _i4Ctrl, _t4Ctrl, _di4Ctrl, _dt4Ctrl,
        _i5Ctrl, _t5Ctrl, _di5Ctrl, _dt5Ctrl,
        _i6Ctrl, _t6Ctrl, _di6Ctrl, _dt6Ctrl,
        _tambCtrl,
      ];

  @override
  void initState() {
    super.initState();
    _loadRecentImages();
    ThermalIndicatorSessionStore.pendingLoad.addListener(_onPendingLoadChanged);
    // Wis berekeningen zodra een invoerveld wijzigt
    for (final c in _allMeasurementCtrls) {
      c.addListener(_clearResults);
    }
    // Already-queued session (e.g. loaded before this screen built)
    _onPendingLoadChanged();
  }

  void _clearResults() {
    if (_results.isNotEmpty || _crossComparison != null) {
      setState(() {
        _results = const [];
        _crossComparison = null;
      });
    }
  }

  @override
  void dispose() {
    ThermalIndicatorSessionStore.pendingLoad
        .removeListener(_onPendingLoadChanged);
    for (final c in _allMeasurementCtrls) {
      c.removeListener(_clearResults);
      c.dispose();
    }
    super.dispose();
  }

  // ── Parse helpers ─────────────────────────────────────────────────────────

  double? _parse(TextEditingController c) => double.tryParse(c.text);

  ThermalMeasurement? _buildMeasurement(
    TextEditingController iCtrl,
    TextEditingController tCtrl,
    TextEditingController diCtrl,
    TextEditingController dtCtrl,
  ) {
    final i = _parse(iCtrl);
    final t = _parse(tCtrl);
    final di = _parse(diCtrl);
    final dt = _parse(dtCtrl);
    final tamb = _parse(_tambCtrl);
    if (i == null || t == null || di == null || dt == null || tamb == null) {
      return null;
    }
    return ThermalMeasurement(
      current: i,
      temperature: t,
      ambient: tamb,
      currentError: di,
      temperatureError: dt,
    );
  }

  void _calculate() {
    final m1 = _buildMeasurement(_i1Ctrl, _t1Ctrl, _di1Ctrl, _dt1Ctrl);
    final m2 = _buildMeasurement(_i2Ctrl, _t2Ctrl, _di2Ctrl, _dt2Ctrl);
    final m3 = _buildMeasurement(_i3Ctrl, _t3Ctrl, _di3Ctrl, _dt3Ctrl);
    final m4 = _buildMeasurement(_i4Ctrl, _t4Ctrl, _di4Ctrl, _dt4Ctrl);
    final m5 = _buildMeasurement(_i5Ctrl, _t5Ctrl, _di5Ctrl, _dt5Ctrl);
    final m6 = _buildMeasurement(_i6Ctrl, _t6Ctrl, _di6Ctrl, _dt6Ctrl);

    const invalidMsg = 'Controleer de invoer — alle velden moeten geldige getallen bevatten.';

    final bindings = _measurementBindings();
    final tamb = _parse(_tambCtrl) ?? 20.0;
    final kEntries = <_KEntry>[];
    final measurements = [m1, m2, m3, m4, m5, m6];
    for (int i = 0; i < 6; i++) {
      final m = measurements[i];
      final b = bindings[i];
      if (m == null) continue;
      final dT = m.temperature - tamb;
      if (dT < 0.5 || m.current <= 0) continue;
      final k = dT / (m.current * m.current);
      // dK/K = sqrt((dT/dT)^2 + (2·dI/I)^2)
      final relDt = m.temperatureError / dT;
      final relI = 2.0 * m.currentError / m.current;
      final dk = k * (relDt * relDt + relI * relI <= 0
          ? 0.0
          : (relDt * relDt + relI * relI) < 1e-20
              ? 0.0
              : _sqrt(relDt * relDt + relI * relI));
      kEntries.add(_KEntry(
        id: b.id,
        label: b.label,
        sourceLabel: b.sourceLabel,
        color: b.color,
        current: m.current,
        temperature: m.temperature,
        deltaT: dT,
        k: k,
        dk: dk,
      ));
    }
    kEntries.sort((a, b) => b.k.compareTo(a.k));

    _CrossComparisonResult? cross;
    if (kEntries.isNotEmpty) {
      // Reference: Meting 1 (id == 1); fall back to first entry if not present
      final kRef = kEntries.firstWhere(
        (e) => e.id == 1,
        orElse: () => kEntries.first,
      );
      final enriched = kEntries.map((e) {
        if (e.id == kRef.id) return e.copyWith(snr: 0, snrLevel: SnrLevel.notSignificant);
        final dKCombined = _sqrt(e.dk * e.dk + kRef.dk * kRef.dk);
        final snr = dKCombined > 1e-20 ? (e.k - kRef.k) / dKCombined : 0.0;
        final level = snr >= 3
            ? SnrLevel.significant
            : snr >= 1
                ? SnrLevel.uncertain
                : SnrLevel.notSignificant;
        return e.copyWith(snr: snr, snrLevel: level);
      }).toList();
      cross = _CrossComparisonResult(
        entries: enriched,
        kRef: kRef,
        tamb: tamb,
      );
    }

    setState(() {
      _results = [
        _buildBlock('Meting 1 ↔ Meting 2', m1, m2, invalidMsg),
        _buildBlock('Meting 3 ↔ Meting 4', m3, m4, invalidMsg),
        _buildBlock('Meting 5 ↔ Meting 6', m5, m6, invalidMsg),
      ];
      _crossComparison = cross;
    });
  }

  static double _sqrt(double v) => v <= 0 ? 0 : sqrt(v);

  Future<void> _exportToExcel() async {
    if (_isExporting) return;
    setState(() => _isExporting = true);
    try {
      final bindings = _measurementBindings();
      final rows = <MeasurementExportRow>[];
      for (final b in bindings) {
        final i = _parse(b.currentCtrl);
        final t = _parse(b.temperatureCtrl);
        final di = _parse(b.currentErrorCtrl);
        final dt = _parse(b.temperatureErrorCtrl);
        if (i == null || t == null || di == null || dt == null) {
          _showMessage(
              'Controleer de invoer — alle velden moeten geldige getallen bevatten.');
          return;
        }
        rows.add(MeasurementExportRow(
          label: b.label,
          source: b.sourceLabel,
          current: i,
          currentError: di,
          temperature: t,
          temperatureError: dt,
        ));
      }
      final tamb = _parse(_tambCtrl) ?? 20.0;
      final path = await ThermalExcelExportService.export(
        measurements: rows,
        tamb: tamb,
      );
      await Share.shareXFiles(
        [XFile(path)],
        subject: 'Thermische indicator K — export',
      );
    } catch (e) {
      _showExportError('$e');
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  _ComparisonBlockResult _buildBlock(
    String title,
    ThermalMeasurement? mA,
    ThermalMeasurement? mB,
    String invalidMsg,
  ) {
    if (mA == null || mB == null) {
      return _ComparisonBlockResult(
        title: title,
        result: ComparisonResult.invalid(invalidMsg),
      );
    }

    final result = ThermalMeasurement.compare(mA, mB);
    final tamb = _parse(_tambCtrl) ?? 20.0;
    final dTA = mA.temperature - tamb;
    final dTB = mB.temperature - tamb;
    final iA2 = mA.current * mA.current;
    final iB2 = mB.current * mB.current;

    _DeltaTCorrected? corr;
    if (iB2.abs() > 1e-6 && dTA.abs() > 1e-6 && dTB.abs() > 1e-6) {
      final ratio = iA2 / iB2;
      corr = _DeltaTCorrected(
        dtCorrected: dTA - ratio * dTB,
        deltaI2T: iA2 / dTA - iB2 / dTB,
        deltaI2ratio: ratio - dTA / dTB,
        deltaT2: dTA - ratio * dTB,
        deltaTperI2: (iA2 > 1e-6 && iB2 > 1e-6) ? dTA / iA2 - dTB / iB2 : double.nan,
      );
    }

    return _ComparisonBlockResult(title: title, result: result, deltaTCorr: corr);
  }

  File? get _flirImageFile {
    final file = File(_flirData.imagePath);
    return file.existsSync() ? file : null;
  }

  List<_PinnedImageEntry> get _pinnedImages => const [
        _PinnedImageEntry(
          title: 'Voorbeeld FLIR E95',
          subtitle: 'Vooringevulde meetpunten A1 t/m B3',
          path: _flirImagePath,
        ),
      ];

  SharedPreferences get _prefs => sl<SharedPreferences>();

  Future<void> _loadRecentImages() async {
    final raw = _prefs.getStringList(_recentImagesKey) ?? const [];
    final parsed = <_RecentImageEntry>[];
    for (final item in raw) {
      try {
        final map = jsonDecode(item) as Map<String, dynamic>;
        parsed.add(_RecentImageEntry.fromJson(map));
      } catch (_) {
        continue;
      }
    }

    if (!mounted) return;
    setState(() {
      _recentImages = parsed;
    });
  }

  Future<void> _persistRecentImages() async {
    await _prefs.setStringList(
      _recentImagesKey,
      _recentImages.map((entry) => jsonEncode(entry.toJson())).toList(),
    );
  }

  Future<void> _pickImage() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['jpg', 'jpeg', 'png', 'bmp', 'webp', 'tif', 'tiff'],
    );

    if (result == null) return;

    final file = result.files.single;
    final path = file.path;
    if (path == null) return;

    await _loadImageFromPath(path, suggestedName: file.name, byteSize: file.size);
  }

  Future<void> _loadImageFromPath(
    String path, {
    String? suggestedName,
    int? byteSize,
  }) async {
    final file = File(path);
    if (!file.existsSync()) {
      _showMessage('Bestand niet gevonden: $path');
      await _removeRecentImage(path);
      return;
    }

    final nextData = await _buildFlirDataFromPath(
      path,
      suggestedName: suggestedName,
      byteSize: byteSize,
    );

    if (!mounted) return;

    setState(() {
      _flirData = nextData;
      _results = const [];
      _assignedSpotByMeasurement.clear();

      // Auto-assign spots to measurements if available
      final allPoints = [...nextData.mappedPoints, ...nextData.extraPoints];
      for (int m = 1; m <= 6 && m <= allPoints.length; m++) {
        final point = allPoints[m - 1];
        _assignedSpotByMeasurement[m] = point.spot;
        _setTemperatureValue(m, point.temperature.toStringAsFixed(1));
        _setSourceLabel(m, '${point.label} (${point.spot})');
      }
      // Clear any unassigned measurements
      for (int m = allPoints.length + 1; m <= 6; m++) {
        _clearMeasurementFields(m);
        _setSourceLabel(m, 'Handmatige invoer');
      }
    });

    await _rememberRecentImage(nextData);
  }

  Future<void> _handleDroppedFiles(List<String> paths) async {
    if (paths.isEmpty) return;
    setState(() {
      _isDragActive = false;
    });
    await _loadImageFromPath(paths.first);
  }

  Future<void> _rememberRecentImage(_ExtractedFlirData data) async {
    final updated = [
      _RecentImageEntry(
        path: data.imagePath,
        fileName: data.fileName,
        subtitle: data.cameraModel,
        lastOpened: DateTime.now(),
      ),
      ..._recentImages.where((entry) => entry.path != data.imagePath),
    ].take(6).toList();

    setState(() {
      _recentImages = updated;
    });
    await _persistRecentImages();
  }

  Future<void> _removeRecentImage(String path) async {
    final updated = _recentImages.where((entry) => entry.path != path).toList();
    setState(() {
      _recentImages = updated;
    });
    await _persistRecentImages();
  }

  Future<_ExtractedFlirData> _buildFlirDataFromPath(
    String path, {
    String? suggestedName,
    int? byteSize,
  }) async {
    final fileName = suggestedName ?? _fileNameFromPath(path);
    final resolution = await _readImageResolution(path);
    final size = byteSize ?? await File(path).length();
    final stats = await File(path).stat();

    // Try radiometric extraction via FLIR Atlas SDK
    final flir = await FlirExtractService.extract(path);

    if (flir != null && flir.ok) {
      final cam = flir.camera;
      final tp = flir.thermalParams;
      final compass = flir.compass;

      // Split spots: first 6 as mapped, rest as extra
      final allSpots = flir.spots.where((s) => s.isValid).toList();
      final mapped = allSpots.length > 6
          ? allSpots.sublist(0, 6)
          : allSpots;
      final extra = allSpots.length > 6
          ? allSpots.sublist(6)
          : <FlirSpot>[];

      return _ExtractedFlirData(
        imagePath: path,
        fileName: fileName,
        fileSize: _formatFileSize(size),
        cameraModel: cam?.model ?? 'Onbekend',
        software: cam?.programVersion ?? 'Onbekend',
        captureDate: _formatTimestamp(stats.modified),
        resolution: resolution ?? '${flir.width} x ${flir.height}',
        palette: 'Radiometrisch (Atlas SDK)',
        direction: compass != null ? compass.directionLabel : 'Onbekend',
        minTemp: tp != null
            ? (cam?.rangeMin != null ? cam!.rangeMin - 273.15 : null)
            : null,
        maxTemp: tp != null
            ? (cam?.rangeMax != null ? cam!.rangeMax - 273.15 : null)
            : null,
        note: 'Radiometrische data uitgelezen via FLIR Atlas C SDK. '
            'Camera: ${cam?.model ?? "?"}, '
            'Serienummer: ${cam?.serial ?? "?"}, '
            'Emissiviteit: ${tp?.emissivity.toStringAsFixed(2) ?? "?"}, '
            'Afstand: ${tp?.objectDistance.toStringAsFixed(1) ?? "?"} m.',
        mappedPoints: mapped
            .map((s) => _ExtractedThermalPoint(
                  spot: 'Sp${s.id}',
                  label: s.label.isNotEmpty ? s.label : 'Sp${s.id}',
                  temperature: s.temperature,
                ))
            .toList(),
        extraPoints: extra
            .map((s) => _ExtractedThermalPoint(
                  spot: 'Sp${s.id}',
                  label: s.label.isNotEmpty ? s.label : 'Sp${s.id}',
                  temperature: s.temperature,
                ))
            .toList(),
      );
    }

    // Fallback: no radiometric data available
    return _ExtractedFlirData(
      imagePath: path,
      fileName: fileName,
      fileSize: _formatFileSize(size),
      cameraModel: 'Niet automatisch uitgelezen',
      software: 'Niet automatisch uitgelezen',
      captureDate: _formatTimestamp(stats.modified),
      resolution: resolution ?? 'Onbekend',
      palette: 'Niet automatisch uitgelezen',
      direction: 'Niet automatisch uitgelezen',
      minTemp: null,
      maxTemp: null,
      note: flir?.message ??
          'Geen radiometrische FLIR-data gevonden in dit bestand. '
              'Meetpunten moeten handmatig worden ingevoerd.',
      mappedPoints: const [],
      extraPoints: const [],
    );
  }

  Future<String?> _readImageResolution(String path) async {
    try {
      final bytes = await File(path).readAsBytes();
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      final image = frame.image;
      final resolution = '${image.width} x ${image.height}';
      image.dispose();
      return resolution;
    } catch (_) {
      return null;
    }
  }

  String _fileNameFromPath(String path) => path.split(Platform.pathSeparator).last;

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
  }

  String _formatTimestamp(DateTime value) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${value.year}-${two(value.month)}-${two(value.day)} '
        '${two(value.hour)}:${two(value.minute)}:${two(value.second)}';
  }

  String _formatRelativeTime(DateTime value) {
    final diff = DateTime.now().difference(value);
    if (diff.inMinutes < 1) return 'zojuist';
    if (diff.inHours < 1) return '${diff.inMinutes} min geleden';
    if (diff.inDays < 1) return '${diff.inHours} uur geleden';
    return '${diff.inDays} d geleden';
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  void _showExportError(String error) {
    if (!mounted) return;
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Fout bij exporteren'),
        content: SingleChildScrollView(
          child: SelectableText(
            error,
            style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Sluiten'),
          ),
        ],
      ),
    );
  }

  void _onPendingLoadChanged() {
    final session = ThermalIndicatorSessionStore.pendingLoad.value;
    if (session == null) return;
    _applySession(session);
    ThermalIndicatorSessionStore.pendingLoad.value = null;
  }

  void _applySession(ThermalIndicatorSession session) {
    setState(() {
      _tambCtrl.text = session.ambient.toStringAsFixed(1);
      for (final m in session.measurements) {
        final (iCtrl, tCtrl, diCtrl, dtCtrl) = switch (m.id) {
          1 => (_i1Ctrl, _t1Ctrl, _di1Ctrl, _dt1Ctrl),
          2 => (_i2Ctrl, _t2Ctrl, _di2Ctrl, _dt2Ctrl),
          3 => (_i3Ctrl, _t3Ctrl, _di3Ctrl, _dt3Ctrl),
          4 => (_i4Ctrl, _t4Ctrl, _di4Ctrl, _dt4Ctrl),
          5 => (_i5Ctrl, _t5Ctrl, _di5Ctrl, _dt5Ctrl),
          6 => (_i6Ctrl, _t6Ctrl, _di6Ctrl, _dt6Ctrl),
          _ => (null, null, null, null),
        };
        if (iCtrl == null) continue;
        iCtrl.text = m.current.toStringAsFixed(1);
        tCtrl!.text = m.temperature.toStringAsFixed(1);
        diCtrl!.text = m.currentError.toString();
        dtCtrl!.text = m.temperatureError.toString();
        _setSourceLabel(m.id, m.sourceLabel);
      }
      _results = const [];
    });
    _showMessage('Sessie "${session.name}" geladen.');
  }

  Future<void> _saveSession() async {
    final tamb = _parse(_tambCtrl);
    if (tamb == null) {
      _showMessage('Vul een geldige omgevingstemperatuur in.');
      return;
    }

    final defaultName = 'Thermische indicator '
        '${_formatTimestamp(DateTime.now())}';
    final nameCtrl = TextEditingController(text: defaultName);
    final noteCtrl = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sessie opslaan'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(
                labelText: 'Naam',
                border: OutlineInputBorder(),
              ),
              autofocus: true,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: noteCtrl,
              decoration: const InputDecoration(
                labelText: 'Notitie (optioneel)',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuleren'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Opslaan'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) {
      nameCtrl.dispose();
      noteCtrl.dispose();
      return;
    }

    final bindings = _measurementBindings();
    final measurements = <ThermalIndicatorMeasurement>[];
    for (final b in bindings) {
      measurements.add(ThermalIndicatorMeasurement(
        id: b.id,
        label: b.label,
        sourceLabel: b.sourceLabel,
        current: _parse(b.currentCtrl) ?? 0,
        temperature: _parse(b.temperatureCtrl) ?? 0,
        currentError: _parse(b.currentErrorCtrl) ?? 0,
        temperatureError: _parse(b.temperatureErrorCtrl) ?? 0,
      ));
    }

    final name = nameCtrl.text.trim().isEmpty
        ? defaultName
        : nameCtrl.text.trim();
    final note = noteCtrl.text.trim().isEmpty ? null : noteCtrl.text.trim();
    nameCtrl.dispose();
    noteCtrl.dispose();

    final session = ThermalIndicatorSession(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      name: name,
      createdAt: DateTime.now(),
      ambient: tamb,
      measurements: measurements,
      imagePath: _flirData.imagePath,
      imageFileName: _flirData.fileName,
      note: note,
    );

    await ThermalIndicatorSessionStore(_prefs).save(session);
    if (!mounted) return;
    _showMessage('Sessie "$name" opgeslagen in Historie.');
  }

  void _setSourceLabel(int measurement, String label) {
    switch (measurement) {
      case 1: _measurement1Source = label; break;
      case 2: _measurement2Source = label; break;
      case 3: _measurement3Source = label; break;
      case 4: _measurement4Source = label; break;
      case 5: _measurement5Source = label; break;
      case 6: _measurement6Source = label; break;
    }
  }

  void _setTemperatureValue(int measurement, String value) {
    switch (measurement) {
      case 1: _t1Ctrl.text = value; break;
      case 2: _t2Ctrl.text = value; break;
      case 3: _t3Ctrl.text = value; break;
      case 4: _t4Ctrl.text = value; break;
      case 5: _t5Ctrl.text = value; break;
      case 6: _t6Ctrl.text = value; break;
    }
  }

  /// Wist alle invoervelden (T, I, δI, δT) van een niet-toegewezen meting.
  void _clearMeasurementFields(int measurement) {
    switch (measurement) {
      case 1: _t1Ctrl.text = ''; _i1Ctrl.text = ''; _di1Ctrl.text = ''; _dt1Ctrl.text = ''; break;
      case 2: _t2Ctrl.text = ''; _i2Ctrl.text = ''; _di2Ctrl.text = ''; _dt2Ctrl.text = ''; break;
      case 3: _t3Ctrl.text = ''; _i3Ctrl.text = ''; _di3Ctrl.text = ''; _dt3Ctrl.text = ''; break;
      case 4: _t4Ctrl.text = ''; _i4Ctrl.text = ''; _di4Ctrl.text = ''; _dt4Ctrl.text = ''; break;
      case 5: _t5Ctrl.text = ''; _i5Ctrl.text = ''; _di5Ctrl.text = ''; _dt5Ctrl.text = ''; break;
      case 6: _t6Ctrl.text = ''; _i6Ctrl.text = ''; _di6Ctrl.text = ''; _dt6Ctrl.text = ''; break;
    }
  }

  void _applyPointToMeasurement(_ExtractedThermalPoint point, int measurement) {
    setState(() {
      // Enforce 1:1: verwijder dit punt van een eventuele andere meting
      for (final key in _assignedSpotByMeasurement.keys.toList()) {
        if (_assignedSpotByMeasurement[key] == point.spot && key != measurement) {
          _assignedSpotByMeasurement.remove(key);
          _setSourceLabel(key, 'Handmatige invoer');
        }
      }
      _setTemperatureValue(measurement, point.temperature.toStringAsFixed(1));
      _setSourceLabel(measurement, '${point.label} (${point.spot})');
      _assignedSpotByMeasurement[measurement] = point.spot;
      _results = const [];
    });
  }

  void _handlePointAssignment(_ExtractedThermalPoint point, int? measurement) {
    if (measurement == null) {
      // Ontkoppel dit punt
      setState(() {
        for (final key in _assignedSpotByMeasurement.keys.toList()) {
          if (_assignedSpotByMeasurement[key] == point.spot) {
            _assignedSpotByMeasurement.remove(key);
            _setSourceLabel(key, 'Handmatige invoer');
          }
        }
        _results = const [];
      });
    } else {
      _applyPointToMeasurement(point, measurement);
    }
  }

  int? _assignedMeasurementForPoint(_ExtractedThermalPoint point) {
    for (final entry in _assignedSpotByMeasurement.entries) {
      if (entry.value == point.spot) return entry.key;
    }
    return null;
  }

  List<_MeasurementBinding> _measurementBindings() => [
        _MeasurementBinding(
          id: 1,
          label: 'Meting 1',
          color: AppTheme.chartA,
          sourceLabel: _measurement1Source,
          assignedSpot: _assignedSpotByMeasurement[1],
          temperatureCtrl: _t1Ctrl,
          currentCtrl: _i1Ctrl,
          currentErrorCtrl: _di1Ctrl,
          temperatureErrorCtrl: _dt1Ctrl,
        ),
        _MeasurementBinding(
          id: 2,
          label: 'Meting 2',
          color: AppTheme.chartB,
          sourceLabel: _measurement2Source,
          assignedSpot: _assignedSpotByMeasurement[2],
          temperatureCtrl: _t2Ctrl,
          currentCtrl: _i2Ctrl,
          currentErrorCtrl: _di2Ctrl,
          temperatureErrorCtrl: _dt2Ctrl,
        ),
        _MeasurementBinding(
          id: 3,
          label: 'Meting 3',
          color: AppTheme.statusWarning,
          sourceLabel: _measurement3Source,
          assignedSpot: _assignedSpotByMeasurement[3],
          temperatureCtrl: _t3Ctrl,
          currentCtrl: _i3Ctrl,
          currentErrorCtrl: _di3Ctrl,
          temperatureErrorCtrl: _dt3Ctrl,
        ),
        _MeasurementBinding(
          id: 4,
          label: 'Meting 4',
          color: AppTheme.statusFault,
          sourceLabel: _measurement4Source,
          assignedSpot: _assignedSpotByMeasurement[4],
          temperatureCtrl: _t4Ctrl,
          currentCtrl: _i4Ctrl,
          currentErrorCtrl: _di4Ctrl,
          temperatureErrorCtrl: _dt4Ctrl,
        ),
        _MeasurementBinding(
          id: 5,
          label: 'Meting 5',
          color: const Color(0xFF6A1B9A),
          sourceLabel: _measurement5Source,
          assignedSpot: _assignedSpotByMeasurement[5],
          temperatureCtrl: _t5Ctrl,
          currentCtrl: _i5Ctrl,
          currentErrorCtrl: _di5Ctrl,
          temperatureErrorCtrl: _dt5Ctrl,
        ),
        _MeasurementBinding(
          id: 6,
          label: 'Meting 6',
          color: const Color(0xFF00838F),
          sourceLabel: _measurement6Source,
          assignedSpot: _assignedSpotByMeasurement[6],
          temperatureCtrl: _t6Ctrl,
          currentCtrl: _i6Ctrl,
          currentErrorCtrl: _di6Ctrl,
          temperatureErrorCtrl: _dt6Ctrl,
        ),
      ];


  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Thermische indicator K'),
        actions: [
          IconButton(
            tooltip: 'Sessie opslaan',
            icon: const Icon(Icons.save_outlined),
            onPressed: _saveSession,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          // Info banner
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppTheme.primary, AppTheme.primaryDark],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'K = ΔT / I²  [°C/A²]',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    fontFamily: 'monospace',
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Een hogere K-waarde betekent een hogere thermische weerstand. '
                  'Vergelijking van K tussen twee metingen onthult een slechte verbinding, '
                  'gecorrigeerd voor verschillen in stroom.',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          LayoutBuilder(
            builder: (context, constraints) {
              final imageCard = _ImagePreviewCard(
                data: _flirData,
                imageFile: _flirImageFile,
                onPickImage: _pickImage,
                onEdit: () async {
                  await FlirEditorDialog.show(context, _flirData.imagePath);
                  // Herlaad image data na editor (spots kunnen gewijzigd zijn)
                  if (!mounted) return;
                  await _loadImageFromPath(_flirData.imagePath);
                },
                isDragActive: _isDragActive,
                onDragEntered: () => setState(() => _isDragActive = true),
                onDragExited: () => setState(() => _isDragActive = false),
                onDropPaths: _handleDroppedFiles,
              );
              final pointsPanel = _PointAssignmentPanel(
                data: _flirData,
                onAssignmentChanged: _handlePointAssignment,
                assignedMeasurementForPoint: _assignedMeasurementForPoint,
              );

              if (constraints.maxWidth >= 760) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: imageCard),
                    const SizedBox(width: 12),
                    Expanded(child: pointsPanel),
                  ],
                );
              }

              return Column(
                children: [
                  imageCard,
                  const SizedBox(height: 12),
                  pointsPanel,
                ],
              );
            },
          ),
          const SizedBox(height: 12),

          _ImageLibraryCard(
            pinnedImages: _pinnedImages,
            recentImages: _recentImages,
            formatRelativeTime: _formatRelativeTime,
            onOpenPinned: (entry) => _loadImageFromPath(entry.path),
            onOpenRecent: (entry) => _loadImageFromPath(entry.path),
            onRemoveRecent: (entry) => _removeRecentImage(entry.path),
          ),
          const SizedBox(height: 12),

          _FlirDataCard(data: _flirData),
          const SizedBox(height: 12),

          // Gedeelde omgevingstemperatuur
          Card(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: Row(
                children: [
                  const Icon(Icons.thermostat_outlined,
                      size: 20, color: AppTheme.primary),
                  const SizedBox(width: 10),
                  const Text('Omgevingstemperatuur (T_amb):',
                      style: TextStyle(fontSize: 13)),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 80,
                    child: _NumberField(
                      controller: _tambCtrl,
                      label: '°C',
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 4),

          // Meting 1 en 2 naast elkaar
          LayoutBuilder(
            builder: (context, constraints) {
              final measurementCards = _measurementBindings()
                  .map(
                    (binding) => _MeasurementCard(
                      label: binding.label,
                      sourceLabel: binding.sourceLabel,
                      color: binding.color,
                      iCtrl: binding.currentCtrl,
                      tCtrl: binding.temperatureCtrl,
                      diCtrl: binding.currentErrorCtrl,
                      dtCtrl: binding.temperatureErrorCtrl,
                      tambCtrl: _tambCtrl,
                    ),
                  )
                  .toList();

              if (constraints.maxWidth >= 760) {
                return Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: measurementCards
                      .map(
                        (card) => SizedBox(
                          width: (constraints.maxWidth - 8) / 2,
                          child: card,
                        ),
                      )
                      .toList(),
                );
              }

              return Column(
                children: [
                  for (int i = 0; i < measurementCards.length; i++) ...[
                    measurementCards[i],
                    if (i < measurementCards.length - 1)
                      const SizedBox(height: 8),
                  ],
                ],
              );
            },
          ),

          const SizedBox(height: 12),

          // Bereken knop
          FilledButton.icon(
            onPressed: _calculate,
            icon: const Icon(Icons.calculate_outlined),
            label: const Text('Bereken meting 1-2, 3-4 en 5-6'),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
            ),
          ),

          const SizedBox(height: 8),

          // Excel-export knop
          OutlinedButton.icon(
            onPressed: _isExporting ? null : _exportToExcel,
            icon: _isExporting
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.table_chart_outlined),
            label: Text(_isExporting ? 'Exporteren…' : 'Exporteer naar Excel'),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
            ),
          ),

          const SizedBox(height: 12),

          // Resultaat
          if (_results.isNotEmpty)
            ..._results.map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _ResultCard(
                  title: item.title,
                  result: item.result,
                  deltaTCorr: item.deltaTCorr,
                ),
              ),
            ),

          if (_crossComparison != null) ...[
            _CrossComparisonCard(result: _crossComparison!),
            const SizedBox(height: 12),
          ],

          // NPR 8040-1 beoordeling (methoden 1, 2, 3)
          _NprAssessmentCard(
            bindings: _measurementBindings(),
            tambCtrl: _tambCtrl,
          ),
          const SizedBox(height: 12),

          // Uitleg formules
          const _ExplanationCard(),
        ],
      ),
    );
  }
}

// ─── Invoerkaart per meting ───────────────────────────────────────────────────

class _MeasurementCard extends StatefulWidget {
  final String label;
  final String sourceLabel;
  final Color color;
  final TextEditingController iCtrl;
  final TextEditingController tCtrl;
  final TextEditingController diCtrl;
  final TextEditingController dtCtrl;
  final TextEditingController tambCtrl;

  const _MeasurementCard({
    required this.label,
    required this.sourceLabel,
    required this.color,
    required this.iCtrl,
    required this.tCtrl,
    required this.diCtrl,
    required this.dtCtrl,
    required this.tambCtrl,
  });

  @override
  State<_MeasurementCard> createState() => _MeasurementCardState();
}

class _MeasurementCardState extends State<_MeasurementCard> {
  // Live K preview
  double? get _liveK {
    final i = double.tryParse(widget.iCtrl.text);
    final t = double.tryParse(widget.tCtrl.text);
    final tamb = double.tryParse(widget.tambCtrl.text);
    if (i == null || t == null || tamb == null || i <= 0) return null;
    final dT = t - tamb;
    if (dT < 0.5) return null;
    return dT / (i * i);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final k = _liveK;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 12,
                  backgroundColor: widget.color.withValues(alpha: 0.15),
                  child: Text(
                    widget.label.split(' ').last,
                    style: TextStyle(
                        color: widget.color,
                        fontWeight: FontWeight.bold,
                        fontSize: 11),
                  ),
                ),
                const SizedBox(width: 8),
                Text(widget.label,
                    style: theme.textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Bron: ${widget.sourceLabel}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: Colors.grey.shade700,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 10),
            _NumberField(
              controller: widget.iCtrl,
              label: 'I (A)',
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 6),
            _NumberField(
              controller: widget.tCtrl,
              label: 'T (°C)',
              onChanged: (_) => setState(() {}),
            ),
            const Divider(height: 16),
            Text('Meetonzekerheid',
                style: theme.textTheme.labelSmall
                    ?.copyWith(color: Colors.grey.shade600)),
            const SizedBox(height: 6),
            _NumberField(controller: widget.diCtrl, label: 'dI (A)'),
            const SizedBox(height: 6),
            _NumberField(controller: widget.dtCtrl, label: 'dT (°C)'),
            if (k != null) ...[
              const SizedBox(height: 10),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                decoration: BoxDecoration(
                  color: widget.color.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Text('K = ',
                        style: TextStyle(
                            fontSize: 12, color: widget.color)),
                    Text(
                      k.toStringAsExponential(3),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: widget.color,
                        fontFamily: 'monospace',
                      ),
                    ),
                    Text(' °C/A²',
                        style: TextStyle(fontSize: 11, color: widget.color)),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ─── Resultaatkaart ───────────────────────────────────────────────────────────

class _ResultCard extends StatelessWidget {
  final String title;
  final ComparisonResult result;
  final _DeltaTCorrected? deltaTCorr;
  const _ResultCard({
    required this.title,
    required this.result,
    this.deltaTCorr,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final (bgColor, borderColor, icon) = switch (result.snrLevel) {
      SnrLevel.significant => (
          AppTheme.statusFault.withValues(alpha: 0.08),
          AppTheme.statusFault,
          Icons.warning_amber_rounded,
        ),
      SnrLevel.uncertain => (
          AppTheme.statusWarning.withValues(alpha: 0.08),
          AppTheme.statusWarning,
          Icons.help_outline_rounded,
        ),
      SnrLevel.notSignificant => (
          AppTheme.statusOk.withValues(alpha: 0.08),
          AppTheme.statusOk,
          Icons.check_circle_outline_rounded,
        ),
      SnrLevel.invalid => (
          Colors.grey.withValues(alpha: 0.08),
          Colors.grey,
          Icons.error_outline_rounded,
        ),
    };

    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: borderColor, width: 1.5),
      ),
      color: bgColor,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: borderColor, size: 22),
                const SizedBox(width: 8),
                Text(title,
                    style: theme.textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 12),

            // Diagnostische tekst
            Text(
              result.diagnostic,
              style: const TextStyle(fontSize: 13, height: 1.45),
            ),

            if (result.isValid) ...[
              const Divider(height: 20),

              // K waarden
              _ResultRow(
                label: 'K₁',
                value: result.k1!.toStringAsExponential(4),
                sub: '± ${result.dk1!.toStringAsExponential(2)}',
                unit: '°C/A²',
                color: AppTheme.chartA,
              ),
              _ResultRow(
                label: 'K₂',
                value: result.k2!.toStringAsExponential(4),
                sub: '± ${result.dk2!.toStringAsExponential(2)}',
                unit: '°C/A²',
                color: AppTheme.chartB,
              ),
              const Divider(height: 16),
              _ResultRow(
                label: 'ΔK = K₁ − K₂',
                value: result.deltaK!.toStringAsExponential(4),
                unit: '°C/A²',
              ),
              _ResultRow(
                label: 'Onzekerheid d(ΔK)',
                value: '± ${result.uncertainty!.toStringAsExponential(3)}',
                unit: '°C/A²',
              ),
              const Divider(height: 16),
              _SnrRow(snr: result.snr!, level: result.snrLevel),
            ],

            // ΔT gecorrigeerd voor stroom
            if (deltaTCorr != null) ...[
              const Divider(height: 20),
              Text(
                'ΔT gecorrigeerd voor stroom',
                style: theme.textTheme.titleSmall
                    ?.copyWith(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              const SizedBox(height: 8),
              _CorrRow(
                formula: '(T₁−Tamb) − (I₁/I₂)²×(T₂−Tamb)',
                value: deltaTCorr!.dtCorrected,
                unit: '°C',
              ),
              _CorrRow(
                formula: 'I₁²/ΔT₁ − I₂²/ΔT₂',
                value: deltaTCorr!.deltaI2T,
                unit: 'A²/°C',
              ),
              _CorrRow(
                formula: '(I₁²/I₂²) − (ΔT₁/ΔT₂)',
                value: deltaTCorr!.deltaI2ratio,
                unit: '',
              ),
              _CorrRow(
                formula: 'ΔT₁ − (I₁²/I₂²)×ΔT₂',
                value: deltaTCorr!.deltaT2,
                unit: '°C',
              ),
              _CorrRow(
                formula: 'Δ(T/I²) = ΔT₁/I₁² − ΔT₂/I₂²',
                value: deltaTCorr!.deltaTperI2,
                unit: '°C/A²',
                exponential: true,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ResultRow extends StatelessWidget {
  final String label;
  final String value;
  final String? sub;
  final String unit;
  final Color? color;

  const _ResultRow({
    required this.label,
    required this.value,
    this.sub,
    required this.unit,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(
            child: Text(label,
                style: TextStyle(
                    fontSize: 13,
                    color: color,
                    fontWeight:
                        color != null ? FontWeight.w600 : FontWeight.normal)),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              fontFamily: 'monospace',
              color: color,
            ),
          ),
          if (sub != null)
            Text(' $sub',
                style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey.shade600,
                    fontFamily: 'monospace')),
          Text('  $unit',
              style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
        ],
      ),
    );
  }
}

class _SnrRow extends StatelessWidget {
  final double snr;
  final SnrLevel level;
  const _SnrRow({required this.snr, required this.level});

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (level) {
      SnrLevel.significant => ('Significant (SNR > 3)', AppTheme.statusFault),
      SnrLevel.uncertain => ('Onzeker (1 ≤ SNR ≤ 3)', AppTheme.statusWarning),
      SnrLevel.notSignificant => ('Niet significant (SNR < 1)', AppTheme.statusOk),
      SnrLevel.invalid => ('Ongeldig', Colors.grey),
    };

    return Row(
      children: [
        const Expanded(
            child: Text('SNR  =  |ΔK| / d(ΔK)',
                style: TextStyle(fontSize: 13))),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: color, width: 1),
          ),
          child: Text(
            '${snr.toStringAsFixed(2)}  —  $label',
            style: TextStyle(
                fontSize: 12, fontWeight: FontWeight.bold, color: color),
          ),
        ),
      ],
    );
  }
}

class _CorrRow extends StatelessWidget {
  final String formula;
  final double value;
  final String unit;
  final bool exponential;

  const _CorrRow({
    required this.formula,
    required this.value,
    required this.unit,
    this.exponential = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = value.isNaN
        ? Colors.grey
        : value.abs() < (exponential ? 1e-4 : 1.0)
            ? AppTheme.statusOk
            : AppTheme.statusFault;
    final display = value.isNaN
        ? '—'
        : exponential
            ? value.toStringAsExponential(3)
            : value.toStringAsFixed(3);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(
            child: Text(formula,
                style: const TextStyle(fontSize: 11, fontFamily: 'monospace', color: Colors.black)),
          ),
          Text(
            '$display $unit',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              fontFamily: 'monospace',
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Uitlegkaart ──────────────────────────────────────────────────────────────

class _ExplanationCard extends StatelessWidget {
  const _ExplanationCard();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      color: const Color(0xFFF6F8FC),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Formules en beslislogica',
                style: theme.textTheme.titleSmall
                    ?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            _FormulaRow('K = ΔT / I²',
                'Thermische weerstandsindicator  [°C/A²]'),
            _FormulaRow('dK = K × √((dΔT/ΔT)² + (2·dI/I)²)',
                'Foutpropagatie eerste orde'),
            _FormulaRow('ΔK = K₁ − K₂', 'Verschil tussen twee metingen'),
            _FormulaRow('d(ΔK) = √(dK₁² + dK₂²)',
                'Gecombineerde onzekerheid'),
            _FormulaRow('SNR = |ΔK| / d(ΔK)',
                'Signaal-ruisverhouding'),
            const Divider(height: 16),
            _DecisionRow(
                color: AppTheme.statusFault,
                label: 'SNR > 3',
                text: 'Significante afwijking — mogelijke slechte verbinding'),
            _DecisionRow(
                color: AppTheme.statusWarning,
                label: '1 ≤ SNR ≤ 3',
                text: 'Onzeker — verhoog stroom of verbeter meetnauwkeurigheid'),
            _DecisionRow(
                color: AppTheme.statusOk,
                label: 'SNR < 1',
                text: 'Niet betrouwbaar — verschil valt binnen meetruis'),
          ],
        ),
      ),
    );
  }
}

class _FormulaRow extends StatelessWidget {
  final String formula;
  final String description;
  const _FormulaRow(this.formula, this.description);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(formula,
              style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.primaryDark)),
          Text(description,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
        ],
      ),
    );
  }
}

class _DecisionRow extends StatelessWidget {
  final Color color;
  final String label;
  final String text;
  const _DecisionRow(
      {required this.color, required this.label, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: color),
            ),
            child: Text(label,
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: color,
                    fontFamily: 'monospace')),
          ),
          const SizedBox(width: 8),
          Expanded(
              child: Text(text,
                  style: const TextStyle(fontSize: 12),
                  overflow: TextOverflow.visible)),
        ],
      ),
    );
  }
}

// ─── Gedeeld invoerveld ───────────────────────────────────────────────────────

class _NumberField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final ValueChanged<String>? onChanged;

  const _NumberField({
    required this.controller,
    required this.label,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(
          decimal: true, signed: true),
      decoration: InputDecoration(
        labelText: label,
        isDense: true,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        border: const OutlineInputBorder(),
      ),
      style: const TextStyle(fontSize: 13),
      onChanged: onChanged,
    );
  }
}

class _ImagePreviewCard extends StatefulWidget {
  final _ExtractedFlirData data;
  final File? imageFile;
  final Future<void> Function() onPickImage;
  final VoidCallback? onEdit;
  final bool isDragActive;
  final VoidCallback onDragEntered;
  final VoidCallback onDragExited;
  final ValueChanged<List<String>> onDropPaths;

  const _ImagePreviewCard({
    required this.data,
    required this.imageFile,
    required this.onPickImage,
    this.onEdit,
    required this.isDragActive,
    required this.onDragEntered,
    required this.onDragExited,
    required this.onDropPaths,
  });

  @override
  State<_ImagePreviewCard> createState() => _ImagePreviewCardState();
}

class _ImagePreviewCardState extends State<_ImagePreviewCard> {
  double _containerScale = 0.5;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.image_outlined, color: AppTheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'FLIR-opname in containerveld',
                    style: Theme.of(context)
                        .textTheme
                        .titleSmall
                        ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                ),
                if (widget.onEdit != null)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: OutlinedButton.icon(
                      onPressed: widget.onEdit,
                      icon: const Icon(Icons.tune, size: 18),
                      label: const Text('Bewerken'),
                    ),
                  ),
                FilledButton.icon(
                  onPressed: widget.onPickImage,
                  icon: const Icon(Icons.upload_file),
                  label: const Text('Kies afbeelding'),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(Icons.photo_size_select_small,
                    size: 16, color: Colors.grey),
                const SizedBox(width: 6),
                const Text('Grootte:', style: TextStyle(fontSize: 12)),
                Expanded(
                  child: Slider(
                    value: _containerScale,
                    min: 0.25,
                    max: 1.0,
                    divisions: 6,
                    label: '${(_containerScale * 100).round()}%',
                    onChanged: (v) => setState(() => _containerScale = v),
                  ),
                ),
                Text('${(_containerScale * 100).round()}%',
                    style: const TextStyle(fontSize: 12, fontFamily: 'monospace')),
              ],
            ),
            FractionallySizedBox(
              widthFactor: _containerScale,
              alignment: Alignment.centerLeft,
              child: DropTarget(
              onDragDone: (detail) => widget.onDropPaths(
                detail.files
                    .map((file) => file.path)
                    .where((path) => path.isNotEmpty)
                    .toList(),
              ),
              onDragEntered: (_) => widget.onDragEntered(),
              onDragExited: (_) => widget.onDragExited(),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: double.infinity,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: widget.isDragActive
                        ? AppTheme.primary
                        : AppTheme.primary.withValues(alpha: 0.18),
                    width: widget.isDragActive ? 2 : 1,
                  ),
                  color: widget.isDragActive
                      ? AppTheme.primary.withValues(alpha: 0.08)
                      : const Color(0xFFF5F7FB),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: AspectRatio(
                    aspectRatio: 4 / 3,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        if (widget.imageFile != null)
                          Image.file(
                            widget.imageFile!,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) =>
                                const _ImagePlaceholder(),
                          )
                        else
                          const _ImagePlaceholder(),
                        Positioned(
                          left: 16,
                          right: 16,
                          bottom: 16,
                          child: _UploadOverlay(isDragActive: widget.isDragActive),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            ),
            const SizedBox(height: 10),
            Text(
              widget.data.fileName,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            Text(
              'Pad: ${widget.data.imagePath}',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: Colors.grey.shade700),
            ),
            const SizedBox(height: 4),
            Text(
              'Bestandsgrootte: ${widget.data.fileSize}',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: Colors.grey.shade700),
            ),
          ],
        ),
      ),
    );
  }
}

class _ImagePlaceholder extends StatelessWidget {
  const _ImagePlaceholder();

  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: Alignment.center,
      color: const Color(0xFFF0F3F9),
      child: Text(
        'Nog geen afbeelding geladen',
        style: Theme.of(context)
            .textTheme
            .bodyMedium
            ?.copyWith(color: Colors.grey.shade700),
      ),
    );
  }
}

class _UploadOverlay extends StatelessWidget {
  final bool isDragActive;

  const _UploadOverlay({required this.isDragActive});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.58),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(
            isDragActive ? Icons.file_download_done : Icons.file_upload_outlined,
            color: Colors.white,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              isDragActive
                  ? 'Laat los om de afbeelding direct te laden'
                  : 'Sleep hier je afbeelding of klik op "Kies afbeelding"',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ImageLibraryCard extends StatelessWidget {
  final List<_PinnedImageEntry> pinnedImages;
  final List<_RecentImageEntry> recentImages;
  final String Function(DateTime value) formatRelativeTime;
  final ValueChanged<_PinnedImageEntry> onOpenPinned;
  final ValueChanged<_RecentImageEntry> onOpenRecent;
  final ValueChanged<_RecentImageEntry> onRemoveRecent;

  const _ImageLibraryCard({
    required this.pinnedImages,
    required this.recentImages,
    required this.formatRelativeTime,
    required this.onOpenPinned,
    required this.onOpenRecent,
    required this.onRemoveRecent,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Recente en vaste afbeeldingen',
              style: Theme.of(context)
                  .textTheme
                  .titleSmall
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: pinnedImages
                  .map(
                    (entry) => _LibraryTile(
                      title: entry.title,
                      subtitle: entry.subtitle,
                      badge: 'Vast',
                      actionLabel: 'Open',
                      onPressed: () => onOpenPinned(entry),
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 16),
            Text(
              'Recent geopend',
              style: Theme.of(context)
                  .textTheme
                  .titleSmall
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            if (recentImages.isEmpty)
              Text(
                'Nog geen recente afbeeldingen opgeslagen.',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
              )
            else
              ...recentImages.map(
                (entry) => _RecentImageRow(
                  title: entry.fileName,
                  subtitle: entry.subtitle,
                  meta: '${entry.path} • ${formatRelativeTime(entry.lastOpened)}',
                  onOpen: () => onOpenRecent(entry),
                  onRemove: () => onRemoveRecent(entry),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _LibraryTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final String badge;
  final String actionLabel;
  final VoidCallback onPressed;

  const _LibraryTile({
    required this.title,
    required this.subtitle,
    required this.badge,
    required this.actionLabel,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 240,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F9FD),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.primary.withValues(alpha: 0.14)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ChipLabel(text: badge, filled: true),
          const SizedBox(height: 10),
          Text(
            title,
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: Colors.grey.shade700),
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: onPressed,
            child: Text(actionLabel),
          ),
        ],
      ),
    );
  }
}

class _RecentImageRow extends StatelessWidget {
  final String title;
  final String subtitle;
  final String meta;
  final VoidCallback onOpen;
  final VoidCallback onRemove;

  const _RecentImageRow({
    required this.title,
    required this.subtitle,
    required this.meta,
    required this.onOpen,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onOpen,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        margin: const EdgeInsets.only(bottom: 4),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFFF7F9FD),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppTheme.primary.withValues(alpha: 0.10)),
        ),
        child: Row(
          children: [
            const Icon(Icons.image_outlined, size: 16, color: Colors.grey),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              subtitle,
              style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
            ),
            const SizedBox(width: 6),
            Text(
              meta,
              style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
            ),
            const SizedBox(width: 4),
            IconButton(
              icon: Icon(Icons.close, size: 14, color: Colors.grey.shade400),
              onPressed: onRemove,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
              tooltip: 'Verwijder',
            ),
          ],
        ),
      ),
    );
  }
}

class _FlirDataCard extends StatelessWidget {
  final _ExtractedFlirData data;

  const _FlirDataCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final allFields = [
      ('Camera', data.cameraModel),
      ('Opname', data.captureDate),
      ('Software', data.software),
      ('Bestand', data.fileSize),
      ('Resolutie', data.resolution),
      ('Palet', data.palette),
      ('Richting', data.direction),
      ('Min. schaal', data.minTemp != null
          ? '${data.minTemp!.toStringAsFixed(1)} °C'
          : 'Niet beschikbaar'),
      ('Max. schaal', data.maxTemp != null
          ? '${data.maxTemp!.toStringAsFixed(1)} °C'
          : 'Niet beschikbaar'),
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Opgehaalde FLIR-data',
              style: Theme.of(context)
                  .textTheme
                  .titleSmall
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Text(
              data.note,
              style: TextStyle(
                fontSize: 12,
                height: 1.45,
                color: Colors.grey.shade700,
              ),
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: allFields
                  .map((field) => _DataField(label: field.$1, value: field.$2))
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }
}

class _PointAssignmentPanel extends StatelessWidget {
  final _ExtractedFlirData data;
  final void Function(_ExtractedThermalPoint point, int? measurement)
      onAssignmentChanged;
  final int? Function(_ExtractedThermalPoint point)
      assignedMeasurementForPoint;

  const _PointAssignmentPanel({
    required this.data,
    required this.onAssignmentChanged,
    required this.assignedMeasurementForPoint,
  });

  @override
  Widget build(BuildContext context) {
    final allPoints = [...data.mappedPoints, ...data.extraPoints];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Meetpunten A en B',
              style: Theme.of(context)
                  .textTheme
                  .titleSmall
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            if (allPoints.isEmpty)
              Text(
                'Geen meetpunten beschikbaar voor deze afbeelding.',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
              )
            else
              ...allPoints.map(
                (point) => _PointRow(
                  point: point,
                  assignedMeasurement: assignedMeasurementForPoint(point),
                  onAssignmentChanged: (measurement) =>
                      onAssignmentChanged(point, measurement),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _DataField extends StatelessWidget {
  final String label;
  final String value;

  const _DataField({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 170,
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          isDense: true,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          border: const OutlineInputBorder(),
        ),
        child: Text(
          value,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}

class _PointRow extends StatelessWidget {
  final _ExtractedThermalPoint point;
  final int? assignedMeasurement;
  final ValueChanged<int?> onAssignmentChanged;

  const _PointRow({
    required this.point,
    required this.assignedMeasurement,
    required this.onAssignmentChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F9FD),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.primary.withValues(alpha: 0.12)),
      ),
      child: Row(
        children: [
          _ChipLabel(text: point.spot),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '${point.label}  ${point.temperature.toStringAsFixed(1)} °C',
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontFamily: 'monospace',
                fontSize: 13,
              ),
            ),
          ),
          SizedBox(
            width: 130,
            child: DropdownButtonFormField<int?>(
              initialValue: assignedMeasurement,
              decoration: const InputDecoration(
                isDense: true,
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                border: OutlineInputBorder(),
              ),
              items: [
                const DropdownMenuItem<int?>(
                  value: null,
                  child: Text('Geen', style: TextStyle(fontSize: 13)),
                ),
                for (int i = 1; i <= 6; i++)
                  DropdownMenuItem<int?>(
                    value: i,
                    child:
                        Text('Meting $i', style: const TextStyle(fontSize: 13)),
                  ),
              ],
              onChanged: onAssignmentChanged,
            ),
          ),
        ],
      ),
    );
  }
}


class _ChipLabel extends StatelessWidget {
  final String text;
  final bool filled;

  const _ChipLabel({
    required this.text,
    this.filled = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = filled ? AppTheme.primary : AppTheme.primaryDark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: filled ? color.withValues(alpha: 0.12) : Colors.white,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}

class _ExtractedFlirData {
  final String imagePath;
  final String fileName;
  final String fileSize;
  final String cameraModel;
  final String software;
  final String captureDate;
  final String resolution;
  final String palette;
  final String direction;
  final double? minTemp;
  final double? maxTemp;
  final String note;
  final List<_ExtractedThermalPoint> mappedPoints;
  final List<_ExtractedThermalPoint> extraPoints;

  const _ExtractedFlirData({
    required this.imagePath,
    required this.fileName,
    required this.fileSize,
    required this.cameraModel,
    required this.software,
    required this.captureDate,
    required this.resolution,
    required this.palette,
    required this.direction,
    required this.minTemp,
    required this.maxTemp,
    required this.note,
    required this.mappedPoints,
    required this.extraPoints,
  });

  _ExtractedFlirData copyWith({
    String? imagePath,
    String? fileName,
    String? fileSize,
    String? cameraModel,
    String? software,
    String? captureDate,
    String? resolution,
    String? palette,
    String? direction,
    double? minTemp,
    double? maxTemp,
    String? note,
    List<_ExtractedThermalPoint>? mappedPoints,
    List<_ExtractedThermalPoint>? extraPoints,
  }) {
    return _ExtractedFlirData(
      imagePath: imagePath ?? this.imagePath,
      fileName: fileName ?? this.fileName,
      fileSize: fileSize ?? this.fileSize,
      cameraModel: cameraModel ?? this.cameraModel,
      software: software ?? this.software,
      captureDate: captureDate ?? this.captureDate,
      resolution: resolution ?? this.resolution,
      palette: palette ?? this.palette,
      direction: direction ?? this.direction,
      minTemp: minTemp ?? this.minTemp,
      maxTemp: maxTemp ?? this.maxTemp,
      note: note ?? this.note,
      mappedPoints: mappedPoints ?? this.mappedPoints,
      extraPoints: extraPoints ?? this.extraPoints,
    );
  }
}

class _ExtractedThermalPoint {
  final String spot;
  final String label;
  final double temperature;

  const _ExtractedThermalPoint({
    required this.spot,
    required this.label,
    required this.temperature,
  });
}

class _PinnedImageEntry {
  final String title;
  final String subtitle;
  final String path;

  const _PinnedImageEntry({
    required this.title,
    required this.subtitle,
    required this.path,
  });
}

class _RecentImageEntry {
  final String path;
  final String fileName;
  final String subtitle;
  final DateTime lastOpened;

  const _RecentImageEntry({
    required this.path,
    required this.fileName,
    required this.subtitle,
    required this.lastOpened,
  });

  factory _RecentImageEntry.fromJson(Map<String, dynamic> json) {
    return _RecentImageEntry(
      path: json['path'] as String,
      fileName: json['fileName'] as String,
      subtitle: json['subtitle'] as String,
      lastOpened: DateTime.parse(json['lastOpened'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
        'path': path,
        'fileName': fileName,
        'subtitle': subtitle,
        'lastOpened': lastOpened.toIso8601String(),
      };
}

class _MeasurementBinding {
  final int id;
  final String label;
  final Color color;
  final String sourceLabel;
  final String? assignedSpot;
  final TextEditingController temperatureCtrl;
  final TextEditingController currentCtrl;
  final TextEditingController currentErrorCtrl;
  final TextEditingController temperatureErrorCtrl;

  const _MeasurementBinding({
    required this.id,
    required this.label,
    required this.color,
    required this.sourceLabel,
    required this.assignedSpot,
    required this.temperatureCtrl,
    required this.currentCtrl,
    required this.currentErrorCtrl,
    required this.temperatureErrorCtrl,
  });
}

class _ComparisonBlockResult {
  final String title;
  final ComparisonResult result;

  /// Extra ΔT-gecorrigeerde berekeningen (uit comparison_screen).
  final _DeltaTCorrected? deltaTCorr;

  const _ComparisonBlockResult({
    required this.title,
    required this.result,
    this.deltaTCorr,
  });
}

/// Extra berekeningen per meetpunt-paar, analoog aan comparison_screen.
class _DeltaTCorrected {
  /// (T_A − T_amb) − (I_A/I_B)² × (T_B − T_amb)
  final double dtCorrected;

  /// I_A²/ΔT_A − I_B²/ΔT_B
  final double deltaI2T;

  /// (I_A²/I_B²) − (ΔT_A/ΔT_B)
  final double deltaI2ratio;

  /// ΔT_A − (I_A²/I_B²) × ΔT_B
  final double deltaT2;

  /// (T_A−Tamb)/I_A² − (T_B−Tamb)/I_B²
  final double deltaTperI2;

  const _DeltaTCorrected({
    required this.dtCorrected,
    required this.deltaI2T,
    required this.deltaI2ratio,
    required this.deltaT2,
    required this.deltaTperI2,
  });
}

// ─── NPR 8040-1 beoordeling (methoden 1, 2, 3) ───────────────────────────────

/// Methode 1: maximale toelaatbare temperatuur van isolatiemateriaal geleider.
class _NprInsulationMaterial {
  final String name;
  final double tMax;
  final String example;
  const _NprInsulationMaterial(this.name, this.tMax, this.example);
}

const List<_NprInsulationMaterial> _nprInsulationMaterials = [
  _NprInsulationMaterial('PVC', 70, 'VD / H05VV-F / H07V-K'),
  _NprInsulationMaterial('QWPK', 75, 'H05BQ-F / H07BQ-F'),
  _NprInsulationMaterial('XLPE', 90, 'YMvK / XMvK'),
  _NprInsulationMaterial('EVA', 90, 'H05G-U / H07G-U'),
  _NprInsulationMaterial('Siliconenrubber', 180, 'NEN-EN-IEC 60204-1'),
];

/// Methode 2: temperatuurklasse elektrisch isolatiemateriaal component
/// (IEC 60085).
class _NprTempClass {
  final String letter;
  final double classTemp;
  final double tMax;
  const _NprTempClass(this.letter, this.classTemp, this.tMax);
}

const List<_NprTempClass> _nprTempClasses = [
  _NprTempClass('Y', 90, 105),
  _NprTempClass('A', 105, 120),
  _NprTempClass('E', 120, 130),
  _NprTempClass('B', 130, 155),
  _NprTempClass('F', 155, 180),
  _NprTempClass('H', 180, 200),
];

/// Methode 3: maximale toelaatbare temperatuurstijging van een onderdeel.
class _NprComponentPart {
  final String component;
  final String part;
  final double dTsMax;
  final String ref;
  const _NprComponentPart(this.component, this.part, this.dTsMax, this.ref);
}

const List<_NprComponentPart> _nprComponentParts = [
  _NprComponentPart('Aardlek(automaat)', 'Behuizing', 70, 'NEN-EN-IEC 61439'),
  _NprComponentPart('Installatieautomaat', 'Behuizing', 70, 'NEN-EN-IEC 61439'),
  _NprComponentPart('Schakelaar/scheider', 'Behuizing', 70, 'NEN-EN-IEC 61439'),
  _NprComponentPart('Motorbeveiliging spoel', 'Klasse A', 85,
      'NEN-EN-IEC 60947-4-1'),
  _NprComponentPart('Motorbeveiliging spoel', 'Klasse E', 100,
      'NEN-EN-IEC 60947-4-1'),
  _NprComponentPart('Motorbeveiliging spoel', 'Klasse B', 110,
      'NEN-EN-IEC 60947-4-1'),
  _NprComponentPart('Motorbeveiliging spoel', 'Klasse F', 135,
      'NEN-EN-IEC 60947-4-1'),
  _NprComponentPart('Motorbeveiliging spoel', 'Klasse H', 160,
      'NEN-EN-IEC 60947-4-1'),
  _NprComponentPart('Magneetschakelaar spoel', 'Klasse A', 85,
      'NEN-EN-IEC 61095'),
  _NprComponentPart('Magneetschakelaar spoel', 'Klasse E', 100,
      'NEN-EN-IEC 61095'),
  _NprComponentPart('Magneetschakelaar spoel', 'Klasse B', 110,
      'NEN-EN-IEC 61095'),
  _NprComponentPart('Magneetschakelaar spoel', 'Klasse F', 135,
      'NEN-EN-IEC 61095'),
  _NprComponentPart('Magneetschakelaar spoel', 'Klasse H', 160,
      'NEN-EN-IEC 61095'),
  _NprComponentPart('Bedieningsknop', 'Kunststof', 25, 'NEN-EN-IEC 60947-1'),
  _NprComponentPart(
      'Schakel-/verdeelinrichting', 'Kunststof', 40, 'NEN-EN-IEC 61439-1'),
];

class _NprAssessmentCard extends StatefulWidget {
  final List<_MeasurementBinding> bindings;
  final TextEditingController tambCtrl;

  const _NprAssessmentCard({
    required this.bindings,
    required this.tambCtrl,
  });

  @override
  State<_NprAssessmentCard> createState() => _NprAssessmentCardState();
}

class _NprAssessmentCardState extends State<_NprAssessmentCard> {
  _NprInsulationMaterial _material = _nprInsulationMaterials.first;
  bool _isOnInsulation = false; // -5K correctie volgens methode 1
  _NprTempClass _tempClass = _nprTempClasses[1]; // A
  _NprComponentPart _componentPart = _nprComponentParts.first;

  late final List<TextEditingController> _watched;

  @override
  void initState() {
    super.initState();
    _watched = [
      widget.tambCtrl,
      for (final b in widget.bindings) b.temperatureCtrl,
    ];
    for (final c in _watched) {
      c.addListener(_onChanged);
    }
  }

  @override
  void dispose() {
    for (final c in _watched) {
      c.removeListener(_onChanged);
    }
    super.dispose();
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  double? _parse(TextEditingController c) => double.tryParse(c.text);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tamb = _parse(widget.tambCtrl);

    return Card(
      color: const Color(0xFFF7FAF7),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Beoordeling volgens NPR 8040-1 (methoden 1, 2, 3)',
                style: theme.textTheme.titleSmall
                    ?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Text(
              'Vergelijkt de gemeten temperaturen per meting met de maximale '
              'toelaatbare waarden uit NPR 8040-1.',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
            ),
            const Divider(height: 20),

            // ── Methode 1 ──────────────────────────────────────────
            _buildMethodHeader(
              theme,
              'Methode 1',
              'Max. toelaatbare temperatuur van het isolatiemateriaal van een geleider',
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<_NprInsulationMaterial>(
                    initialValue: _material,
                    isDense: true,
                    decoration: const InputDecoration(
                      labelText: 'Isolatiemateriaal',
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                    items: _nprInsulationMaterials
                        .map((m) => DropdownMenuItem(
                              value: m,
                              child: Text(
                                '${m.name}  —  ${m.tMax.toStringAsFixed(0)} °C',
                                style: const TextStyle(fontSize: 13),
                              ),
                            ))
                        .toList(),
                    onChanged: (v) =>
                        setState(() => _material = v ?? _material),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Checkbox(
                  value: _isOnInsulation,
                  onChanged: (v) =>
                      setState(() => _isOnInsulation = v ?? false),
                  visualDensity: VisualDensity.compact,
                ),
                const Expanded(
                  child: Text(
                    'Meting op isolatie van draad/ader (−5 K op Tmax)',
                    style: TextStyle(fontSize: 12),
                  ),
                ),
              ],
            ),
            Text(
              'Voorbeeld: ${_material.example}',
              style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 8),
            _buildMeasurementsTable(
              evaluate: (tmc) {
                final tMax =
                    _isOnInsulation ? _material.tMax - 5 : _material.tMax;
                return _NprEvalRow(
                  measured: tmc,
                  limit: tMax,
                  limitLabel: 'Tmax',
                  unit: '°C',
                  exceeded: tmc > tMax,
                );
              },
            ),

            const Divider(height: 24),

            // ── Methode 2 ──────────────────────────────────────────
            _buildMethodHeader(
              theme,
              'Methode 2',
              'Max. toelaatbare temperatuur elektrisch isolatiemateriaal van een component (IEC 60085)',
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<_NprTempClass>(
              initialValue: _tempClass,
              isDense: true,
              decoration: const InputDecoration(
                labelText: 'Temperatuurklasse',
                isDense: true,
                border: OutlineInputBorder(),
              ),
              items: _nprTempClasses
                  .map((c) => DropdownMenuItem(
                        value: c,
                        child: Text(
                          'Klasse ${c.letter}  —  klasse ${c.classTemp.toStringAsFixed(0)} °C, Tmax ${c.tMax.toStringAsFixed(0)} °C',
                          style: const TextStyle(fontSize: 13),
                        ),
                      ))
                  .toList(),
              onChanged: (v) =>
                  setState(() => _tempClass = v ?? _tempClass),
            ),
            const SizedBox(height: 8),
            _buildMeasurementsTable(
              evaluate: (tmc) => _NprEvalRow(
                measured: tmc,
                limit: _tempClass.tMax,
                limitLabel: 'Tmax',
                unit: '°C',
                exceeded: tmc > _tempClass.tMax,
              ),
            ),

            const Divider(height: 24),

            // ── Methode 3 ──────────────────────────────────────────
            _buildMethodHeader(
              theme,
              'Methode 3',
              'Max. toelaatbare temperatuurstijging van een onderdeel (ΔTmc − Tamb)',
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<_NprComponentPart>(
              initialValue: _componentPart,
              isDense: true,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Component / onderdeel',
                isDense: true,
                border: OutlineInputBorder(),
              ),
              items: _nprComponentParts
                  .map((p) => DropdownMenuItem(
                        value: p,
                        child: Text(
                          '${p.component} — ${p.part} (ΔTsmax ${p.dTsMax.toStringAsFixed(0)} K)',
                          style: const TextStyle(fontSize: 13),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ))
                  .toList(),
              onChanged: (v) =>
                  setState(() => _componentPart = v ?? _componentPart),
            ),
            const SizedBox(height: 6),
            if (tamb == null || tamb < 5 || tamb > 40)
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.statusWarning.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: AppTheme.statusWarning),
                ),
                child: Text(
                  'Let op: methode 3 is alleen geldig wanneer 5 °C ≤ Tamb ≤ 40 °C (huidig: '
                  '${tamb == null ? '—' : '${tamb.toStringAsFixed(1)} °C'}).',
                  style: const TextStyle(fontSize: 11),
                ),
              ),
            const SizedBox(height: 8),
            _buildMeasurementsTable(
              evaluate: (tmc) {
                if (tamb == null) {
                  return const _NprEvalRow(
                    measured: double.nan,
                    limit: 0,
                    limitLabel: 'ΔTsmax',
                    unit: 'K',
                    exceeded: false,
                    invalid: true,
                    invalidReason: 'Tamb ontbreekt',
                  );
                }
                final deltaT = tmc - tamb;
                return _NprEvalRow(
                  measured: deltaT,
                  limit: _componentPart.dTsMax,
                  limitLabel: 'ΔTsmax',
                  unit: 'K',
                  exceeded: deltaT > _componentPart.dTsMax,
                );
              },
              valueLabel: 'ΔT',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMethodHeader(ThemeData theme, String title, String subtitle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title,
            style: theme.textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: AppTheme.primaryDark,
            )),
        Text(subtitle,
            style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
      ],
    );
  }

  Widget _buildMeasurementsTable({
    required _NprEvalRow Function(double tmc) evaluate,
    String valueLabel = 'T',
  }) {
    final rows = <Widget>[];
    for (final b in widget.bindings) {
      final tmc = _parse(b.temperatureCtrl);
      if (tmc == null) {
        rows.add(_NprResultLine(
          label: b.label,
          color: b.color,
          valueText: '—',
          statusText: 'Geen temperatuur',
          statusColor: Colors.grey,
        ));
        continue;
      }
      final eval = evaluate(tmc);
      if (eval.invalid) {
        rows.add(_NprResultLine(
          label: b.label,
          color: b.color,
          valueText: '—',
          statusText: eval.invalidReason ?? 'Ongeldig',
          statusColor: Colors.grey,
        ));
        continue;
      }
      rows.add(_NprResultLine(
        label: b.label,
        color: b.color,
        valueText:
            '$valueLabel = ${eval.measured.toStringAsFixed(1)} ${eval.unit}   |   ${eval.limitLabel} = ${eval.limit.toStringAsFixed(0)} ${eval.unit}',
        statusText: eval.exceeded
            ? 'Directe actie vereist'
            : 'Binnen grenswaarde',
        statusColor:
            eval.exceeded ? AppTheme.statusFault : AppTheme.statusOk,
      ));
    }
    return Column(children: rows);
  }
}

class _NprEvalRow {
  final double measured;
  final double limit;
  final String limitLabel;
  final String unit;
  final bool exceeded;
  final bool invalid;
  final String? invalidReason;
  const _NprEvalRow({
    required this.measured,
    required this.limit,
    required this.limitLabel,
    required this.unit,
    required this.exceeded,
    this.invalid = false,
    this.invalidReason,
  });
}

// ─── Kruis-vergelijking alle metingen ─────────────────────────────────────────

class _KEntry {
  final int id;
  final String label;
  final String sourceLabel;
  final Color color;
  final double current;
  final double temperature;
  final double deltaT;
  final double k;
  final double dk;
  final double? snr;
  final SnrLevel? snrLevel;

  const _KEntry({
    required this.id,
    required this.label,
    required this.sourceLabel,
    required this.color,
    required this.current,
    required this.temperature,
    required this.deltaT,
    required this.k,
    required this.dk,
    this.snr,
    this.snrLevel,
  });

  _KEntry copyWith({double? snr, SnrLevel? snrLevel}) => _KEntry(
        id: id,
        label: label,
        sourceLabel: sourceLabel,
        color: color,
        current: current,
        temperature: temperature,
        deltaT: deltaT,
        k: k,
        dk: dk,
        snr: snr ?? this.snr,
        snrLevel: snrLevel ?? this.snrLevel,
      );
}

class _CrossComparisonResult {
  final List<_KEntry> entries; // sorted highest K first
  final _KEntry kRef; // lowest K (reference)
  final double tamb;

  const _CrossComparisonResult({
    required this.entries,
    required this.kRef,
    required this.tamb,
  });
}

class _CrossComparisonCard extends StatelessWidget {
  final _CrossComparisonResult result;

  const _CrossComparisonCard({required this.result});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final entries = result.entries;
    final kMax = entries.first.k;
    final kRef = result.kRef;

    // Determine overall verdict
    final worstLevel = entries.fold<SnrLevel>(
      SnrLevel.notSignificant,
      (prev, e) {
        final lv = e.snrLevel ?? SnrLevel.notSignificant;
        if (lv == SnrLevel.significant) return SnrLevel.significant;
        if (prev == SnrLevel.significant) return SnrLevel.significant;
        if (lv == SnrLevel.uncertain) return SnrLevel.uncertain;
        return prev;
      },
    );

    final (headerColor, headerBg, headerIcon, verdictText) = switch (worstLevel) {
      SnrLevel.significant => (
          AppTheme.statusFault,
          AppTheme.statusFault.withValues(alpha: 0.08),
          Icons.warning_amber_rounded,
          'Eén of meer metingen wijken significant af van de referentie. '
              'Mogelijke slechte verbinding aanwezig.',
        ),
      SnrLevel.uncertain => (
          AppTheme.statusWarning,
          AppTheme.statusWarning.withValues(alpha: 0.08),
          Icons.help_outline_rounded,
          'Eén of meer metingen wijken mogelijk af van de referentie. '
              'Aanvullend onderzoek aanbevolen.',
        ),
      _ => (
          AppTheme.statusOk,
          AppTheme.statusOk.withValues(alpha: 0.08),
          Icons.check_circle_outline_rounded,
          'Geen significante afwijkingen tussen de metingen gevonden.',
        ),
    };

    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: headerColor, width: 1.5),
      ),
      color: headerBg,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Icon(headerIcon, color: headerColor, size: 22),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Vergelijking alle metingen — K-rangschikking',
                    style: theme.textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Referentie (laagste K): ${kRef.label}  '
              '(K = ${kRef.k.toStringAsExponential(3)} °C/A²). '
              'Hogere K-waarden duiden op hogere thermische weerstand.',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
            ),
            const SizedBox(height: 12),

            // Table header
            _KTableRow.header(),
            const Divider(height: 8),

            // Rows
            for (final e in entries) _KTableRow(entry: e, kMax: kMax, kRef: kRef),

            const Divider(height: 20),

            // Verdict
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(headerIcon, color: headerColor, size: 16),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    verdictText,
                    style: TextStyle(
                      fontSize: 12,
                      color: headerColor,
                      fontWeight: FontWeight.w600,
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
}

class _KTableRow extends StatelessWidget {
  final _KEntry? entry;
  final double kMax;
  final _KEntry? kRef;
  final bool isHeader;

  const _KTableRow({
    required _KEntry this.entry,
    required this.kMax,
    required this.kRef,
  }) : isHeader = false;

  const _KTableRow.header()
      : entry = null,
        kMax = 1,
        kRef = null,
        isHeader = true;

  @override
  Widget build(BuildContext context) {
    if (isHeader) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          children: [
            SizedBox(
              width: 70,
              child: Text('Meting',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey.shade600)),
            ),
            const SizedBox(width: 6),
            SizedBox(
              width: 90,
              child: Text('K (°C/A²)',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey.shade600,
                      fontFamily: 'monospace')),
            ),
            const SizedBox(width: 6),
            SizedBox(
              width: 50,
              child: Text('K/K_ref',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey.shade600)),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text('SNR vs ref.',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey.shade600)),
            ),
          ],
        ),
      );
    }

    final e = entry!;
    final isRef = kRef != null && e.id == kRef!.id;
    final ratio = kRef != null && kRef!.k > 1e-20 ? e.k / kRef!.k : 1.0;
    final snr = e.snr;
    final level = e.snrLevel ?? SnrLevel.notSignificant;
    final barFraction = kMax > 1e-20 ? (e.k / kMax).clamp(0.0, 1.0) : 0.0;

    final (levelColor, levelLabel) = switch (level) {
      SnrLevel.significant => (AppTheme.statusFault, 'Significant'),
      SnrLevel.uncertain => (AppTheme.statusWarning, 'Onzeker'),
      SnrLevel.notSignificant =>
        isRef ? (AppTheme.statusOk, 'Referentie') : (AppTheme.statusOk, 'OK'),
      SnrLevel.invalid => (Colors.grey, '—'),
    };

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SizedBox(
                width: 70,
                child: Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration:
                          BoxDecoration(color: e.color, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 4),
                    Text(e.label,
                        style: const TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              SizedBox(
                width: 90,
                child: Text(
                  e.k.toStringAsExponential(3),
                  style: const TextStyle(
                      fontSize: 12,
                      fontFamily: 'monospace',
                      fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(width: 6),
              SizedBox(
                width: 50,
                child: Text(
                  isRef ? '1.00×' : '${ratio.toStringAsFixed(2)}×',
                  style: TextStyle(
                    fontSize: 12,
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.w600,
                    color: ratio > 2 ? AppTheme.statusFault : null,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: levelColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: levelColor, width: 0.8),
                  ),
                  child: Text(
                    snr != null && !isRef
                        ? '${snr.toStringAsFixed(1)}  —  $levelLabel'
                        : levelLabel,
                    style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: levelColor),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 3),
          // K bar
          LayoutBuilder(
            builder: (_, constraints) => Stack(
              children: [
                Container(
                  height: 4,
                  width: constraints.maxWidth,
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Container(
                  height: 4,
                  width: constraints.maxWidth * barFraction,
                  decoration: BoxDecoration(
                    color: levelColor.withValues(alpha: 0.7),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 1),
        ],
      ),
    );
  }
}

class _NprResultLine extends StatelessWidget {
  final String label;
  final Color color;
  final String valueText;
  final String statusText;
  final Color statusColor;

  const _NprResultLine({
    required this.label,
    required this.color,
    required this.valueText,
    required this.statusText,
    required this.statusColor,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration:
                BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 62,
            child: Text(label,
                style: const TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w600)),
          ),
          Expanded(
            child: Text(valueText,
                style: const TextStyle(
                    fontSize: 11,
                    fontFamily: 'monospace',
                    color: Colors.black)),
          ),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: statusColor),
            ),
            child: Text(statusText,
                style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: statusColor)),
          ),
        ],
      ),
    );
  }
}
