// lib/screens/stop_detail_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/app_provider.dart';
import '../data/vizag_data.dart';
import '../utils/app_theme.dart';
import '../widgets/shared_widgets.dart';
import 'bus_journey_screen.dart';

class StopDetailScreen extends StatelessWidget {
  final BusStop stop;
  const StopDetailScreen({super.key, required this.stop});

  @override
  Widget build(BuildContext context) {
    final p       = context.watch<AppProvider>();
    final buses   = p.busesAtStop(stop);
    final routes  = VizagRoutes.servingStop(stop.id);

    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(
        backgroundColor: AppTheme.surface,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back,
              size: 20, color: AppTheme.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(stop.name,
              style: const TextStyle(fontSize: 16,
                  fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
          Text(stop.nameTelugu,
              style: const TextStyle(
                  fontSize: 11, color: AppTheme.textSecondary)),
        ]),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(0.5),
          child: Divider(height: 0.5, color: AppTheme.divider),
        ),
      ),
      body: ListView(
        children: [
          // ── Stats row ──
          _StopStatsRow(busCount: buses.length, routeCount: routes.length),

          // ── Incoming buses ──
          SectionHeader(
            'Buses on the way',
            subtitle: buses.isEmpty
                ? 'No live bus data for this stop'
                : '${buses.length} buses incoming',
          ),

          if (buses.isEmpty)
            const EmptyState(
              'No buses tracked right now',
              sub: 'Scheduled routes are shown below',
              icon: Icons.directions_bus_outlined,
            )
          else
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: buses.map((nb) {
                  final following = p.followingBusCountAtStop(nb);
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      IncomingBusCard(
                        nb,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => BusJourneyScreen(
                              bus: nb.bus,
                              stop: stop,
                            ),
                          ),
                        ),
                      ),
                      if (following > 0)
                        Padding(
                          padding: const EdgeInsets.only(left: 12, bottom: 10),
                          child: Text(
                            '$following more ${nb.bus.routeNumber} bus${following == 1 ? '' : 'es'} after this',
                            style: const TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                    ],
                  );
                }).toList(),
              ),
            ),

          // ── Routes serving this stop ──
          SectionHeader('All routes here',
              subtitle: '${routes.length} routes serve this stop'),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: routes.map((route) => _RouteChip(
                route: route,
                currentStopId: stop.id,
              )).toList(),
            ),
          ),

          const SizedBox(height: 40),
        ],
      ),
    );
  }
}

// ── Stats bar ─────────────────────────────────────────────────────
class _StopStatsRow extends StatelessWidget {
  final int busCount;
  final int routeCount;
  const _StopStatsRow({required this.busCount, required this.routeCount});

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.all(16),
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: AppTheme.surface,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: AppTheme.border, width: 0.5),
    ),
    child: Row(children: [
      _Stat('$busCount', 'buses incoming', AppTheme.green),
      _Divider(),
      _Stat('$routeCount', 'routes', AppTheme.blue),
    ]),
  );
}

class _Stat extends StatelessWidget {
  final String value;
  final String label;
  final Color color;
  const _Stat(this.value, this.label, this.color);

  @override
  Widget build(BuildContext context) => Expanded(
    child: Column(children: [
      Text(value, style: TextStyle(fontSize: 22,
          fontWeight: FontWeight.w700, color: color)),
      Text(label, style: const TextStyle(
          fontSize: 11, color: AppTheme.textSecondary)),
    ]),
  );
}

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
      width: 0.5, height: 32, color: AppTheme.border,
      margin: const EdgeInsets.symmetric(horizontal: 8));
}

// ── Route chip ────────────────────────────────────────────────────
class _RouteChip extends StatelessWidget {
  final BusRoute route;
  final String currentStopId;
  const _RouteChip({required this.route, required this.currentStopId});

  @override
  Widget build(BuildContext context) {
    final color = AppTheme.routeColor(route.number);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.border, width: 0.5),
      ),
      child: Row(children: [
        RouteBadge(route.number),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(route.name,
                style: const TextStyle(fontSize: 13,
                    color: AppTheme.textPrimary, fontWeight: FontWeight.w500)),
            Text(route.nameTelugu,
                style: const TextStyle(fontSize: 11,
                    color: AppTheme.textSecondary)),
          ]),
        ),
        Text('every ${route.frequencyMins}m',
            style: TextStyle(fontSize: 11, color: color)),
      ]),
    );
  }
}
