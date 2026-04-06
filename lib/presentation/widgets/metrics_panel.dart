import 'package:flutter/material.dart';
import '../../domain/entities/analysis_result.dart';

class MetricsPanel extends StatelessWidget {
  final AnalysisResult result;

  const MetricsPanel({super.key, required this.result});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Thermal Metrics — ${result.conductor.name}',
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                _MetricChip(
                  label: 'Max Temp',
                  value: '${result.maxTemperature.toStringAsFixed(1)} °C',
                  icon: Icons.thermostat,
                  color: Colors.red.shade700,
                ),
                _MetricChip(
                  label: 'ΔT',
                  value: '${result.deltaT.toStringAsFixed(2)} °C',
                  icon: Icons.swap_vert,
                  color: Colors.orange.shade700,
                ),
                _MetricChip(
                  label: 'Max |∇T|',
                  value: '${result.maxAbsGradient.toStringAsFixed(3)} °C/m',
                  icon: Icons.trending_up,
                  color: Colors.purple.shade700,
                ),
                _MetricChip(
                  label: '∇T / I',
                  value:
                      '${result.normalizedGradient.toStringAsFixed(4)} °C/m/A',
                  icon: Icons.bolt,
                  color: Colors.blue.shade700,
                ),
                _MetricChip(
                  label: 'Hotspot length',
                  value: result.hotspots.isEmpty
                      ? '—'
                      : '${result.totalHotspotLength.toStringAsFixed(3)} m',
                  icon: Icons.local_fire_department,
                  color: result.hotspots.isEmpty
                      ? Colors.grey
                      : Colors.red.shade900,
                ),
                _MetricChip(
                  label: 'Hotspots',
                  value: '${result.hotspots.length}',
                  icon: Icons.pin_drop,
                  color: result.hotspots.isEmpty
                      ? Colors.grey
                      : Colors.deepOrange,
                ),
              ],
            ),
            if (result.hotspots.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Divider(),
              const SizedBox(height: 4),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.science, size: 16, color: Colors.grey.shade600),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      result.hotspotDiagnosis,
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: Colors.grey.shade700),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _MetricChip extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _MetricChip({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 130),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
