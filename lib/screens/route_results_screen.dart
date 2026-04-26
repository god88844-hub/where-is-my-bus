// lib/screens/route_results_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/app_provider.dart';
import '../models/bus.dart';
import '../data/vizag_data.dart';
import '../utils/app_theme.dart';
import '../widgets/shared_widgets.dart';
import 'bus_journey_screen.dart';

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
              child: EmptyState(
                'No direct routes found',
                sub: 'Try a nearby boarding or destination stop',
                icon: Icons.route_outlined,
              ),
            )
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
                          ? AppTheme.green.withValues(alpha: 0.4)
                          : AppTheme.amber.withValues(alpha: 0.4),
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
              route: route,
              fromStop: from,
              toStop: to,
              color: routeColor,
            ),
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
                            builder: (_) => BusJourneyScreen(
                              bus: bus,
                              stop: from,
                            ),
                          ),
                        ),
                      ))
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
    final fullSegmentStopIds = route.stopIdsBetween(fromStop.id, toStop.id);
    final visibleSegmentStopIds =
        route.visibleStopIdsBetween(fromStop.id, toStop.id);
    final segmentStopIds = visibleSegmentStopIds.isEmpty
        ? <String>[fromStop.id, toStop.id]
        : visibleSegmentStopIds;
    final stops = segmentStopIds.map(VizagStops.resolve).toList();
    final hiddenStopCount = fullSegmentStopIds.isEmpty
        ? 0
        : fullSegmentStopIds.length - stops.length;

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
                    color: isF || isL ? color : color.withValues(alpha: 0.4),
                  ),
                ),
                if (!isL)
                  Expanded(
                      child: Container(
                    height: 1.5,
                    color: color.withValues(alpha: 0.35),
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
        if (hiddenStopCount > 0) ...[
          const SizedBox(height: 6),
          Text(
            '$hiddenStopCount sub-stop${hiddenStopCount == 1 ? '' : 's'} hidden',
            style: const TextStyle(
              fontSize: 10,
              color: AppTheme.textMuted,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
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
    final provider = context.watch<AppProvider>();
    final currentStop = VizagStops.resolve(bus.segmentStartIdResolved);
    final etaMins = provider.etaToStopMins(bus, fromStop.id);
    final isAtBoardingStop =
        bus.segmentStartIdResolved == fromStop.id && !bus.isBetweenStops;
    final isApproachingBoardingStop = bus.segmentEndIdResolved == fromStop.id;
    final hasPassedBoardingStop = !isAtBoardingStop &&
        !isApproachingBoardingStop &&
        !bus.isApproachingStop(fromStop.id);
    final statusLabel = isAtBoardingStop
        ? 'At ${fromStop.name}'
        : isApproachingBoardingStop
            ? 'Approaching ${fromStop.name}'
            : hasPassedBoardingStop
                ? 'Passed ${fromStop.name}'
                : 'Passed ${currentStop.name}';
    final etaLabel = hasPassedBoardingStop
        ? 'Passed'
        : isAtBoardingStop || etaMins <= 0
            ? 'Now'
            : '$etaMins min';
    final etaColor = hasPassedBoardingStop
        ? AppTheme.textMuted
        : etaMins <= 3
            ? AppTheme.green
            : AppTheme.amber;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: const BoxDecoration(
          border: Border(
            top: BorderSide(color: AppTheme.divider, width: 0.5),
          ),
        ),
        child: Row(
          children: [
            Icon(Icons.directions_bus_rounded,
                size: 15, color: AppTheme.routeColor(bus.routeNumber)),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    statusLabel,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppTheme.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      BusTypePill(bus.routeBusType),
                      SourcePill(bus.source),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  etaLabel,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: etaColor,
                  ),
                ),
                const SizedBox(height: 4),
                CrowdBar(bus.crowd),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
