import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../domain/entities/analysis_result.dart';

/// Dual-mode temperature chart:
///   - Single conductor: blue line + red hotspot overlay.
///   - Comparison mode: blue line A + orange line B + red hotspot overlay for both.
class TemperatureChart extends StatelessWidget {
  final AnalysisResult resultA;
  final AnalysisResult? resultB;

  const TemperatureChart({
    super.key,
    required this.resultA,
    this.resultB,
  });

  @override
  Widget build(BuildContext context) {
    final bars = <LineChartBarData>[
      _buildMainBar(resultA, AppTheme.chartA, 'A'),
      if (resultB != null) _buildMainBar(resultB!, AppTheme.chartB, 'B'),
      ..._buildHotspotBars(resultA, AppTheme.chartHotspot),
      if (resultB != null) ..._buildHotspotBars(resultB!, AppTheme.chartHotspot),
    ];

    return AspectRatio(
      aspectRatio: 1.7,
      child: Padding(
        padding: const EdgeInsets.only(right: 16, top: 8, bottom: 4),
        child: LineChart(
          LineChartData(
            gridData: FlGridData(
              show: true,
              drawVerticalLine: true,
              getDrawingHorizontalLine: (_) =>
                  FlLine(color: Colors.grey.shade200, strokeWidth: 1),
              getDrawingVerticalLine: (_) =>
                  FlLine(color: Colors.grey.shade200, strokeWidth: 1),
            ),
            titlesData: FlTitlesData(
              leftTitles: AxisTitles(
                axisNameWidget: const Text('T (°C)',
                    style: TextStyle(fontSize: 11)),
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 52,
                  getTitlesWidget: (v, _) => Text(
                    v.toStringAsFixed(0),
                    style: const TextStyle(fontSize: 10),
                  ),
                ),
              ),
              bottomTitles: AxisTitles(
                axisNameWidget: const Text('Position (m)',
                    style: TextStyle(fontSize: 11)),
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 28,
                  getTitlesWidget: (v, _) => Text(
                    v.toStringAsFixed(2),
                    style: const TextStyle(fontSize: 10),
                  ),
                ),
              ),
              topTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false)),
              rightTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false)),
            ),
            borderData: FlBorderData(
              show: true,
              border: Border.all(color: Colors.grey.shade300),
            ),
            lineBarsData: bars,
            lineTouchData: LineTouchData(
              touchTooltipData: LineTouchTooltipData(
                getTooltipColor: (_) => Colors.blueGrey.shade800,
                getTooltipItems: (spots) => spots.map((s) {
                  final label = s.barIndex == 0
                      ? resultA.conductor.name
                      : (resultB?.conductor.name ?? '');
                  return LineTooltipItem(
                    '$label\n${s.x.toStringAsFixed(3)} m\n${s.y.toStringAsFixed(2)} °C',
                    const TextStyle(color: Colors.white, fontSize: 11),
                  );
                }).toList(),
              ),
            ),
          ),
        ),
      ),
    );
  }

  LineChartBarData _buildMainBar(
    AnalysisResult r,
    Color color,
    String label,
  ) {
    return LineChartBarData(
      spots: List.generate(
        r.conductor.positions.length,
        (i) => FlSpot(r.conductor.positions[i], r.effectiveTemps[i]),
      ),
      isCurved: true,
      curveSmoothness: 0.1,
      color: color,
      barWidth: 2,
      dotData: const FlDotData(show: false),
      isStrokeCapRound: true,
    );
  }

  /// Creates one [LineChartBarData] per hotspot region (drawn in red on top).
  List<LineChartBarData> _buildHotspotBars(
    AnalysisResult r,
    Color color,
  ) {
    return r.hotspots.map((h) {
      final spots = <FlSpot>[];
      for (int i = h.startIndex; i <= h.endIndex; i++) {
        spots.add(FlSpot(r.conductor.positions[i], r.effectiveTemps[i]));
      }
      return LineChartBarData(
        spots: spots,
        isCurved: false,
        color: color,
        barWidth: 4,
        dotData: FlDotData(
          show: true,
          getDotPainter: (_, _, _, _) => FlDotCirclePainter(
            radius: 3,
            color: color,
            strokeWidth: 0,
            strokeColor: Colors.transparent,
          ),
        ),
        isStrokeCapRound: true,
      );
    }).toList();
  }
}
