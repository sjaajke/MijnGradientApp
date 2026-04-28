import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../widgets/analysis_top_nav.dart';
import 'npr_assessment_screen.dart';

// ── Invoermodel ───────────────────────────────────────────────────────────────

class RegressionMeasurementData {
  final String label;
  final Color color;
  final double? temperature;
  final double? current;

  const RegressionMeasurementData({
    required this.label,
    required this.color,
    required this.temperature,
    required this.current,
  });
}

// ── Regressieresultaat ────────────────────────────────────────────────────────

class _SeriesResult {
  final String name;
  final Color color;
  final List<double?> temps; // ruwe of genormaliseerde T [3 waarden]
  final double? slope; // m  [°C/positie]
  final double? intercept; // b bij x=0
  final double? r2; // fit-kwaliteit 0–1
  final double? tMiddleResidual; // afwijking middelpunt van lineaire fit
  final bool normalized;

  const _SeriesResult({
    required this.name,
    required this.color,
    required this.temps,
    required this.slope,
    required this.intercept,
    required this.r2,
    required this.tMiddleResidual,
    required this.normalized,
  });
}

enum _DiagnosisStatus { ok, currentImbalance, deviation }

class _DiagnosisResult {
  final _DiagnosisStatus status;
  final String label;
  final String subtype; // alleen bij deviation
  final double deltaMSlope;
  final double deltaMPercent;
  final String reliabilityNote;

  const _DiagnosisResult({
    required this.status,
    required this.label,
    required this.subtype,
    required this.deltaMSlope,
    required this.deltaMPercent,
    required this.reliabilityNote,
  });
}

// ── Scherm ────────────────────────────────────────────────────────────────────

class RegressionAnalysisScreen extends StatefulWidget {
  /// Lijst van 6 metingen (index 0–5 = meting 1–6).
  /// Reeks A = indices 0, 2, 4  (meting 1, 3, 5)
  /// Reeks B = indices 1, 3, 5  (meting 2, 4, 6)
  final List<RegressionMeasurementData> measurements;
  final double? tamb;

  const RegressionAnalysisScreen({
    super.key,
    required this.measurements,
    required this.tamb,
  });

  @override
  State<RegressionAnalysisScreen> createState() =>
      _RegressionAnalysisScreenState();
}

class _RegressionAnalysisScreenState extends State<RegressionAnalysisScreen> {
  bool _normalize = true;
  final _iRefCtrl = TextEditingController();
  final _tolCtrl = TextEditingController(text: '0.2');

  void _openTopNavScreen(AnalysisTopNavScreen screen) {
    switch (screen) {
      case AnalysisTopNavScreen.regression:
        return;
      case AnalysisTopNavScreen.thermal:
        Navigator.of(context).pop();
        return;
      case AnalysisTopNavScreen.npr:
        final measurements = widget.measurements
            .map(
              (m) => NprMeasurementData(
                label: m.label,
                color: m.color,
                temperature: m.temperature,
                current: m.current,
              ),
            )
            .toList();
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => NprAssessmentScreen(
              measurements: measurements,
              tamb: widget.tamb,
            ),
          ),
        );
    }
  }

  @override
  void initState() {
    super.initState();
    // Stel I_ref in als gemiddelde van beschikbare stromen
    final currents = widget.measurements
        .map((m) => m.current)
        .whereType<double>()
        .toList();
    if (currents.isNotEmpty) {
      final avg = currents.reduce((a, b) => a + b) / currents.length;
      _iRefCtrl.text = avg.toStringAsFixed(1);
    }
  }

  @override
  void dispose() {
    _iRefCtrl.dispose();
    _tolCtrl.dispose();
    super.dispose();
  }

  // ── Bereken ─────────────────────────────────────────────────────────────────

  double? _parse(String text) => double.tryParse(text);

  /// Lineaire regressie voor 3 equidistante punten (x = 1, 2, 3).
  /// Geeft (slope, intercept_x0, R²) of null als te weinig data.
  ({double slope, double intercept, double r2, double middleResidual})?
  _regression(double t1, double t2, double t3) {
    // OLS: x = [1,2,3], x̄ = 2
    final yBar = (t1 + t2 + t3) / 3.0;
    final slope = (t3 - t1) / 2.0; // = Σ(xi-x̄)(yi-ȳ) / Σ(xi-x̄)²
    final intercept = yBar - slope * 2.0; // intercept bij x = 0

    final pred1 = intercept + slope * 1;
    final pred2 = intercept + slope * 2;
    final pred3 = intercept + slope * 3;

    final ssTot =
        (t1 - yBar) * (t1 - yBar) +
        (t2 - yBar) * (t2 - yBar) +
        (t3 - yBar) * (t3 - yBar);
    final ssRes =
        (t1 - pred1) * (t1 - pred1) +
        (t2 - pred2) * (t2 - pred2) +
        (t3 - pred3) * (t3 - pred3);

    final r2 = ssTot < 1e-10 ? 1.0 : 1.0 - ssRes / ssTot;
    final middleResidual = t2 - pred2;

    return (
      slope: slope,
      intercept: intercept,
      r2: r2.clamp(0.0, 1.0),
      middleResidual: middleResidual,
    );
  }

  _SeriesResult _buildSeries(
    String name,
    Color color,
    List<RegressionMeasurementData> points, // 3 punten
    double? tamb,
    double? iRef,
    bool normalize,
  ) {
    List<double?> temps = points.map((p) => p.temperature).toList();

    bool normalized = false;
    if (normalize && tamb != null && iRef != null && iRef > 0) {
      temps = points.map((p) {
        if (p.temperature == null) return null;
        final dT = p.temperature! - tamb;
        final i = p.current;
        if (i == null || i <= 0) {
          return p.temperature; // geen stroom → ongewijzigd
        }
        final dTNorm = dT * (iRef / i) * (iRef / i);
        return tamb + dTNorm;
      }).toList();
      normalized = true;
    }

    final t1 = temps[0], t2 = temps[1], t3 = temps[2];
    if (t1 == null || t2 == null || t3 == null) {
      return _SeriesResult(
        name: name,
        color: color,
        temps: temps,
        slope: null,
        intercept: null,
        r2: null,
        tMiddleResidual: null,
        normalized: normalized,
      );
    }

    final reg = _regression(t1, t2, t3);
    return _SeriesResult(
      name: name,
      color: color,
      temps: temps,
      slope: reg?.slope,
      intercept: reg?.intercept,
      r2: reg?.r2,
      tMiddleResidual: reg?.middleResidual,
      normalized: normalized,
    );
  }

  _DiagnosisResult _diagnose(
    _SeriesResult a,
    _SeriesResult b,
    double tolerance,
  ) {
    final mA = a.slope, mB = b.slope;

    if (mA == null || mB == null) {
      return const _DiagnosisResult(
        status: _DiagnosisStatus.ok,
        label: 'Onvoldoende data',
        subtype: '',
        deltaMSlope: 0,
        deltaMPercent: 0,
        reliabilityNote: 'Niet alle meetpunten zijn beschikbaar.',
      );
    }

    final deltaM = (mA - mB).abs();
    final avgM = (mA.abs() + mB.abs()) / 2.0;
    final deltaMPct = avgM > 1e-6 ? deltaM / avgM * 100.0 : double.infinity;

    // Betrouwbaarheid op basis van R²
    final r2A = a.r2 ?? 0.0, r2B = b.r2 ?? 0.0;
    final String reliabilityNote;
    if (r2A < 0.5 || r2B < 0.5) {
      reliabilityNote =
          'Lage fit-kwaliteit (R² < 0,50) — niet-lineair verloop.';
    } else if (r2A < 0.8 || r2B < 0.8) {
      reliabilityNote =
          'Matige fit-kwaliteit (R² < 0,80) — enige niet-lineariteit.';
    } else {
      reliabilityNote = 'Goede fit-kwaliteit (R² ≥ 0,80).';
    }

    // OK?
    if (deltaM <= tolerance) {
      // Controleer stroomonbalans: helling gelijk maar T1 ≠ T2
      final t1A = a.temps[0], t1B = b.temps[0];
      if (t1A != null && t1B != null && (t1A - t1B).abs() > 2 * tolerance) {
        return _DiagnosisResult(
          status: _DiagnosisStatus.currentImbalance,
          label: 'Stroomonbalans vermoed',
          subtype: '',
          deltaMSlope: deltaM,
          deltaMPercent: deltaMPct,
          reliabilityNote: reliabilityNote,
        );
      }
      return _DiagnosisResult(
        status: _DiagnosisStatus.ok,
        label: 'OK — symmetrisch thermisch gedrag',
        subtype: '',
        deltaMSlope: deltaM,
        deltaMPercent: deltaMPct,
        reliabilityNote: reliabilityNote,
      );
    }

    // Afwijking — bepaal subtype
    final String subtype;
    final bool nonLinearA = (a.r2 ?? 1.0) < 0.8;
    final bool nonLinearB = (b.r2 ?? 1.0) < 0.8;
    final t1A = a.temps[0], t1B = b.temps[0];
    final t3A = a.temps[2], t3B = b.temps[2];

    final bool strongDeclineA =
        mA < -tolerance && t1A != null && t3A != null && t1A > t3A;
    final bool strongDeclineB =
        mB < -tolerance && t1B != null && t3B != null && t1B > t3B;

    if (strongDeclineA || strongDeclineB) {
      subtype = 'Overgangsweerstand nabij aansluiting';
    } else if (nonLinearA || nonLinearB) {
      subtype = 'Lokale hotspot';
    } else {
      subtype = 'Asymmetrische warmteverdeling';
    }

    return _DiagnosisResult(
      status: _DiagnosisStatus.deviation,
      label: 'Thermografische afwijking',
      subtype: subtype,
      deltaMSlope: deltaM,
      deltaMPercent: deltaMPct,
      reliabilityNote: reliabilityNote,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tamb = widget.tamb;
    final iRef = _parse(_iRefCtrl.text);
    final tolerance = _parse(_tolCtrl.text) ?? 0.2;

    // Reeks A = meting 1,3,5 (indices 0,2,4)
    // Reeks B = meting 2,4,6 (indices 1,3,5)
    final ms = widget.measurements;
    final pointsA = ms.length >= 5
        ? [ms[0], ms[2], ms[4]]
        : <RegressionMeasurementData>[];
    final pointsB = ms.length >= 6
        ? [ms[1], ms[3], ms[5]]
        : <RegressionMeasurementData>[];

    final hasA = pointsA.length == 3;
    final hasB = pointsB.length == 3;

    final seriesA = hasA
        ? _buildSeries(
            'Reeks A',
            AppTheme.chartA,
            pointsA,
            tamb,
            iRef,
            _normalize,
          )
        : null;
    final seriesB = hasB
        ? _buildSeries(
            'Reeks B',
            AppTheme.chartB,
            pointsB,
            tamb,
            iRef,
            _normalize,
          )
        : null;

    final diagnosis = (seriesA != null && seriesB != null)
        ? _diagnose(seriesA, seriesB, tolerance)
        : null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Regressie & stroomnormalisatie'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(44),
          child: AnalysisTopNav(
            current: AnalysisTopNavScreen.regression,
            onSelected: _openTopNavScreen,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          // ── Header ─────────────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF1A237E), Color(0xFF283593)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Lineaire regressie',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Reeks A = meting 1, 3, 5  ·  Reeks B = meting 2, 4, 6\n'
                  'Equidistante meetpunten. Detecteert afwijkend thermisch gedrag '
                  'op basis van warmteverloop (gradient).',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.88),
                    fontSize: 12,
                    height: 1.45,
                  ),
                ),
                if (tamb != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    'Tamb = ${tamb.toStringAsFixed(1)} °C',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 11,
                      fontFamily: 'monospace',
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),

          // ── Instellingen ────────────────────────────────────────────────────
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Instellingen',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Switch(
                        value: _normalize,
                        onChanged: (v) => setState(() => _normalize = v),
                      ),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'Stroomnormalisatie toepassen',
                          style: TextStyle(fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                  if (_normalize) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Referentiestroom I_ref  (A)',
                            style: TextStyle(fontSize: 13),
                          ),
                        ),
                        SizedBox(
                          width: 80,
                          child: TextField(
                            controller: _iRefCtrl,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            textAlign: TextAlign.center,
                            decoration: const InputDecoration(
                              isDense: true,
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 8,
                              ),
                            ),
                            onChanged: (_) => setState(() {}),
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Tolerantie Δm  (°C/pos)',
                          style: TextStyle(fontSize: 13),
                        ),
                      ),
                      SizedBox(
                        width: 80,
                        child: TextField(
                          controller: _tolCtrl,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          textAlign: TextAlign.center,
                          decoration: const InputDecoration(
                            isDense: true,
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 8,
                            ),
                          ),
                          onChanged: (_) => setState(() {}),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // ── Reeks A ──────────────────────────────────────────────────────────
          if (seriesA != null)
            _SeriesCard(result: seriesA, tamb: tamb, points: pointsA),
          const SizedBox(height: 8),

          // ── Reeks B ──────────────────────────────────────────────────────────
          if (seriesB != null)
            _SeriesCard(result: seriesB, tamb: tamb, points: pointsB),
          const SizedBox(height: 8),

          // ── Vergelijking + grafiek ────────────────────────────────────────────
          if (seriesA != null && seriesB != null && diagnosis != null) ...[
            LayoutBuilder(
              builder: (_, constraints) {
                final seriesAValue = seriesA;
                final seriesBValue = seriesB;
                final comparison = _ComparisonCard(
                  seriesA: seriesAValue,
                  seriesB: seriesBValue,
                  diagnosis: diagnosis,
                  tolerance: tolerance,
                );
                final chart = _RegressionChart(
                  seriesA: seriesAValue,
                  seriesB: seriesBValue,
                  rawTempsA: pointsA.map((p) => p.temperature).toList(),
                  rawTempsB: pointsB.map((p) => p.temperature).toList(),
                  tamb: tamb ?? 20.0,
                  tolerance: tolerance,
                );
                if (constraints.maxWidth >= 560) {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: comparison),
                      const SizedBox(width: 8),
                      Expanded(child: chart),
                    ],
                  );
                }
                return Column(
                  children: [comparison, const SizedBox(height: 8), chart],
                );
              },
            ),
            const SizedBox(height: 8),
            _DiagnosisCard(diagnosis: diagnosis),
          ],

          if (!hasA && !hasB)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'Onvoldoende meetpunten — vul meting 1 t/m 6 in.',
                  style: TextStyle(fontSize: 13),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ── Reekskaart ────────────────────────────────────────────────────────────────

class _SeriesCard extends StatelessWidget {
  final _SeriesResult result;
  final double? tamb;
  final List<RegressionMeasurementData> points;

  const _SeriesCard({
    required this.result,
    required this.tamb,
    required this.points,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final m = result.slope;
    final b = result.intercept;
    final r2 = result.r2;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 12,
                  backgroundColor: result.color.withValues(alpha: 0.15),
                  child: Icon(Icons.show_chart, color: result.color, size: 14),
                ),
                const SizedBox(width: 8),
                Text(
                  result.name,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (result.normalized) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'genormaliseerd',
                      style: TextStyle(fontSize: 9, color: AppTheme.primary),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 10),

            // Meetpunten
            ...List.generate(3, (i) {
              final p = points[i];
              final tRaw = p.temperature;
              final tNorm = result.temps[i];
              final iVal = p.current;
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: p.color,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    SizedBox(
                      width: 64,
                      child: Text(
                        p.label,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    if (tRaw != null)
                      Text(
                        'T = ${tRaw.toStringAsFixed(1)} °C',
                        style: const TextStyle(
                          fontSize: 11,
                          fontFamily: 'monospace',
                        ),
                      ),
                    if (iVal != null)
                      Text(
                        '  I = ${iVal.toStringAsFixed(1)} A',
                        style: TextStyle(
                          fontSize: 11,
                          fontFamily: 'monospace',
                          color: Colors.grey.shade600,
                        ),
                      ),
                    if (result.normalized &&
                        tNorm != null &&
                        tRaw != null &&
                        (tNorm - tRaw).abs() > 0.05)
                      Text(
                        '  → ${tNorm.toStringAsFixed(1)} °C',
                        style: TextStyle(
                          fontSize: 11,
                          fontFamily: 'monospace',
                          color: AppTheme.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                  ],
                ),
              );
            }),

            const Divider(height: 16),

            // Regressieparameters
            if (m != null && b != null && r2 != null) ...[
              _RegRow(
                'Helling m',
                '${m.toStringAsFixed(3)} °C/pos',
                color: m.abs() < 0.01 ? AppTheme.statusOk : null,
              ),
              _RegRow('Intercept b (x=0)', '${b.toStringAsFixed(2)} °C'),
              _RegRow(
                'Fit-kwaliteit R²',
                r2.toStringAsFixed(3),
                color: r2 >= 0.8
                    ? AppTheme.statusOk
                    : r2 >= 0.5
                    ? AppTheme.statusWarning
                    : AppTheme.statusFault,
              ),
              if (result.tMiddleResidual != null)
                _RegRow(
                  'Residu middelpunt',
                  '${result.tMiddleResidual!.toStringAsFixed(3)} °C',
                  color: result.tMiddleResidual!.abs() < 0.5
                      ? AppTheme.statusOk
                      : AppTheme.statusFault,
                ),
            ] else
              const Text(
                'Onvoldoende data voor regressie.',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
          ],
        ),
      ),
    );
  }
}

class _RegRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? color;

  const _RegRow(this.label, this.value, {this.color});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 2),
    child: Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(fontSize: 11, fontFamily: 'monospace'),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            fontFamily: 'monospace',
            color: color,
          ),
        ),
      ],
    ),
  );
}

// ── Vergelijkingskaart ────────────────────────────────────────────────────────

class _ComparisonCard extends StatelessWidget {
  final _SeriesResult seriesA;
  final _SeriesResult seriesB;
  final _DiagnosisResult diagnosis;
  final double tolerance;

  const _ComparisonCard({
    required this.seriesA,
    required this.seriesB,
    required this.diagnosis,
    required this.tolerance,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mA = seriesA.slope, mB = seriesB.slope;
    final deltaM = diagnosis.deltaMSlope;
    final deltaMPct = diagnosis.deltaMPercent;
    final withinTol = deltaM <= tolerance;

    // Staafbreedte normaliseren op max |m|
    final maxM = [
      mA?.abs() ?? 0,
      mB?.abs() ?? 0,
    ].reduce((a, b) => a > b ? a : b);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Vergelijking hellingen',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),

            // Visuele balkjes
            if (mA != null && mB != null && maxM > 0) ...[
              _SlopeBar(
                label: 'Reeks A  m_A',
                value: mA,
                max: maxM,
                color: AppTheme.chartA,
              ),
              const SizedBox(height: 4),
              _SlopeBar(
                label: 'Reeks B  m_B',
                value: mB,
                max: maxM,
                color: AppTheme.chartB,
              ),
              const SizedBox(height: 10),
            ],

            const Divider(height: 4),
            const SizedBox(height: 8),

            _RegRow(
              'Δm = |m_A − m_B|',
              '${deltaM.toStringAsFixed(3)} °C/pos',
              color: withinTol ? AppTheme.statusOk : AppTheme.statusFault,
            ),
            _RegRow(
              'Δm%',
              deltaMPct.isInfinite ? '—' : '${deltaMPct.toStringAsFixed(1)} %',
              color: withinTol ? AppTheme.statusOk : AppTheme.statusFault,
            ),
            _RegRow('Tolerantie', '${tolerance.toStringAsFixed(2)} °C/pos'),

            const SizedBox(height: 6),
            Text(
              diagnosis.reliabilityNote,
              style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
    );
  }
}

class _SlopeBar extends StatelessWidget {
  final String label;
  final double value;
  final double max;
  final Color color;

  const _SlopeBar({
    required this.label,
    required this.value,
    required this.max,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final frac = (max > 1e-10 ? (value.abs() / max).clamp(0.0, 1.0) : 0.0);
    return Row(
      children: [
        SizedBox(
          width: 100,
          child: Text(
            label,
            style: const TextStyle(fontSize: 10, fontFamily: 'monospace'),
          ),
        ),
        Expanded(
          child: LayoutBuilder(
            builder: (ctx, cons) {
              return Stack(
                children: [
                  Container(
                    height: 14,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  Container(
                    width: cons.maxWidth * frac,
                    height: 14,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.75),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 72,
          child: Text(
            '${value.toStringAsFixed(3)} °C/p',
            style: TextStyle(
              fontSize: 10,
              fontFamily: 'monospace',
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ),
      ],
    );
  }
}

// ── Diagnosekaart ─────────────────────────────────────────────────────────────

class _DiagnosisCard extends StatelessWidget {
  final _DiagnosisResult diagnosis;

  const _DiagnosisCard({required this.diagnosis});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final Color statusColor;
    final IconData statusIcon;

    switch (diagnosis.status) {
      case _DiagnosisStatus.ok:
        statusColor = AppTheme.statusOk;
        statusIcon = Icons.check_circle_outline_rounded;
      case _DiagnosisStatus.currentImbalance:
        statusColor = AppTheme.statusWarning;
        statusIcon = Icons.warning_amber_rounded;
      case _DiagnosisStatus.deviation:
        statusColor = AppTheme.statusFault;
        statusIcon = Icons.error_outline_rounded;
    }

    return Card(
      color: statusColor.withValues(alpha: 0.06),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: statusColor.withValues(alpha: 0.4), width: 1.5),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(statusIcon, color: statusColor, size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    diagnosis.label,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: statusColor,
                    ),
                  ),
                ),
              ],
            ),
            if (diagnosis.subtype.isNotEmpty) ...[
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  diagnosis.subtype,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: statusColor,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Regressiegrafiek ──────────────────────────────────────────────────────────

class _RegressionChart extends StatefulWidget {
  final _SeriesResult seriesA;
  final _SeriesResult seriesB;
  final List<double?> rawTempsA;
  final List<double?> rawTempsB;
  final double tamb;
  final double tolerance;

  const _RegressionChart({
    required this.seriesA,
    required this.seriesB,
    required this.rawTempsA,
    required this.rawTempsB,
    required this.tamb,
    required this.tolerance,
  });

  @override
  State<_RegressionChart> createState() => _RegressionChartState();
}

enum _ChartMode { deltaAbsolute, deltaPercent, actualTemperature, deltaMSlope }

class _RegressionChartState extends State<_RegressionChart> {
  _ChartMode _mode = _ChartMode.deltaAbsolute;
  bool _showTolerance = true;

  ({double slope, double intercept})? _regressionFromTemps(
    List<double?> temps,
  ) {
    if (temps.length < 3) return null;
    final t1 = temps[0];
    final t2 = temps[1];
    final t3 = temps[2];
    if (t1 == null || t2 == null || t3 == null) return null;

    final yBar = (t1 + t2 + t3) / 3.0;
    final slope = (t3 - t1) / 2.0;
    final intercept = yBar - slope * 2.0;
    return (slope: slope, intercept: intercept);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tamb = widget.tamb;
    final sA = widget.seriesA;
    final sB = widget.seriesB;

    // ΔT per punt
    final dtA = sA.temps.map((t) => t != null ? t - tamb : null).toList();
    final dtB = sB.temps.map((t) => t != null ? t - tamb : null).toList();

    // Referentie voor %: gemiddeld ΔT over alle punten
    final allDTs = [...dtA.whereType<double>(), ...dtB.whereType<double>()];
    final refDT = allDTs.isNotEmpty
        ? allDTs.reduce((a, b) => a + b) / allDTs.length
        : 1.0;

    final List<double?> ysA, ysB;
    final double? slopeA, interceptA, slopeB, interceptB;
    final double? tolBand;
    final String yLabel;
    final String seriesLabelA;
    final String seriesLabelB;
    final Color seriesColorA;
    final Color seriesColorB;

    switch (_mode) {
      case _ChartMode.deltaPercent:
        if (refDT.abs() > 0.01) {
          final scale = 100.0 / refDT;
          ysA = dtA.map((dt) => dt != null ? dt * scale : null).toList();
          ysB = dtB.map((dt) => dt != null ? dt * scale : null).toList();
          slopeA = sA.slope != null ? sA.slope! * scale : null;
          interceptA = sA.intercept != null
              ? (sA.intercept! - tamb) * scale
              : null;
          slopeB = sB.slope != null ? sB.slope! * scale : null;
          interceptB = sB.intercept != null
              ? (sB.intercept! - tamb) * scale
              : null;
          tolBand = _showTolerance ? widget.tolerance * scale : null;
          yLabel = 'ΔT (%)';
          seriesLabelA = 'Reeks A';
          seriesLabelB = 'Reeks B';
          seriesColorA = AppTheme.chartA;
          seriesColorB = AppTheme.chartB;
        } else {
          ysA = dtA;
          ysB = dtB;
          slopeA = sA.slope;
          interceptA = sA.intercept != null ? sA.intercept! - tamb : null;
          slopeB = sB.slope;
          interceptB = sB.intercept != null ? sB.intercept! - tamb : null;
          tolBand = _showTolerance ? widget.tolerance : null;
          yLabel = 'ΔT (°C)';
          seriesLabelA = 'Reeks A';
          seriesLabelB = 'Reeks B';
          seriesColorA = AppTheme.chartA;
          seriesColorB = AppTheme.chartB;
        }
      case _ChartMode.actualTemperature:
        final rawRegA = _regressionFromTemps(widget.rawTempsA);
        final rawRegB = _regressionFromTemps(widget.rawTempsB);
        ysA = widget.rawTempsA;
        ysB = widget.rawTempsB;
        slopeA = rawRegA?.slope;
        interceptA = rawRegA?.intercept;
        slopeB = rawRegB?.slope;
        interceptB = rawRegB?.intercept;
        tolBand = null;
        yLabel = 'T (°C)';
        seriesLabelA = 'Reeks A';
        seriesLabelB = 'Reeks B';
        seriesColorA = AppTheme.chartA;
        seriesColorB = AppTheme.chartB;
      case _ChartMode.deltaMSlope:
        final deltaM = (sA.slope != null && sB.slope != null)
            ? (sA.slope! - sB.slope!).abs()
            : null;
        ysA = deltaM != null ? [deltaM, deltaM, deltaM] : const <double?>[];
        ysB = _showTolerance
            ? [widget.tolerance, widget.tolerance, widget.tolerance]
            : const <double?>[];
        slopeA = null;
        interceptA = null;
        slopeB = null;
        interceptB = null;
        tolBand = null;
        yLabel = 'Δm (°C/pos)';
        seriesLabelA = 'Δm';
        seriesLabelB = 'Tolerantie';
        seriesColorA = AppTheme.primaryDark;
        seriesColorB = AppTheme.statusWarning;
      case _ChartMode.deltaAbsolute:
        ysA = dtA;
        ysB = dtB;
        slopeA = sA.slope;
        interceptA = sA.intercept != null ? sA.intercept! - tamb : null;
        slopeB = sB.slope;
        interceptB = sB.intercept != null ? sB.intercept! - tamb : null;
        tolBand = _showTolerance ? widget.tolerance : null;
        yLabel = 'ΔT (°C)';
        seriesLabelA = 'Reeks A';
        seriesLabelB = 'Reeks B';
        seriesColorA = AppTheme.chartA;
        seriesColorB = AppTheme.chartB;
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Thermisch verloop',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),

            // Toggles
            Wrap(
              spacing: 6,
              children: [
                FilterChip(
                  label: const Text('ΔT abs'),
                  selected: _mode == _ChartMode.deltaAbsolute,
                  onSelected: (_) =>
                      setState(() => _mode = _ChartMode.deltaAbsolute),
                  visualDensity: VisualDensity.compact,
                  labelStyle: const TextStyle(fontSize: 11),
                ),
                FilterChip(
                  label: const Text('ΔT %'),
                  selected: _mode == _ChartMode.deltaPercent,
                  onSelected: (_) =>
                      setState(() => _mode = _ChartMode.deltaPercent),
                  visualDensity: VisualDensity.compact,
                  labelStyle: const TextStyle(fontSize: 11),
                ),
                FilterChip(
                  label: const Text('Werkelijke T'),
                  selected: _mode == _ChartMode.actualTemperature,
                  onSelected: (_) =>
                      setState(() => _mode = _ChartMode.actualTemperature),
                  visualDensity: VisualDensity.compact,
                  labelStyle: const TextStyle(fontSize: 11),
                ),
                FilterChip(
                  label: const Text('Δm-lijn'),
                  selected: _mode == _ChartMode.deltaMSlope,
                  onSelected: (_) =>
                      setState(() => _mode = _ChartMode.deltaMSlope),
                  visualDensity: VisualDensity.compact,
                  labelStyle: const TextStyle(fontSize: 11),
                ),
                FilterChip(
                  label: const Text('Tolerantie'),
                  selected: _showTolerance,
                  onSelected: (v) => setState(() => _showTolerance = v),
                  visualDensity: VisualDensity.compact,
                  labelStyle: const TextStyle(fontSize: 11),
                ),
              ],
            ),
            const SizedBox(height: 6),

            // Legenda
            Row(
              children: [
                _dot(seriesColorA),
                const SizedBox(width: 4),
                Text(
                  seriesLabelA,
                  style: TextStyle(
                    fontSize: 10,
                    color: seriesColorA,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (ysB.whereType<double>().isNotEmpty) ...[
                  const SizedBox(width: 12),
                  _dot(seriesColorB),
                  const SizedBox(width: 4),
                  Text(
                    seriesLabelB,
                    style: TextStyle(
                      fontSize: 10,
                      color: seriesColorB,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
                if (tolBand != null) ...[
                  const SizedBox(width: 12),
                  Container(
                    width: 18,
                    height: 3,
                    color: seriesColorA.withValues(alpha: 0.35),
                  ),
                  const SizedBox(width: 4),
                  const Text(
                    'tol.',
                    style: TextStyle(fontSize: 10, color: Colors.grey),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 4),

            // Grafiek
            SizedBox(
              height: 210,
              child: CustomPaint(
                painter: _ChartPainter(
                  ysA: ysA,
                  ysB: ysB,
                  slopeA: slopeA,
                  interceptA: interceptA,
                  slopeB: slopeB,
                  interceptB: interceptB,
                  toleranceBand: tolBand,
                  colorA: seriesColorA,
                  colorB: seriesColorB,
                  yLabel: yLabel,
                ),
                size: Size.infinite,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _dot(Color color) => Container(
    width: 10,
    height: 10,
    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
  );
}

// ── Grafiekpainter ────────────────────────────────────────────────────────────

class _ChartPainter extends CustomPainter {
  final List<double?> ysA;
  final List<double?> ysB;
  final double? slopeA;
  final double? interceptA;
  final double? slopeB;
  final double? interceptB;
  final double? toleranceBand;
  final Color colorA;
  final Color colorB;
  final String yLabel;

  const _ChartPainter({
    required this.ysA,
    required this.ysB,
    required this.slopeA,
    required this.interceptA,
    required this.slopeB,
    required this.interceptB,
    required this.toleranceBand,
    required this.colorA,
    required this.colorB,
    required this.yLabel,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const ml = 46.0, mr = 8.0, mt = 12.0, mb = 28.0;
    final w = size.width - ml - mr;
    final h = size.height - mt - mb;
    if (w <= 0 || h <= 0) return;

    // Y-bereik bepalen
    final allY = <double>[
      ...ysA.whereType<double>(),
      ...ysB.whereType<double>(),
    ];
    if (slopeA != null && interceptA != null) {
      allY.add(interceptA! + slopeA! * 1);
      allY.add(interceptA! + slopeA! * 3);
    }
    if (slopeB != null && interceptB != null) {
      allY.add(interceptB! + slopeB! * 1);
      allY.add(interceptB! + slopeB! * 3);
    }
    if (toleranceBand != null && slopeA != null && interceptA != null) {
      final tb = toleranceBand!;
      allY.add(interceptA! + (slopeA! + tb) * 1);
      allY.add(interceptA! + (slopeA! + tb) * 3);
      allY.add(interceptA! + (slopeA! - tb) * 1);
      allY.add(interceptA! + (slopeA! - tb) * 3);
    }
    if (allY.isEmpty) return;

    double yMin = allY.reduce((a, b) => a < b ? a : b);
    double yMax = allY.reduce((a, b) => a > b ? a : b);
    final span = yMax - yMin;
    final pad = span < 0.01 ? 0.5 : span * 0.15;
    yMin -= pad;
    yMax += pad;
    final ySpan = yMax - yMin;

    Offset px(double x, double y) =>
        Offset(ml + (x - 1) / 2.0 * w, mt + (1.0 - (y - yMin) / ySpan) * h);

    // Achtergrond
    canvas.drawRect(
      Rect.fromLTWH(ml, mt, w, h),
      Paint()
        ..color = Colors.grey.shade50
        ..style = PaintingStyle.fill,
    );

    // Gridlijnen + Y-labels
    const gridCount = 4;
    final gridPaint = Paint()
      ..color = Colors.grey.shade200
      ..strokeWidth = 0.7;
    for (int i = 0; i <= gridCount; i++) {
      final y = yMin + ySpan * i / gridCount;
      final p = px(1, y);
      canvas.drawLine(Offset(ml, p.dy), Offset(ml + w, p.dy), gridPaint);
      _label(
        canvas,
        y.toStringAsFixed(1),
        Offset(ml - 4, p.dy - 5),
        width: 40,
        align: TextAlign.right,
      );
    }

    // X-posities + labels
    for (int xi = 1; xi <= 3; xi++) {
      final p = px(xi.toDouble(), yMin);
      canvas.drawLine(Offset(p.dx, mt), Offset(p.dx, mt + h), gridPaint);
      _label(canvas, 'pos $xi', Offset(p.dx - 16, mt + h + 5), width: 34);
    }

    // Assen
    final axisPaint = Paint()
      ..color = Colors.grey.shade500
      ..strokeWidth = 1;
    canvas.drawLine(Offset(ml, mt), Offset(ml, mt + h), axisPaint);
    canvas.drawLine(Offset(ml, mt + h), Offset(ml + w, mt + h), axisPaint);

    // Y-eenheid
    _label(canvas, yLabel, Offset(0, mt - 10), width: 60, fontSize: 8.0);

    // Tolerantieband rondom regressielijn A
    if (toleranceBand != null && slopeA != null && interceptA != null) {
      final tb = toleranceBand!;
      final p1u = px(1, interceptA! + (slopeA! + tb) * 1);
      final p3u = px(3, interceptA! + (slopeA! + tb) * 3);
      final p3l = px(3, interceptA! + (slopeA! - tb) * 3);
      final p1l = px(1, interceptA! + (slopeA! - tb) * 1);
      final bandPath = Path()
        ..moveTo(p1u.dx, p1u.dy)
        ..lineTo(p3u.dx, p3u.dy)
        ..lineTo(p3l.dx, p3l.dy)
        ..lineTo(p1l.dx, p1l.dy)
        ..close();
      canvas.drawPath(
        bandPath,
        Paint()
          ..color = colorA.withValues(alpha: 0.08)
          ..style = PaintingStyle.fill,
      );
      final borderPaint = Paint()
        ..color = colorA.withValues(alpha: 0.30)
        ..strokeWidth = 1
        ..style = PaintingStyle.stroke;
      canvas.drawLine(p1u, p3u, borderPaint);
      canvas.drawLine(p1l, p3l, borderPaint);
    }

    // Regressielijnen (semi-transparant)
    void drawReg(double? sl, double? ic, Color color) {
      if (sl == null || ic == null) return;
      canvas.drawLine(
        px(1, ic + sl * 1),
        px(3, ic + sl * 3),
        Paint()
          ..color = color.withValues(alpha: 0.45)
          ..strokeWidth = 1.5
          ..style = PaintingStyle.stroke,
      );
    }

    drawReg(slopeA, interceptA, colorA);
    drawReg(slopeB, interceptB, colorB);

    // Datareeksen
    void drawSeries(List<double?> ys, Color color) {
      final pts = <Offset>[];
      for (int i = 0; i < ys.length; i++) {
        final y = ys[i];
        if (y != null) pts.add(px((i + 1).toDouble(), y));
      }
      if (pts.isEmpty) return;
      if (pts.length > 1) {
        final path = Path()..moveTo(pts[0].dx, pts[0].dy);
        for (int i = 1; i < pts.length; i++) {
          path.lineTo(pts[i].dx, pts[i].dy);
        }
        canvas.drawPath(
          path,
          Paint()
            ..color = color
            ..strokeWidth = 2
            ..style = PaintingStyle.stroke,
        );
      }
      for (final pt in pts) {
        canvas.drawCircle(
          pt,
          5,
          Paint()
            ..color = color
            ..style = PaintingStyle.fill,
        );
        canvas.drawCircle(
          pt,
          2.5,
          Paint()
            ..color = Colors.white
            ..style = PaintingStyle.fill,
        );
      }
    }

    drawSeries(ysA, colorA);
    drawSeries(ysB, colorB);

    // Kader
    canvas.drawRect(
      Rect.fromLTWH(ml, mt, w, h),
      Paint()
        ..color = Colors.grey.shade300
        ..strokeWidth = 0.8
        ..style = PaintingStyle.stroke,
    );
  }

  void _label(
    Canvas canvas,
    String text,
    Offset position, {
    double fontSize = 8.5,
    Color color = Colors.grey,
    TextAlign align = TextAlign.left,
    double width = 60,
  }) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(fontSize: fontSize, color: color),
      ),
      textDirection: TextDirection.ltr,
      textAlign: align,
    )..layout(minWidth: 0, maxWidth: width);
    final offset = align == TextAlign.right
        ? Offset(position.dx - tp.width, position.dy)
        : position;
    tp.paint(canvas, offset);
  }

  @override
  bool shouldRepaint(_ChartPainter old) =>
      ysA != old.ysA ||
      ysB != old.ysB ||
      toleranceBand != old.toleranceBand ||
      slopeA != old.slopeA ||
      interceptA != old.interceptA ||
      slopeB != old.slopeB ||
      interceptB != old.interceptB;
}
