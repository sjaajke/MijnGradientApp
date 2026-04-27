import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

// ── Invoermodel ───────────────────────────────────────────────────────────────

class NprMeasurementData {
  final String label;
  final Color color;
  final double? temperature; // null = veld leeg / ongeldig

  const NprMeasurementData({
    required this.label,
    required this.color,
    required this.temperature,
  });
}

// ── Scherm ────────────────────────────────────────────────────────────────────

class NprAssessmentScreen extends StatefulWidget {
  final List<NprMeasurementData> measurements;
  final double? tamb;

  const NprAssessmentScreen({
    super.key,
    required this.measurements,
    required this.tamb,
  });

  @override
  State<NprAssessmentScreen> createState() => _NprAssessmentScreenState();
}

class _NprAssessmentScreenState extends State<NprAssessmentScreen> {
  _NprInsulationMaterial _material = _nprInsulationMaterials.first;
  bool _isOnInsulation = false;
  _NprTempClass _tempClass = _nprTempClasses[1]; // A
  _NprComponentPart _componentPart = _nprComponentParts.first;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tamb = widget.tamb;

    return Scaffold(
      appBar: AppBar(
        title: const Text('NPR 8040-1 — methoden 1, 2 en 3'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          // ── Toelichting ──────────────────────────────────────────────────
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
                Text(
                  'Beoordeling volgens NPR 8040-1',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Vergelijkt de gemeten temperaturen per meting met de maximale '
                  'toelaatbare waarden uit NPR 8040-1.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.white.withValues(alpha: 0.88),
                    height: 1.4,
                  ),
                ),
                if (tamb != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    'Tamb = ${tamb.toStringAsFixed(1)} °C',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                      fontFamily: 'monospace',
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ── Methode 1 ─────────────────────────────────────────────────────
          _SectionCard(
            title: 'Methode 1',
            subtitle:
                'Max. toelaatbare temperatuur van het isolatiemateriaal van een geleider',
            color: AppTheme.chartA,
            children: [
              DropdownButtonFormField<_NprInsulationMaterial>(
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
                onChanged: (v) => setState(() => _material = v ?? _material),
              ),
              const SizedBox(height: 8),
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
            ],
          ),

          // ── Methode 2 ─────────────────────────────────────────────────────
          _SectionCard(
            title: 'Methode 2',
            subtitle:
                'Max. toelaatbare temperatuur elektrisch isolatiemateriaal van een component (IEC 60085)',
            color: AppTheme.chartB,
            children: [
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
                onChanged: (v) => setState(() => _tempClass = v ?? _tempClass),
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
            ],
          ),

          // ── Methode 3 ─────────────────────────────────────────────────────
          _SectionCard(
            title: 'Methode 3',
            subtitle:
                'Max. toelaatbare temperatuurstijging van een onderdeel (ΔTmc − Tamb)',
            color: AppTheme.chartGradient,
            children: [
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
                    'Let op: methode 3 is alleen geldig wanneer 5 °C ≤ Tamb ≤ 40 °C '
                    '(huidig: ${tamb == null ? '—' : '${tamb.toStringAsFixed(1)} °C'}).',
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
        ],
      ),
    );
  }

  Widget _buildMeasurementsTable({
    required _NprEvalRow Function(double tmc) evaluate,
    String valueLabel = 'T',
  }) {
    final rows = <Widget>[];
    for (final m in widget.measurements) {
      if (m.temperature == null) {
        rows.add(_NprResultLine(
          label: m.label,
          color: m.color,
          valueText: '—',
          statusText: 'Geen temperatuur',
          statusColor: Colors.grey,
        ));
        continue;
      }
      final eval = evaluate(m.temperature!);
      if (eval.invalid) {
        rows.add(_NprResultLine(
          label: m.label,
          color: m.color,
          valueText: '—',
          statusText: eval.invalidReason ?? 'Ongeldig',
          statusColor: Colors.grey,
        ));
        continue;
      }
      rows.add(_NprResultLine(
        label: m.label,
        color: m.color,
        valueText:
            '$valueLabel = ${eval.measured.toStringAsFixed(1)} ${eval.unit}   |   ${eval.limitLabel} = ${eval.limit.toStringAsFixed(0)} ${eval.unit}',
        statusText:
            eval.exceeded ? 'Directe actie vereist' : 'Binnen grenswaarde',
        statusColor: eval.exceeded ? AppTheme.statusFault : AppTheme.statusOk,
      ));
    }
    return Column(children: rows);
  }
}

// ── Sectiekaart ───────────────────────────────────────────────────────────────

class _SectionCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final Color color;
  final List<Widget> children;

  const _SectionCard({
    required this.title,
    required this.subtitle,
    required this.color,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 14,
                  backgroundColor: color.withValues(alpha: 0.15),
                  child: Text(
                    title.split(' ').last,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          style: theme.textTheme.labelLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: AppTheme.primaryDark,
                          )),
                      Text(subtitle,
                          style: TextStyle(
                              fontSize: 11, color: Colors.grey.shade700)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }
}

// ── NPR-datamodellen ──────────────────────────────────────────────────────────

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
  _NprComponentPart('Motorbeveiliging spoel', 'Klasse A', 85, 'NEN-EN-IEC 60947-4-1'),
  _NprComponentPart('Motorbeveiliging spoel', 'Klasse E', 100, 'NEN-EN-IEC 60947-4-1'),
  _NprComponentPart('Motorbeveiliging spoel', 'Klasse B', 110, 'NEN-EN-IEC 60947-4-1'),
  _NprComponentPart('Motorbeveiliging spoel', 'Klasse F', 135, 'NEN-EN-IEC 60947-4-1'),
  _NprComponentPart('Motorbeveiliging spoel', 'Klasse H', 160, 'NEN-EN-IEC 60947-4-1'),
  _NprComponentPart('Magneetschakelaar spoel', 'Klasse A', 85, 'NEN-EN-IEC 61095'),
  _NprComponentPart('Magneetschakelaar spoel', 'Klasse E', 100, 'NEN-EN-IEC 61095'),
  _NprComponentPart('Magneetschakelaar spoel', 'Klasse B', 110, 'NEN-EN-IEC 61095'),
  _NprComponentPart('Magneetschakelaar spoel', 'Klasse F', 135, 'NEN-EN-IEC 61095'),
  _NprComponentPart('Magneetschakelaar spoel', 'Klasse H', 160, 'NEN-EN-IEC 61095'),
  _NprComponentPart('Bedieningsknop', 'Kunststof', 25, 'NEN-EN-IEC 60947-1'),
  _NprComponentPart('Schakel-/verdeelinrichting', 'Kunststof', 40, 'NEN-EN-IEC 61439-1'),
];

// ── Hulpklassen ───────────────────────────────────────────────────────────────

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
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
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
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
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
