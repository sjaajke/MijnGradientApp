import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:uuid/uuid.dart';
import '../../core/constants/app_constants.dart';
import '../../core/di/injection_container.dart';
import '../../domain/entities/conductor.dart';
import '../../domain/usecases/import_csv_usecase.dart';

/// Screen for entering or importing conductor data.
/// Returns an [InputResult] via [Navigator.pop] when confirmed.
///
/// Pass [existingConductor] to pre-fill all fields for editing.
class InputScreen extends StatefulWidget {
  final String? existingId;
  final String? labelSuffix; // e.g. "A" or "B"
  final Conductor? existingConductor;
  final SmoothingMethod? existingSmoothing;
  final double? existingHotspotFactor;
  final int? existingMaWindow;

  const InputScreen({
    super.key,
    this.existingId,
    this.labelSuffix,
    this.existingConductor,
    this.existingSmoothing,
    this.existingHotspotFactor,
    this.existingMaWindow,
  });

  @override
  State<InputScreen> createState() => _InputScreenState();
}

class _InputScreenState extends State<InputScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tab;

  // ── Common fields ─────────────────────────────────────────────────────────
  final _nameCtrl = TextEditingController();
  final _currentCtrl = TextEditingController(text: '100');
  SmoothingMethod _smoothing = SmoothingMethod.none;
  double _hotspotFactor = AppConstants.defaultHotspotFactor;
  int _maWindow = AppConstants.defaultMovingAverageWindow;

  // ── Manual entry ──────────────────────────────────────────────────────────
  final List<_Row> _rows = [
    _Row(pos: TextEditingController(), temp: TextEditingController()),
    _Row(pos: TextEditingController(), temp: TextEditingController()),
    _Row(pos: TextEditingController(), temp: TextEditingController()),
  ];

  // ── CSV import ────────────────────────────────────────────────────────────
  String? _csvPath;
  String? _csvError;
  bool _csvLoading = false;

  final _formKey = GlobalKey<FormState>();
  final _uuid = const Uuid();

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);

    final existing = widget.existingConductor;
    if (existing != null) {
      // Pre-fill from existing conductor
      _nameCtrl.text = existing.name;
      _currentCtrl.text = existing.current.toString();
      _smoothing = widget.existingSmoothing ?? SmoothingMethod.none;
      _hotspotFactor = widget.existingHotspotFactor ?? AppConstants.defaultHotspotFactor;
      _maWindow = widget.existingMaWindow ?? AppConstants.defaultMovingAverageWindow;

      // Populate manual entry rows
      _rows.clear();
      for (int i = 0; i < existing.positions.length; i++) {
        _rows.add(_Row(
          pos: TextEditingController(text: existing.positions[i].toString()),
          temp: TextEditingController(text: existing.temperatures[i].toString()),
        ));
      }
    } else {
      _nameCtrl.text = 'Conductor ${widget.labelSuffix ?? ''}';
    }
  }

  @override
  void dispose() {
    _tab.dispose();
    _nameCtrl.dispose();
    _currentCtrl.dispose();
    for (final r in _rows) {
      r.pos.dispose();
      r.temp.dispose();
    }
    super.dispose();
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final suffix = widget.labelSuffix != null ? ' ${widget.labelSuffix}' : '';
    final isEditing = widget.existingConductor != null;
    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Edit Conductor$suffix' : 'Configure Conductor$suffix'),
        bottom: TabBar(
          controller: _tab,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(icon: Icon(Icons.edit), text: 'Manual'),
            Tab(icon: Icon(Icons.upload_file), text: 'Import CSV'),
          ],
        ),
      ),
      body: Form(
        key: _formKey,
        child: Column(
          children: [
            _buildCommonFields(),
            Expanded(
              child: TabBarView(
                controller: _tab,
                children: [
                  _buildManualTab(),
                  _buildCsvTab(),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomBar(),
    );
  }

  Widget _buildCommonFields() {
    return Container(
      color: Colors.grey.shade50,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                flex: 3,
                child: TextFormField(
                  controller: _nameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Conductor name',
                    prefixIcon: Icon(Icons.label_outline),
                  ),
                  validator: (v) =>
                      v == null || v.trim().isEmpty ? 'Required' : null,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: TextFormField(
                  controller: _currentCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Current (A)',
                    prefixIcon: Icon(Icons.bolt),
                  ),
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(
                        RegExp(r'^\d+\.?\d*'))
                  ],
                  validator: (v) {
                    final n = double.tryParse(v ?? '');
                    if (n == null || n <= 0) {
                      return 'Enter valid current';
                    }
                    return null;
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _buildAnalysisSettings(),
        ],
      ),
    );
  }

  Widget _buildAnalysisSettings() {
    return ExpansionTile(
      tilePadding: EdgeInsets.zero,
      title: const Text('Analysis settings',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
      childrenPadding: const EdgeInsets.only(bottom: 8),
      children: [
        Row(
          children: [
            const Text('Smoothing:', style: TextStyle(fontSize: 13)),
            const SizedBox(width: 8),
            Expanded(
              child: DropdownButtonFormField<SmoothingMethod>(
                initialValue: _smoothing,
                isExpanded: true,
                decoration: const InputDecoration(
                  isDense: true,
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                ),
                items: SmoothingMethod.values
                    .map((m) => DropdownMenuItem(
                          value: m,
                          child: Text(m.label,
                              style: const TextStyle(fontSize: 13)),
                        ))
                    .toList(),
                onChanged: (v) => setState(() => _smoothing = v!),
              ),
            ),
          ],
        ),
        if (_smoothing == SmoothingMethod.movingAverage) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              const Text('Window:', style: TextStyle(fontSize: 13)),
              Expanded(
                child: Slider(
                  value: _maWindow.toDouble(),
                  min: 3,
                  max: 21,
                  divisions: 9,
                  label: '$_maWindow',
                  onChanged: (v) =>
                      setState(() => _maWindow = v.round()),
                ),
              ),
              Text('$_maWindow pts',
                  style: const TextStyle(fontSize: 13)),
            ],
          ),
        ],
        const SizedBox(height: 4),
        Row(
          children: [
            const Text('Hotspot factor:', style: TextStyle(fontSize: 13)),
            Expanded(
              child: Slider(
                value: _hotspotFactor,
                min: 1.2,
                max: 5.0,
                divisions: 19,
                label: _hotspotFactor.toStringAsFixed(1),
                onChanged: (v) =>
                    setState(() => _hotspotFactor = v),
              ),
            ),
            Text('${_hotspotFactor.toStringAsFixed(1)}×',
                style: const TextStyle(fontSize: 13)),
          ],
        ),
      ],
    );
  }

  // ── Manual tab ────────────────────────────────────────────────────────────

  Widget _buildManualTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
          child: Row(
            children: [
              const Expanded(
                flex: 2,
                child: Text('Position (m)',
                    style: TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w600)),
              ),
              const SizedBox(width: 8),
              const Expanded(
                flex: 2,
                child: Text('Temperature (°C)',
                    style: TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w600)),
              ),
              const SizedBox(width: 36),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: _rows.length,
            itemBuilder: (_, i) => _buildRowItem(i),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(12),
          child: OutlinedButton.icon(
            onPressed: _addRow,
            icon: const Icon(Icons.add),
            label: const Text('Add point'),
          ),
        ),
      ],
    );
  }

  Widget _buildRowItem(int i) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: TextFormField(
              controller: _rows[i].pos,
              decoration: InputDecoration(
                hintText: '0.${i}0',
                isDense: true,
              ),
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(
                    RegExp(r'^-?\d*\.?\d*'))
              ],
              validator: (v) =>
                  double.tryParse(v ?? '') == null ? 'x' : null,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 2,
            child: TextFormField(
              controller: _rows[i].temp,
              decoration: InputDecoration(
                hintText: '${25 + i}.0',
                isDense: true,
              ),
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(
                    RegExp(r'^-?\d*\.?\d*'))
              ],
              validator: (v) =>
                  double.tryParse(v ?? '') == null ? 'x' : null,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 18),
            onPressed: _rows.length > 3
                ? () => setState(() => _rows.removeAt(i))
                : null,
          ),
        ],
      ),
    );
  }

  void _addRow() => setState(() {
        _rows.add(
            _Row(pos: TextEditingController(), temp: TextEditingController()));
      });

  // ── CSV tab ───────────────────────────────────────────────────────────────

  Widget _buildCsvTab() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Expected CSV columns:\n  Column 1: position (m)\n  Column 2: temperature (°C)\n\nDelimiters: comma, semicolon or tab.\nHeader row is auto-detected.',
            style: TextStyle(fontSize: 13, color: Colors.grey),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: _pickCsv,
            icon: const Icon(Icons.folder_open),
            label: const Text('Choose CSV file'),
          ),
          if (_csvPath != null) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.insert_drive_file,
                    color: Colors.green.shade700, size: 18),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    _csvPath!.split('/').last,
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w500),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
          if (_csvError != null) ...[
            const SizedBox(height: 12),
            Text(
              _csvError!,
              style: TextStyle(
                  color: Theme.of(context).colorScheme.error,
                  fontSize: 13),
            ),
          ],
          if (_csvLoading)
            const Padding(
              padding: EdgeInsets.only(top: 16),
              child: Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }

  Future<void> _pickCsv() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv', 'txt'],
    );
    if (result != null && result.files.single.path != null) {
      setState(() {
        _csvPath = result.files.single.path;
        _csvError = null;
      });
    }
  }

  // ── Bottom bar ────────────────────────────────────────────────────────────

  Widget _buildBottomBar() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: FilledButton.icon(
          onPressed: _onConfirm,
          icon: const Icon(Icons.analytics),
          label: const Text('Confirm & Analyse'),
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(50),
          ),
        ),
      ),
    );
  }

  Future<void> _onConfirm() async {
    if (!_formKey.currentState!.validate()) return;

    final id = widget.existingId ?? _uuid.v4();
    final name = _nameCtrl.text.trim();
    final current = double.parse(_currentCtrl.text);
    Conductor? conductor;

    if (_tab.index == 0) {
      // Manual entry
      final positions = <double>[];
      final temps = <double>[];
      for (final row in _rows) {
        final p = double.tryParse(row.pos.text);
        final t = double.tryParse(row.temp.text);
        if (p != null && t != null) {
          positions.add(p);
          temps.add(t);
        }
      }
      if (positions.length < 3) {
        _showError('Enter at least 3 valid data points.');
        return;
      }
      conductor = Conductor(
        id: id,
        name: name,
        positions: positions,
        temperatures: temps,
        current: current,
      );
    } else {
      // CSV import
      if (_csvPath == null) {
        _showError('Please select a CSV file.');
        return;
      }
      setState(() => _csvLoading = true);
      try {
        conductor = await sl<ImportCsvUseCase>().call(
          filePath: _csvPath!,
          conductorName: name,
          current: current,
          conductorId: id,
        );
      } catch (e) {
        setState(() {
          _csvError = e.toString();
          _csvLoading = false;
        });
        return;
      }
      setState(() => _csvLoading = false);
    }

    if (!mounted) return;
    Navigator.pop(
      context,
      _InputResult(
        conductor: conductor,
        smoothingMethod: _smoothing,
        movingAverageWindow: _maWindow,
        hotspotFactor: _hotspotFactor,
      ),
    );
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }
}

class _Row {
  final TextEditingController pos;
  final TextEditingController temp;
  _Row({required this.pos, required this.temp});
}

/// Return value from [InputScreen].
class _InputResult {
  final Conductor conductor;
  final SmoothingMethod smoothingMethod;
  final int movingAverageWindow;
  final double hotspotFactor;

  _InputResult({
    required this.conductor,
    required this.smoothingMethod,
    required this.movingAverageWindow,
    required this.hotspotFactor,
  });
}

// Public export of the result type so callers can cast properly.
typedef InputResult = _InputResult;
