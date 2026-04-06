import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../domain/entities/hotspot.dart';

class HotspotInfoCard extends StatelessWidget {
  final List<Hotspot> hotspots;
  final double meanGradient;

  const HotspotInfoCard({
    super.key,
    required this.hotspots,
    required this.meanGradient,
  });

  @override
  Widget build(BuildContext context) {
    if (hotspots.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(Icons.check_circle_outline,
                  color: AppTheme.statusOk, size: 20),
              const SizedBox(width: 8),
              const Text('No hotspots detected'),
            ],
          ),
        ),
      );
    }

    return Card(
      child: ExpansionTile(
        leading: Icon(Icons.local_fire_department,
            color: AppTheme.chartHotspot),
        title: Text(
          '${hotspots.length} hotspot${hotspots.length > 1 ? 's' : ''} detected',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: AppTheme.chartHotspot,
          ),
        ),
        subtitle: Text(
          'Total: ${hotspots.fold(0.0, (s, h) => s + h.length).toStringAsFixed(3)} m',
          style: const TextStyle(fontSize: 12),
        ),
        children: hotspots.asMap().entries.map((entry) {
          final i = entry.key;
          final h = entry.value;
          final peakRatio = meanGradient > 0 ? h.peakGradient / meanGradient : 0;

          return ListTile(
            dense: true,
            leading: CircleAvatar(
              radius: 13,
              backgroundColor: AppTheme.chartHotspot.withValues(alpha: 0.15),
              child: Text(
                '${i + 1}',
                style: TextStyle(
                  fontSize: 11,
                  color: AppTheme.chartHotspot,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            title: Text(
              '${h.startPosition.toStringAsFixed(3)} m → '
              '${h.endPosition.toStringAsFixed(3)} m',
              style: const TextStyle(fontSize: 13),
            ),
            subtitle: Text(
              'Length: ${h.length.toStringAsFixed(3)} m  |  '
              'Peak: ${h.peakGradient.toStringAsFixed(3)} °C/m  '
              '(${peakRatio.toStringAsFixed(1)}× mean)',
              style: const TextStyle(fontSize: 11),
            ),
            trailing: h.isShort
                ? Chip(
                    label: const Text('Short',
                        style: TextStyle(fontSize: 10)),
                    backgroundColor:
                        AppTheme.statusFault.withValues(alpha: 0.15),
                    side: BorderSide(color: AppTheme.statusFault),
                    padding: EdgeInsets.zero,
                    visualDensity: VisualDensity.compact,
                  )
                : null,
          );
        }).toList(),
      ),
    );
  }
}
