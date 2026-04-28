import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

enum AnalysisTopNavScreen { thermal, npr, regression }

class AnalysisTopNav extends StatelessWidget {
  final AnalysisTopNavScreen current;
  final ValueChanged<AnalysisTopNavScreen> onSelected;

  const AnalysisTopNav({
    super.key,
    required this.current,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Theme.of(context).appBarTheme.backgroundColor,
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _NavChip(
              label: 'Thermische indicator',
              selected: current == AnalysisTopNavScreen.thermal,
              onTap: () => onSelected(AnalysisTopNavScreen.thermal),
            ),
            const SizedBox(width: 8),
            _NavChip(
              label: 'NPR 8040-1',
              selected: current == AnalysisTopNavScreen.npr,
              onTap: () => onSelected(AnalysisTopNavScreen.npr),
            ),
            const SizedBox(width: 8),
            _NavChip(
              label: 'Regressieanalyse',
              selected: current == AnalysisTopNavScreen.regression,
              onTap: () => onSelected(AnalysisTopNavScreen.regression),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _NavChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label, style: const TextStyle(fontSize: 12)),
      selected: selected,
      onSelected: (_) => onTap(),
      selectedColor: Colors.white,
      side: BorderSide(
        color: selected
            ? AppTheme.primaryDark
            : Colors.white.withValues(alpha: 0.72),
      ),
      labelStyle: TextStyle(
        color: selected ? AppTheme.primaryDark : AppTheme.primaryDark,
        fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
      ),
      backgroundColor: Colors.white.withValues(alpha: 0.94),
      visualDensity: VisualDensity.compact,
      showCheckmark: false,
    );
  }
}
