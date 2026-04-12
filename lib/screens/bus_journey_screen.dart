// lib/screens/bus_journey_screen.dart
// The stop-by-stop timeline view — inspired by the train tracking UI

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/bus.dart';
import '../data/vizag_data.dart';
import '../services/app_provider.dart';
import '../utils/app_theme.dart';
import '../widgets/shared_widgets.dart';

class BusJourneyScreen extends StatelessWidget {
  final LiveBus bus;
  final BusStop stop; // the stop the user is at

  const BusJourneyScreen({super.key, required this.bus, required this.stop});

  @override
  Widget build(BuildContext context) {
    final p = context.watch<AppProvider>();
    // Get latest bus data (refreshes every tick)
    final liveBus = p.buses.where((b) => b.id == bus.id).firstOrNull ?? bus;
    final route = liveBus.routeRef ?? bus.routeRef;

    if (route == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Journey')),
        body: const Center(child: Text('Route not found')),
      );
    }

    final currentIdx = route.stopIds.indexOf(liveBus.segmentStartIdResolved);
    final nextIdx = route.stopIds.indexOf(liveBus.segmentEndIdResolved);
    final userStopIdx = route.stopIds.indexOf(stop.id);
    final timelineChildren = <Widget>[];

    for (final entry in route.stopIds.asMap().entries) {
      final idx = entry.key;
      final stopId = entry.value;
      final s = VizagStops.get(stopId);
      if (s == null) continue;

      final isBusHere = idx == currentIdx && !liveBus.isBetweenStops;
      final isCurrentSegmentStart = idx == currentIdx && liveBus.isBetweenStops;
      final isNextStop = idx == nextIdx && !isBusHere;
      final isPassed = currentIdx >= 0 && idx < currentIdx;
      final isUserStop = stopId == stop.id;
      final isFirst = idx == 0;
      final isLast = idx == route.stopIds.length - 1;

      int? eta;
      if (!isPassed && !isBusHere && currentIdx >= 0) {
        eta = p.etaToStopMins(liveBus, stopId);
      }

      timelineChildren.add(
        _StopRow(
          stop: s,
          isBusHere: isBusHere,
          isCurrentSegmentStart: isCurrentSegmentStart,
          isNextStop: isNextStop,
          isPassed: isPassed,
          isUserStop: isUserStop,
          isFirst: isFirst,
          isLast: isLast,
          eta: eta,
          bus: liveBus,
          routeColor: AppTheme.routeColor(route.number),
        ),
      );

      if (liveBus.isBetweenStops &&
          idx == currentIdx &&
          nextIdx == currentIdx + 1 &&
          nextIdx >= 0) {
        timelineChildren.add(
          _BetweenStopsRow(
            bus: liveBus,
            nextStop: VizagStops.get(route.stopIds[nextIdx]),
            routeColor: AppTheme.routeColor(route.number),
          ),
        );
      }
    }

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
          Row(children: [
            RouteBadge(route.number),
            const SizedBox(width: 8),
            Text(route.name.split('→').last.trim(),
                style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.textPrimary)),
          ]),
          Text(route.nameTelugu,
              style:
                  const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
        ]),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 14),
            child: SourcePill(liveBus.source),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(0.5),
          child: Divider(height: 0.5, color: AppTheme.divider),
        ),
      ),
      body: ListView(
        children: [
          // ── Summary card ──
          _SummaryCard(
              bus: liveBus,
              userStop: stop,
              currentIdx: currentIdx,
              userStopIdx: userStopIdx,
              route: route,
              etaToUserStopMins: p.etaToStopMins(liveBus, stop.id)),

          // ── Timeline ──
          const SectionHeader('Stop timeline'),

          ...timelineChildren,

          const SizedBox(height: 40),
        ],
      ),
    );
  }
}

// ── Summary card ──────────────────────────────────────────────────
class _SummaryCard extends StatelessWidget {
  final LiveBus bus;
  final BusStop userStop;
  final int currentIdx;
  final int userStopIdx;
  final BusRoute route;
  final int etaToUserStopMins;

  const _SummaryCard({
    required this.bus,
    required this.userStop,
    required this.currentIdx,
    required this.userStopIdx,
    required this.route,
    required this.etaToUserStopMins,
  });

  @override
  Widget build(BuildContext context) {
    final stopsAway = (userStopIdx - currentIdx).clamp(0, 99);
    final eta = stopsAway == 0 ? 0 : etaToUserStopMins;
    final color = AppTheme.routeColor(bus.routeNumber);
    final currentStop = VizagStops.get(bus.segmentStartIdResolved);
    final nextStop = VizagStops.get(bus.segmentEndIdResolved);
    final age = DateTime.now().difference(bus.lastUpdated);
    final lastUpdated =
        age.inSeconds < 60 ? '${age.inSeconds}s ago' : '${age.inMinutes}m ago';

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.3), width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(Icons.place, size: 14, color: color),
            const SizedBox(width: 6),
            Text('Bus arriving at ${userStop.name}',
                style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.textPrimary)),
          ]),
          const SizedBox(height: 12),
          Row(children: [
            _SummaryChip(
              label: 'ETA',
              value: stopsAway == 0 ? 'HERE' : '$eta min',
              color: eta <= 3 ? AppTheme.green : AppTheme.amber,
            ),
            const SizedBox(width: 10),
            _SummaryChip(
              label: 'Stops away',
              value: '$stopsAway',
              color: color,
            ),
            const SizedBox(width: 10),
            _SummaryChip(
              label: 'Speed',
              value:
                  '${(bus.effectiveSpeedResolvedKmh ?? bus.speedKmh).round()} km/h',
              color: AppTheme.textSecondary,
            ),
            if (bus.hasContinuousProgress) ...[
              const SizedBox(width: 10),
              _SummaryChip(
                label: 'Progress',
                value: '${(bus.segmentProgressResolved * 100).round()}%',
                color: color,
              ),
            ],
          ]),
          const SizedBox(height: 12),
          Row(children: [
            CrowdBar(bus.crowd),
            const Spacer(),
            Text('Last updated $lastUpdated',
                style: const TextStyle(
                    fontSize: 11, color: AppTheme.textSecondary)),
            const SizedBox(width: 10),
            if (bus.isStale)
              Row(children: [
                const Icon(Icons.warning_amber_rounded,
                    size: 12, color: AppTheme.amber),
                const SizedBox(width: 4),
                const Text('Location may be outdated',
                    style: TextStyle(fontSize: 11, color: AppTheme.amber)),
              ]),
          ]),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _StatusPill(
                icon: Icons.radio_button_checked,
                label: currentStop == null
                    ? 'Current stop unknown'
                    : bus.isBetweenStops
                        ? 'Last passed: ${currentStop.name}'
                        : 'Current: ${currentStop.name}',
                color: color,
              ),
              _StatusPill(
                icon: Icons.arrow_forward,
                label: nextStop == null
                    ? 'Next stop unavailable'
                    : 'Next: ${nextStop.name}'
                        '${bus.distanceToNextStopKmResolved == null ? '' : ' · ${bus.distanceToNextStopKmResolved!.toStringAsFixed(2)} km'}',
                color: AppTheme.green,
              ),
              _StatusPill(
                icon: Icons.directions_bus_filled_outlined,
                label: bus.busTypeLabel,
                color: bus.routeBusType == BusType.redOrdinary
                    ? const Color(0xFFE24B4A)
                    : Color(bus.routeBusType.colorValue),
              ),
              if (bus.busPlateNumber.isNotEmpty)
                _StatusPill(
                  icon: Icons.badge_outlined,
                  label: bus.busPlateNumber,
                  color: AppTheme.textSecondary,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _StatusPill({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withOpacity(0.2), width: 0.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 5),
          Text(label,
              style: TextStyle(
                  fontSize: 11, color: color, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _SummaryChip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _SummaryChip(
      {required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) => Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.08),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(children: [
            Text(value,
                style: TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w700, color: color)),
            Text(label,
                style: const TextStyle(
                    fontSize: 10, color: AppTheme.textSecondary)),
          ]),
        ),
      );
}

// ── Stop row (timeline item) ──────────────────────────────────────
class _StopRow extends StatelessWidget {
  final BusStop stop;
  final bool isBusHere;
  final bool isCurrentSegmentStart;
  final bool isNextStop;
  final bool isPassed;
  final bool isUserStop;
  final bool isFirst;
  final bool isLast;
  final int? eta;
  final LiveBus bus;
  final Color routeColor;

  const _StopRow({
    required this.stop,
    required this.isBusHere,
    required this.isCurrentSegmentStart,
    required this.isNextStop,
    required this.isPassed,
    required this.isUserStop,
    required this.isFirst,
    required this.isLast,
    required this.eta,
    required this.bus,
    required this.routeColor,
  });

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Timeline column ──
          SizedBox(
            width: 48,
            child: Column(
              children: [
                // Line above
                Expanded(
                  child: Center(
                    child: Container(
                      width: 2,
                      color: isFirst
                          ? Colors.transparent
                          : isPassed || isBusHere
                              ? routeColor
                              : AppTheme.border,
                    ),
                  ),
                ),
                // Dot
                _TimelineDot(
                  isBusHere: isBusHere,
                  isNextStop: isNextStop,
                  isPassed: isPassed,
                  isUserStop: isUserStop,
                  color: routeColor,
                ),
                // Line below
                Expanded(
                  child: Center(
                    child: Container(
                      width: 2,
                      color: isLast
                          ? Colors.transparent
                          : isPassed
                              ? routeColor
                              : AppTheme.border,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── Content ──
          Expanded(
            child: Padding(
              padding:
                  EdgeInsets.fromLTRB(0, isFirst ? 12 : 6, 16, isLast ? 12 : 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Row(children: [
                    Expanded(
                      child: Text(stop.name,
                          style: TextStyle(
                            fontSize: isBusHere ? 15 : 13,
                            fontWeight: isBusHere ||
                                    isCurrentSegmentStart ||
                                    isUserStop ||
                                    isNextStop
                                ? FontWeight.w600
                                : FontWeight.w400,
                            color: isPassed && !isUserStop
                                ? AppTheme.textMuted
                                : AppTheme.textPrimary,
                          )),
                    ),
                    if (eta != null)
                      Text('$eta min',
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color:
                                  eta! <= 3 ? AppTheme.green : AppTheme.amber)),
                    if (isNextStop) ...[
                      const SizedBox(width: 8),
                      Text('Next',
                          style: TextStyle(
                              fontSize: 11,
                              color: routeColor,
                              fontWeight: FontWeight.w600)),
                    ],
                    if (isCurrentSegmentStart) ...[
                      const SizedBox(width: 8),
                      Text('Last passed',
                          style: TextStyle(
                              fontSize: 11,
                              color: routeColor,
                              fontWeight: FontWeight.w600)),
                    ],
                    if (isPassed)
                      const Text('Passed',
                          style: TextStyle(
                              fontSize: 11, color: AppTheme.textMuted)),
                  ]),

                  Text(stop.nameTelugu,
                      style: TextStyle(
                          fontSize: 11,
                          color: isPassed
                              ? AppTheme.textMuted
                              : AppTheme.textSecondary)),

                  // Bus is here card
                  if (isBusHere) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: routeColor.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                            color: routeColor.withOpacity(0.25), width: 0.5),
                      ),
                      child: Row(children: [
                        Icon(Icons.directions_bus_rounded,
                            size: 14, color: routeColor),
                        const SizedBox(width: 6),
                        Text(
                            'Bus is here · ${(bus.effectiveSpeedResolvedKmh ?? bus.speedKmh).round()} km/h',
                            style: TextStyle(
                                fontSize: 12,
                                color: routeColor,
                                fontWeight: FontWeight.w500)),
                        const Spacer(),
                        CrowdBar(bus.crowd),
                      ]),
                    ),
                  ],

                  if (isCurrentSegmentStart) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: routeColor.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                            color: routeColor.withOpacity(0.25), width: 0.5),
                      ),
                      child: Row(children: [
                        Icon(Icons.check_circle_outline,
                            size: 12, color: routeColor),
                        const SizedBox(width: 4),
                        Text('Bus passed this stop',
                            style: TextStyle(
                                fontSize: 11,
                                color: routeColor,
                                fontWeight: FontWeight.w600)),
                      ]),
                    ),
                  ],

                  if (isNextStop) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppTheme.greenDim,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                            color: AppTheme.green.withOpacity(0.25),
                            width: 0.5),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.flag_outlined,
                              size: 12, color: AppTheme.green),
                          SizedBox(width: 4),
                          Text('Bus is heading here next',
                              style: TextStyle(
                                  fontSize: 11,
                                  color: AppTheme.green,
                                  fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                  ],

                  // Your stop card
                  if (isUserStop && !isBusHere) ...[
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppTheme.greenDim,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                            color: AppTheme.green.withOpacity(0.3), width: 0.5),
                      ),
                      child: const Row(children: [
                        Icon(Icons.person_pin_circle,
                            size: 12, color: AppTheme.green),
                        SizedBox(width: 4),
                        Text('Your stop',
                            style: TextStyle(
                                fontSize: 11,
                                color: AppTheme.green,
                                fontWeight: FontWeight.w500)),
                      ]),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BetweenStopsRow extends StatelessWidget {
  final LiveBus bus;
  final BusStop? nextStop;
  final Color routeColor;

  const _BetweenStopsRow({
    required this.bus,
    required this.nextStop,
    required this.routeColor,
  });

  @override
  Widget build(BuildContext context) {
    final progress = bus.segmentProgressResolved;
    final progressPct = (progress * 100).round();
    final nextLabel = nextStop?.name ?? 'next stop';
    final etaLabel =
        bus.etaToNextStopMins <= 0 ? '' : ' · ${bus.etaToNextStopMins} min';
    final distanceLabel = bus.distanceToNextStopKmResolved == null
        ? ''
        : ' · ${bus.distanceToNextStopKmResolved!.toStringAsFixed(2)} km left';

    return SizedBox(
      height: 64,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 48,
            child: LayoutBuilder(
              builder: (context, constraints) {
                const markerSize = 18.0;
                final top = (constraints.maxHeight - markerSize) *
                    progress.clamp(0.0, 1.0);
                return Stack(
                  children: [
                    Center(
                      child: Container(width: 2, color: routeColor),
                    ),
                    Positioned(
                      top: top,
                      left: (48 - markerSize) / 2,
                      child: Container(
                        width: markerSize,
                        height: markerSize,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          border: Border.all(color: routeColor, width: 3),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(0, 0, 16, 0),
              child: Center(
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: routeColor.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: routeColor.withOpacity(0.25), width: 0.5),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Bus is between stops',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: routeColor,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '$progressPct% to $nextLabel$distanceLabel$etaLabel',
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TimelineDot extends StatelessWidget {
  final bool isBusHere;
  final bool isNextStop;
  final bool isPassed;
  final bool isUserStop;
  final Color color;
  const _TimelineDot({
    required this.isBusHere,
    required this.isNextStop,
    required this.isPassed,
    required this.isUserStop,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    if (isBusHere) {
      return Container(
        width: 18,
        height: 18,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white,
          border: Border.all(color: color, width: 3),
        ),
      );
    }
    if (isUserStop) {
      return Container(
        width: 14,
        height: 14,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppTheme.green,
          border: Border.all(color: AppTheme.greenDim, width: 2),
        ),
      );
    }
    if (isNextStop) {
      return Container(
        width: 12,
        height: 12,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white,
          border: Border.all(color: color, width: 2),
        ),
      );
    }
    return Container(
      width: isPassed ? 10 : 8,
      height: isPassed ? 10 : 8,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isPassed ? color : AppTheme.border,
      ),
    );
  }
}
