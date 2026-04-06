import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:share_plus/share_plus.dart';
import '../../core/di/injection_container.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/thermal_indicator_session.dart';
import '../../domain/entities/measurement_session.dart';
import '../../domain/usecases/export_report_usecase.dart';
import '../bloc/session/session_bloc.dart';
import '../bloc/session/session_event.dart';
import '../bloc/session/session_state.dart';
import '../widgets/metrics_panel.dart';
import '../widgets/status_badge.dart';
import '../widgets/temperature_chart.dart';

class SessionHistoryScreen extends StatefulWidget {
  final void Function(int tab)? onTabSwitch;

  const SessionHistoryScreen({super.key, this.onTabSwitch});

  @override
  State<SessionHistoryScreen> createState() => _SessionHistoryScreenState();
}

class _SessionHistoryScreenState extends State<SessionHistoryScreen> {
  List<ThermalIndicatorSession> _thermalSessions = const [];

  @override
  void initState() {
    super.initState();
    context.read<SessionBloc>().add(const SessionsLoadRequested());
    _loadThermalSessions();
    ThermalIndicatorSessionStore.revision.addListener(_loadThermalSessions);
  }

  @override
  void dispose() {
    ThermalIndicatorSessionStore.revision.removeListener(_loadThermalSessions);
    super.dispose();
  }

  void _loadThermalSessions() {
    final store = ThermalIndicatorSessionStore(sl<SharedPreferences>());
    if (!mounted) return;
    setState(() {
      _thermalSessions = store.loadAll();
    });
  }

  Future<void> _deleteThermalSession(String id) async {
    final store = ThermalIndicatorSessionStore(sl<SharedPreferences>());
    await store.delete(id);
    _loadThermalSessions();
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SessionBloc, SessionState>(
      builder: (context, state) {
        if (state is SessionLoading) {
          return const Center(child: CircularProgressIndicator());
        }
        if (state is SessionError) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(state.message,
                    style: TextStyle(
                        color: Theme.of(context).colorScheme.error)),
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: () => context
                      .read<SessionBloc>()
                      .add(const SessionsLoadRequested()),
                  child: const Text('Retry'),
                ),
              ],
            ),
          );
        }
        if (state is SessionLoaded) {
          final hasThermal = _thermalSessions.isNotEmpty;
          final hasClassic = state.sessions.isNotEmpty;

          if (!hasThermal && !hasClassic) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.history, size: 64, color: Colors.grey.shade300),
                  const SizedBox(height: 12),
                  Text(
                    'No saved sessions yet.',
                    style: TextStyle(color: Colors.grey.shade500),
                  ),
                ],
              ),
            );
          }

          return ListView(
            padding: const EdgeInsets.only(bottom: 32),
            children: [
              if (hasThermal) ...[
                _SectionHeader(
                  title: 'Thermische indicator K',
                  count: _thermalSessions.length,
                ),
                ..._thermalSessions.map(
                  (s) => _ThermalIndicatorSessionTile(
                    session: s,
                    onDelete: () => _deleteThermalSession(s.id),
                    onLoad: () {
                      ThermalIndicatorSessionStore.pendingLoad.value = s;
                      widget.onTabSwitch?.call(1);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('"${s.name}" geladen in K-scherm.'),
                        ),
                      );
                    },
                  ),
                ),
              ],
              if (hasClassic) ...[
                _SectionHeader(
                  title: 'Analyse & vergelijking',
                  count: state.sessions.length,
                ),
                ...state.sessions.map(
                  (s) => _SessionTile(session: s),
                ),
              ],
            ],
          );
        }
        return const SizedBox.shrink();
      },
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final int count;
  const _SectionHeader({required this.title, required this.count});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
      child: Row(
        children: [
          Text(title,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade700,
                  )),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
            decoration: BoxDecoration(
              color: Colors.grey.shade200,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text('$count',
                style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey.shade700,
                    fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}

class _ThermalIndicatorSessionTile extends StatelessWidget {
  final ThermalIndicatorSession session;
  final VoidCallback onDelete;
  final VoidCallback onLoad;

  const _ThermalIndicatorSessionTile({
    required this.session,
    required this.onDelete,
    required this.onLoad,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: AppTheme.primary.withValues(alpha: 0.15),
          child: const Icon(Icons.calculate_outlined,
              color: AppTheme.primary, size: 20),
        ),
        title: Text(session.name,
            style: const TextStyle(fontWeight: FontWeight.w500)),
        subtitle: Text(
          '${DateFormat('EEE MMM d, yyyy  HH:mm').format(session.createdAt)}'
          '  ·  Tamb ${session.ambient.toStringAsFixed(1)} °C'
          '  ·  ${session.measurements.length} metingen',
          style: const TextStyle(fontSize: 12),
        ),
        trailing: PopupMenuButton<String>(
          itemBuilder: (_) => const [
            PopupMenuItem(value: 'view', child: Text('Bekijk details')),
            PopupMenuItem(
              value: 'load',
              child: ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.open_in_new_rounded, size: 18),
                title: Text('Laden in K-scherm'),
              ),
            ),
            PopupMenuItem(
                value: 'delete',
                child:
                    Text('Verwijder', style: TextStyle(color: Colors.red))),
          ],
          onSelected: (v) {
            switch (v) {
              case 'view':
                _showDetail(context);
              case 'load':
                onLoad();
              case 'delete':
                _confirmDelete(context);
            }
          },
        ),
        onTap: () => _showDetail(context),
      ),
    );
  }

  void _showDetail(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _ThermalIndicatorSessionDetailScreen(session: session),
      ),
    );
  }

  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sessie verwijderen?'),
        content: Text('"${session.name}" wordt definitief verwijderd.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annuleren'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: AppTheme.statusFault),
            onPressed: () {
              Navigator.pop(ctx);
              onDelete();
            },
            child: const Text('Verwijderen'),
          ),
        ],
      ),
    );
  }
}

class _ThermalIndicatorSessionDetailScreen extends StatelessWidget {
  final ThermalIndicatorSession session;
  const _ThermalIndicatorSessionDetailScreen({required this.session});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(session.name, overflow: TextOverflow.ellipsis),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            DateFormat('EEE MMM d, yyyy  HH:mm').format(session.createdAt),
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _detailRow('Omgevingstemperatuur',
                      '${session.ambient.toStringAsFixed(1)} °C'),
                  if (session.imageFileName != null)
                    _detailRow('Afbeelding', session.imageFileName!),
                  if (session.note != null && session.note!.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text('Notitie',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey.shade700)),
                    const SizedBox(height: 4),
                    Text(session.note!,
                        style: const TextStyle(fontSize: 13)),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text('Metingen',
              style: Theme.of(context)
                  .textTheme
                  .titleSmall
                  ?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          ...session.measurements.map((m) => Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(m.label,
                          style: const TextStyle(
                              fontSize: 13, fontWeight: FontWeight.bold)),
                      Text('Bron: ${m.sourceLabel}',
                          style: TextStyle(
                              fontSize: 11, color: Colors.grey.shade700)),
                      const Divider(height: 12),
                      _detailRow('I',
                          '${m.current.toStringAsFixed(1)} ± ${m.currentError.toStringAsFixed(2)} A'),
                      _detailRow('T',
                          '${m.temperature.toStringAsFixed(1)} ± ${m.temperatureError.toStringAsFixed(2)} °C'),
                    ],
                  ),
                ),
              )),
        ],
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(
            width: 140,
            child: Text(label,
                style: const TextStyle(fontSize: 12, color: Colors.black54)),
          ),
          Expanded(
            child: Text(value,
                style: const TextStyle(
                    fontSize: 13, fontFamily: 'monospace')),
          ),
        ],
      ),
    );
  }
}

class _SessionTile extends StatelessWidget {
  final MeasurementSession session;

  const _SessionTile({required this.session});

  @override
  Widget build(BuildContext context) {
    final statusColor = session.comparison != null
        ? switch (session.comparison!.status) {
            _ when session.comparison!.status.name == 'ok' =>
              AppTheme.statusOk,
            _ when session.comparison!.status.name == 'warning' =>
              AppTheme.statusWarning,
            _ => AppTheme.statusFault,
          }
        : Colors.grey;

    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: statusColor.withValues(alpha: 0.15),
          child: Icon(
            session.hasComparison
                ? Icons.compare_arrows
                : Icons.thermostat,
            color: statusColor,
            size: 20,
          ),
        ),
        title: Text(session.name,
            style: const TextStyle(fontWeight: FontWeight.w500)),
        subtitle: Text(
          DateFormat('EEE MMM d, yyyy  HH:mm').format(session.createdAt),
          style: const TextStyle(fontSize: 12),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (session.comparison != null)
              StatusBadge(status: session.comparison!.status, fontSize: 11),
            const SizedBox(width: 4),
            PopupMenuButton<String>(
              itemBuilder: (_) => [
                const PopupMenuItem(value: 'view', child: Text('Bekijk details')),
                const PopupMenuItem(value: 'export', child: Text('Exporteer rapport')),
                const PopupMenuItem(
                    value: 'delete',
                    child: Text('Verwijder',
                        style: TextStyle(color: Colors.red))),
              ],
              onSelected: (v) {
                switch (v) {
                  case 'view':
                    _showDetail(context);
                  case 'export':
                    _export(context);
                  case 'delete':
                    _confirmDelete(context);
                }
              },
            ),
          ],
        ),
        onTap: () => _showDetail(context),
      ),
    );
  }

  void _showDetail(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _SessionDetailScreen(session: session),
      ),
    );
  }

  Future<void> _export(BuildContext context) async {
    try {
      final path = await sl<ExportReportUseCase>().call(session);
      await Share.shareXFiles(
        [XFile(path)],
        subject: session.name,
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export failed: $e')),
        );
      }
    }
  }

  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete session?'),
        content: Text('This will permanently delete "${session.name}".'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: AppTheme.statusFault),
            onPressed: () {
              Navigator.pop(ctx);
              context
                  .read<SessionBloc>()
                  .add(SessionDeleteRequested(session.id));
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _SessionDetailScreen extends StatelessWidget {
  final MeasurementSession session;
  const _SessionDetailScreen({required this.session});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(session.name, overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(
            icon: const Icon(Icons.share_outlined),
            onPressed: () async {
              try {
                final path =
                    await sl<ExportReportUseCase>().call(session);
                await Share.shareXFiles([XFile(path)],
                    subject: session.name);
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Export failed: $e')),
                  );
                }
              }
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          if (session.analysisB != null) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Text('Temperature Comparison',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade600,
                      )),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: TemperatureChart(
                resultA: session.analysisA,
                resultB: session.analysisB,
              ),
            ),
          ] else ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Text('Temperature Profile',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade600,
                      )),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: TemperatureChart(resultA: session.analysisA),
            ),
          ],
          MetricsPanel(result: session.analysisA),
          if (session.analysisB != null)
            MetricsPanel(result: session.analysisB!),
          if (session.comparison != null)
            _ComparisonSummaryCard(session: session),
        ],
      ),
    );
  }
}

class _ComparisonSummaryCard extends StatelessWidget {
  final MeasurementSession session;
  const _ComparisonSummaryCard({required this.session});

  @override
  Widget build(BuildContext context) {
    final c = session.comparison!;
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('Comparison Result',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold)),
                const Spacer(),
                StatusBadge(status: c.status),
              ],
            ),
            const SizedBox(height: 10),
            Text(c.primaryDiagnosis),
            if (c.flags.isNotEmpty) ...[
              const SizedBox(height: 8),
              ...c.flags.map(
                (f) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('• '),
                      Expanded(child: Text(f, style: const TextStyle(fontSize: 13))),
                    ],
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
