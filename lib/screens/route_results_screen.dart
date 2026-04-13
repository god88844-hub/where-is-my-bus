// lib/screens/route_results_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/app_provider.dart';
import '../models/bus.dart';
import '../data/vizag_data.dart';
import '../utils/app_theme.dart';
import '../widgets/shared_widgets.dart';
import 'stop_detail_screen.dart';

class RouteResultsScreen extends StatelessWidget {
  final BusStop from;
  final BusStop to;
  const RouteResultsScreen({super.key, required this.from, required this.to});

  @override
  Widget build(BuildContext context) {
    final p = context.watch<AppProvider>();
    final results = p.searchRoutes(from, to);

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
          Text('${from.name} → ${to.name}',
              style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary)),
          Text('${from.nameTelugu} → ${to.nameTelugu}',
              style:
                  const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
        ]),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(0.5),
          child: Divider(height: 0.5, color: AppTheme.divider),
        ),
      ),
      body: results.isEmpty
          ? const Center(
              child: EmptyState('No direct routes found',
                  sub: 'Try selecting different stops',
                  icon: Icons.route_outlined))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: results.length,
              itemBuilder: (_, i) =>
                  _RouteResultCard(result: results[i], from: from, to: to),
            ),
    );
  }
}

class _RouteResultCard extends StatelessWidget {
  final RouteResult result;
  final BusStop from;
  final BusStop to;
  const _RouteResultCard(
      {required this.result, required this.from, required this.to});

  @override
  Widget build(BuildContext context) {
    final route = result.route;
    final routeColor = AppTheme.routeColor(route.number);
    final liveBuses = result.liveBuses;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.border, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ──
          Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                RouteBadge(route.number, fontSize: 13),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(route.name,
                          style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: AppTheme.textPrimary)),
                      Text(route.nameTelugu,
                          style: const TextStyle(
                              fontSize: 11, color: AppTheme.textSecondary)),
                    ],
                  ),
                ),
                // Next bus ETA
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: result.nextBusEtaMins <= 5
                        ? AppTheme.greenDim
                        : AppTheme.amberDim,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: result.nextBusEtaMins <= 5
                          ? AppTheme.green.withOpacity(0.4)
                          : AppTheme.amber.withOpacity(0.4),
                      width: 0.5,
                    ),
                  ),
                  child: Column(children: [
                    Text('${result.nextBusEtaMins}',
                        style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: result.nextBusEtaMins <= 5
                                ? AppTheme.green
                                : AppTheme.amber)),
                    Text('min',
                        style: TextStyle(
                            fontSize: 9,
                            color: result.nextBusEtaMins <= 5
                                ? AppTheme.green
                                : AppTheme.amber)),
                  ]),
                ),
              ],
            ),
          ),

          // ── Mini stop timeline ──
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
            child: _MiniTimeline(
                route: route, fromStop: from, toStop: to, color: routeColor),
          ),

          const Divider(color: AppTheme.divider, height: 1),

          // ── Live buses on this route ──
          if (liveBuses.isEmpty)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(children: [
                const Icon(Icons.schedule, size: 13, color: AppTheme.textMuted),
                const SizedBox(width: 6),
                Text('Every ${route.frequencyMins} min · No live bus data',
                    style: const TextStyle(
                        fontSize: 12, color: AppTheme.textMuted)),
              ]),
            )
          else
            Column(
              children: liveBuses
                  .map((bus) => _LiveBusRow(
                      bus: bus,
                      fromStop: from,
                      onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => StopDetailScreen(stop: from)))))
                  .toList(),
            ),
        ],
      ),
    );
  }
}

// ── Mini inline timeline ───────────────────────────────────────────
class _MiniTimeline extends StatelessWidget {
  final BusRoute route;
  final BusStop fromStop;
  final BusStop toStop;
  final Color color;
  const _MiniTimeline(
      {required this.route,
      required this.fromStop,
      required this.toStop,
      required this.color});

  @override
  Widget build(BuildContext context) {
    final fi = route.stopIds.indexOf(fromStop.id);
    final ti = route.stopIds.indexOf(toStop.id);
    if (fi < 0 || ti < 0 || fi >= ti) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Text(
          'Route stop data unavailable',
          style: TextStyle(fontSize: 11, color: AppTheme.textMuted),
        ),
      );
    }
    final stops = route.stopIds
        .sublist(fi, ti + 1)
        .map((id) => VizagStops.get(id))
        .whereType<BusStop>()
        .toList();
    if (stops.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Text(
          'Stop details not available for this segment',
          style: TextStyle(fontSize: 11, color: AppTheme.textMuted),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Dots + line row ──
        Row(
          children: stops.asMap().entries.map((e) {
            final isF = e.key == 0;
            final isL = e.key == stops.length - 1;
            return Expanded(
              child: Row(children: [
                Container(
                  width: isF || isL ? 10 : 7,
                  height: isF || isL ? 10 : 7,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isF || isL ? color : color.withOpacity(0.4),
                  ),
                ),
                if (!isL)
                  Expanded(
                      child: Container(
                    height: 1.5,
                    color: color.withOpacity(0.35),
                  )),
              ]),
            );
          }).toList(),
        ),
        const SizedBox(height: 4),
        // ── First and last stop names only ──
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Flexible(
              child: Text(
                stops.first.name,
                style: const TextStyle(
                    fontSize: 10,
                    color: AppTheme.textPrimary,
                    fontWeight: FontWeight.w500),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Flexible(
              child: Text(
                stops.last.name,
                style: const TextStyle(
                    fontSize: 10,
                    color: AppTheme.textPrimary,
                    fontWeight: FontWeight.w500),
                textAlign: TextAlign.right,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ── Live bus row inside route card ────────────────────────────────
class _LiveBusRow extends StatelessWidget {
  final LiveBus bus;
  final BusStop fromStop;
  final VoidCallback onTap;
  const _LiveBusRow(
      {required this.bus, required this.fromStop, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final currentStop = VizagStops.get(bus.currentStopId);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: const BoxDecoration(
            border:
                Border(top: BorderSide(color: AppTheme.divider, width: 0.5))),
        child: Row(children: [
          Icon(Icons.directions_bus_rounded,
              size: 14, color: AppTheme.routeColor(bus.routeNumber)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
                currentStop != null ? 'At ${currentStop.name}' : 'En route',
                style: const TextStyle(
                    fontSize: 12, color: AppTheme.textSecondary)),
          ),
          BusTypePill(bus.routeBusType),
          const SizedBox(width: 10),
          CrowdBar(bus.crowd),
          const SizedBox(width: 10),
          SourcePill(bus.source),
        ]),
      ),
    );
  }
}
