import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../domain/entities/analysis_result.dart';

/// Bar/line chart showing dT/dx along the conductor.
/// Hotspot threshold line is drawn as a horizontal dashed indicator.
class GradientChart extends StatelessWidget {
  final AnalysisResult result;

  const GradientChart({super.key, required this.result});

  @override
  Widget build(BuildContext context) {
    final absGrads = result.gradients.map((g) => g.abs()).toList();
    final threshold = result.meanAbsGradient * result.hotspotFactor;

    final mainSpots = List.generate(
      result.conductor.positions.length,
      (i) => FlSpot(result.conductor.positions[i], absGrads[i]),
    );

    final thresholdSpots = [
      FlSpot(result.conductor.positions.first, threshold),
      FlSpot(result.conductor.positions.last, threshold),
    ];

    return AspectRatio(
      aspectRatio: 2.2,
      child: Padding(
        padding: const EdgeInsets.only(right: 16, top: 8, bottom: 4),
        child: LineChart(
          LineChartData(
            gridData: FlGridData(
              show: true,
              getDrawingHorizontalLine: (_) =>
                  FlLine(color: Colors.grey.shade200, strokeWidth: 1),
              getDrawingVerticalLine: (_) =>
                  FlLine(color: Colors.grey.shade200, strokeWidth: 1),
            ),
            titlesData: FlTitlesData(
              leftTitles: AxisTitles(
                axisNameWidget: const Text('|∇T| (°C/m)',
                    style: TextStyle(fontSize: 11)),
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 52,
                  getTitlesWidget: (v, _) => Text(
                    v.toStringAsFixed(2),
                    style: const TextStyle(fontSize: 10),
                  ),
                ),
              ),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 24,
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
            lineBarsData: [
              // Gradient profile
              LineChartBarData(
                spots: mainSpots,
                isCurved: true,
                curveSmoothness: 0.05,
                color: AppTheme.chartGradient,
                barWidth: 2,
                dotData: const FlDotData(show: false),
                belowBarData: BarAreaData(
                  show: true,
                  color: AppTheme.chartGradient.withValues(alpha: 0.08),
                ),
              ),
              // Hotspot threshold dashed line
              LineChartBarData(
                spots: thresholdSpots,
                isCurved: false,
                color: AppTheme.chartHotspot,
                barWidth: 1.5,
                dotData: const FlDotData(show: false),
                dashArray: [6, 4],
              ),
            ],
            lineTouchData: LineTouchData(
              touchTooltipData: LineTouchTooltipData(
                getTooltipColor: (_) => Colors.blueGrey.shade800,
                getTooltipItems: (spots) => spots.map((s) {
                  if (s.barIndex == 1) {
                    return LineTooltipItem(
                      'Threshold\n${s.y.toStringAsFixed(3)} °C/m',
                      const TextStyle(
                          color: Colors.redAccent, fontSize: 11),
                    );
                  }
                  return LineTooltipItem(
                    '${s.x.toStringAsFixed(3)} m\n${s.y.toStringAsFixed(3)} °C/m',
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
}
