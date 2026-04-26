import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/vizag_data.dart';
import '../models/bus.dart';
import '../services/app_provider.dart';
import '../services/route_progress_service.dart';
import '../utils/app_theme.dart';
import '../utils/constants.dart';
import '../widgets/shared_widgets.dart';

class BusJourneyScreen extends StatefulWidget {
  final LiveBus bus;
  final BusStop stop;

  const BusJourneyScreen({
    super.key,
    required this.bus,
    required this.stop,
  });

  @override
  State<BusJourneyScreen> createState() => _BusJourneyScreenState();
}

class _BusJourneyScreenState extends State<BusJourneyScreen>
    with SingleTickerProviderStateMixin {
  final Map<String, GlobalKey> _rowKeys = {};
  final Set<String> _expandedAnchorStopIds = <String>{};
  final ScrollController _timelineScrollController = ScrollController();
  bool _showAllMinorStops = false;
  late final AnimationController _pulseController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1150),
  )..repeat(reverse: true);

  String? _lastAutoScrollRowToken;

  @override
  void dispose() {
    _pulseController.dispose();
    _timelineScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider?>();
    final liveBus =
        provider?.buses.where((b) => b.id == widget.bus.id).firstOrNull ??
            widget.bus;
    final route = liveBus.routeRef ?? widget.bus.routeRef;

    if (route == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Journey')),
        body: const Center(child: Text('Route not found')),
      );
    }

    final currentIdx = route.stopIds.indexOf(liveBus.segmentStartIdResolved);
    final nextIdx = route.stopIds.indexOf(liveBus.segmentEndIdResolved);
    final userStopIdx = route.stopIds.indexOf(widget.stop.id);
    final focusIdx = _focusIndex(
      route: route,
      currentIdx: currentIdx,
      nextIdx: nextIdx,
      liveBus: liveBus,
      userStopIdx: userStopIdx,
    );
    final focusRowToken = focusIdx >= 0 && focusIdx < route.stopIds.length
        ? _rowToken(route.stopIds[focusIdx], focusIdx)
        : '';
    final stopGroups = route.stopGroups;
    final hiddenMinorStopCount =
        route.stopIds.length - route.visibleStopIds.length;
    final autoExpandedAnchorStopIds = _autoExpandedAnchorStopIds(
      route: route,
      stopGroups: stopGroups,
      currentStopId: liveBus.segmentStartIdResolved,
      nextStopId: liveBus.segmentEndIdResolved,
      userStopId: widget.stop.id,
    );
    final timelineEntries = _buildTimelineEntries(
      stopGroups: stopGroups,
      autoExpandedAnchorStopIds: autoExpandedAnchorStopIds,
      expandAllMinorStops: _showAllMinorStops,
    );
    final visibleTimelineEntries = timelineEntries.isEmpty
        ? _fallbackTimelineEntries(route.stopIds)
        : timelineEntries;
    final focusTimelineIndex = visibleTimelineEntries.indexWhere(
        (entry) => _rowToken(entry.stopId, entry.routeIndex) == focusRowToken);

    _scheduleAutoScroll(
      targetRowToken: focusRowToken,
      targetTimelineIndex: focusTimelineIndex,
      timelineEntries: visibleTimelineEntries,
    );

    return Scaffold(
      backgroundColor: _JourneyPalette.canvas,
      appBar: AppBar(
        backgroundColor: _JourneyPalette.headerBlue,
        foregroundColor: Colors.white,
        elevation: 0,
        titleSpacing: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              liveBus.displayBusIdentity,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
            Text(
              '${route.from} -> ${route.to}',
              style: const TextStyle(
                fontSize: 12,
                color: Colors.white70,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            _TopChips(
              liveBus: liveBus,
              route: route,
            ),
            _HeroSummary(
              liveBus: liveBus,
              route: route,
              userStop: widget.stop,
              currentIdx: currentIdx,
              nextIdx: nextIdx,
              userStopIdx: userStopIdx,
              showAllMinorStops: _showAllMinorStops,
              hiddenMinorStopCount: hiddenMinorStopCount,
              onToggleAllStops:
                  route.hasHiddenSubStops ? _toggleAllMinorStops : null,
            ),
            Expanded(
              child: Container(
                margin: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                decoration: BoxDecoration(
                  color: _JourneyPalette.board,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: _JourneyPalette.boardBorder,
                    width: 1,
                  ),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x14000000),
                      blurRadius: 16,
                      offset: Offset(0, 10),
                    ),
                  ],
                ),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  children: [
                    _TimelineHeader(
                      liveBus: liveBus,
                      route: route,
                      showAllMinorStops: _showAllMinorStops,
                      hiddenMinorStopCount: hiddenMinorStopCount,
                      onToggleAllStops:
                          route.hasHiddenSubStops ? _toggleAllMinorStops : null,
                    ),
                    if (liveBus.isStale)
                      const _WarningBanner(
                        text:
                            'Live position is stale. The board will update automatically when the next GPS sample arrives.',
                      ),
                    if (route.hasHiddenSubStops)
                      _WarningBanner(
                        text: _showAllMinorStops
                            ? 'Showing every stop on this run. Tap the live card or route bar to collapse back to major stops.'
                            : 'Major stops are shown first. Tap the live card or route bar to reveal all minor stops.',
                      ),
                    Expanded(
                      child: ListView(
                        controller: _timelineScrollController,
                        padding: const EdgeInsets.only(bottom: 12),
                        children:
                            visibleTimelineEntries.asMap().entries.map((entry) {
                          final timelineIndex = entry.key;
                          final timelineEntry = entry.value;
                          final stopId = timelineEntry.stopId;
                          final stop = VizagStops.resolve(stopId);

                          final rowState = _rowStateForIndex(
                            index: timelineEntry.routeIndex,
                            currentIdx: currentIdx,
                            nextIdx: nextIdx,
                            liveBus: liveBus,
                          );

                          final etaMins = rowState == _JourneyStopState.passed
                              ? null
                              : _etaToStopMins(
                                  provider: provider,
                                  bus: liveBus,
                                  route: route,
                                  stopId: stopId,
                                );
                          final distanceFromOriginKm = _distanceFromOriginKm(
                              route, timelineEntry.routeIndex);
                          final distanceToStopKm =
                              liveBus.distanceToStopKm(stopId);

                          return _JourneyStopRow(
                            key: _rowKeyForStop(
                              stopId,
                              timelineEntry.routeIndex,
                            ),
                            stop: stop,
                            route: route,
                            bus: liveBus,
                            rowState: rowState,
                            etaMins: etaMins,
                            distanceFromOriginKm: distanceFromOriginKm,
                            distanceToStopKm: distanceToStopKm,
                            isUserStop: stop.id == widget.stop.id,
                            isFirst: timelineIndex == 0,
                            isLast: timelineIndex ==
                                visibleTimelineEntries.length - 1,
                            isMinorStop: timelineEntry.isMinorStop,
                            hiddenMinorStopCount:
                                timelineEntry.hiddenMinorStopCount,
                            isExpanded: timelineEntry.isExpanded,
                            onToggleSubStops: _showAllMinorStops ||
                                    timelineEntry.hiddenMinorStopCount == 0
                                ? null
                                : () => _toggleAnchorExpansion(
                                      timelineEntry.anchorStopId,
                                    ),
                            pulseAnimation: CurvedAnimation(
                              parent: _pulseController,
                              curve: Curves.easeInOut,
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  int _focusIndex({
    required BusRoute route,
    required int currentIdx,
    required int nextIdx,
    required LiveBus liveBus,
    required int userStopIdx,
  }) {
    if (userStopIdx >= 0 &&
        currentIdx >= 0 &&
        userStopIdx >= currentIdx &&
        userStopIdx <= currentIdx + 2) {
      return userStopIdx;
    }

    if (liveBus.isBetweenStops &&
        nextIdx >= 0 &&
        nextIdx < route.stopIds.length) {
      return nextIdx;
    }

    if (currentIdx >= 0 && currentIdx < route.stopIds.length) {
      return currentIdx;
    }

    return 0;
  }

  Set<String> _autoExpandedAnchorStopIds({
    required BusRoute route,
    required List<RouteStopGroup> stopGroups,
    required String currentStopId,
    required String nextStopId,
    required String userStopId,
  }) {
    final focusIndices = <int>{
      for (final stopId in [currentStopId, nextStopId, userStopId])
        if (stopId.isNotEmpty) route.stopIds.indexOf(stopId),
    }.where((index) => index >= 0).toSet();

    return {
      for (final group in stopGroups)
        if (group.hasMinorStops &&
            focusIndices.any((index) =>
                index >= group.startIndex &&
                index < group.startIndex + group.stopIds.length))
          group.anchorStopId,
    };
  }

  List<_JourneyTimelineEntry> _buildTimelineEntries({
    required List<RouteStopGroup> stopGroups,
    required Set<String> autoExpandedAnchorStopIds,
    required bool expandAllMinorStops,
  }) {
    final expandedAnchorStopIds = expandAllMinorStops
        ? {
            for (final group in stopGroups) group.anchorStopId,
          }
        : {
            ..._expandedAnchorStopIds,
            ...autoExpandedAnchorStopIds,
          };
    final entries = <_JourneyTimelineEntry>[];

    for (final group in stopGroups) {
      final isExpanded = expandAllMinorStops ||
          expandedAnchorStopIds.contains(group.anchorStopId);
      entries.add(
        _JourneyTimelineEntry(
          stopId: group.anchorStopId,
          routeIndex: group.startIndex,
          anchorStopId: group.anchorStopId,
          isMinorStop: false,
          hiddenMinorStopCount: group.minorStopIds.length,
          isExpanded: isExpanded,
        ),
      );

      if (!isExpanded) continue;

      for (var offset = 1; offset < group.stopIds.length; offset++) {
        entries.add(
          _JourneyTimelineEntry(
            stopId: group.stopIds[offset],
            routeIndex: group.startIndex + offset,
            anchorStopId: group.anchorStopId,
            isMinorStop: true,
            hiddenMinorStopCount: 0,
            isExpanded: true,
          ),
        );
      }
    }

    return entries;
  }

  List<_JourneyTimelineEntry> _fallbackTimelineEntries(List<String> stopIds) {
    return [
      for (var i = 0; i < stopIds.length; i++)
        _JourneyTimelineEntry(
          stopId: stopIds[i],
          routeIndex: i,
          anchorStopId: stopIds[i],
          isMinorStop: false,
          hiddenMinorStopCount: 0,
          isExpanded: true,
        ),
    ];
  }

  void _toggleAllMinorStops() {
    setState(() {
      _showAllMinorStops = !_showAllMinorStops;
    });
  }

  String _rowToken(String stopId, int routeIndex) => '$routeIndex::$stopId';

  GlobalKey _rowKeyForStop(String stopId, int routeIndex) =>
      _rowKeys.putIfAbsent(
        _rowToken(stopId, routeIndex),
        () => GlobalKey(),
      );

  void _toggleAnchorExpansion(String anchorStopId) {
    setState(() {
      if (_expandedAnchorStopIds.contains(anchorStopId)) {
        _expandedAnchorStopIds.remove(anchorStopId);
      } else {
        _expandedAnchorStopIds.add(anchorStopId);
      }
    });
  }

  void _scheduleAutoScroll({
    required String targetRowToken,
    required int targetTimelineIndex,
    required List<_JourneyTimelineEntry> timelineEntries,
    int attempts = 0,
  }) {
    if (targetRowToken.isEmpty || _lastAutoScrollRowToken == targetRowToken) {
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }

      if (!_timelineScrollController.hasClients) {
        if (attempts < 4) {
          _scheduleAutoScroll(
            targetRowToken: targetRowToken,
            targetTimelineIndex: targetTimelineIndex,
            timelineEntries: timelineEntries,
            attempts: attempts + 1,
          );
        }
        return;
      }

      final rowContext = _rowKeys[targetRowToken]?.currentContext;
      if (rowContext != null) {
        _lastAutoScrollRowToken = targetRowToken;
        Scrollable.ensureVisible(
          rowContext,
          alignment: 0.34,
          duration: const Duration(milliseconds: 420),
          curve: Curves.easeOutCubic,
        );
        return;
      }

      if (targetTimelineIndex >= 0) {
        final viewport = _timelineScrollController.position.viewportDimension;
        final targetOffset =
            (_estimatedScrollOffset(timelineEntries, targetTimelineIndex) -
                    (viewport * 0.22))
                .clamp(
          _timelineScrollController.position.minScrollExtent,
          _timelineScrollController.position.maxScrollExtent,
        );
        if ((_timelineScrollController.offset - targetOffset).abs() > 1) {
          _timelineScrollController.jumpTo(targetOffset);
        }
      }

      if (attempts < 4) {
        _scheduleAutoScroll(
          targetRowToken: targetRowToken,
          targetTimelineIndex: targetTimelineIndex,
          timelineEntries: timelineEntries,
          attempts: attempts + 1,
        );
      }
    });
  }

  double _estimatedScrollOffset(
    List<_JourneyTimelineEntry> timelineEntries,
    int targetTimelineIndex,
  ) {
    var offset = 0.0;
    for (var i = 0; i < targetTimelineIndex; i++) {
      offset += timelineEntries[i].isMinorStop ? 108 : 128;
    }
    return offset;
  }

  int _etaToStopMins({
    required AppProvider? provider,
    required LiveBus bus,
    required BusRoute route,
    required String stopId,
  }) {
    if (provider != null) {
      return provider.etaToStopMins(bus, stopId);
    }

    final distanceKm = bus.distanceToStopKm(stopId);
    final busIdx = route.stopIds.indexOf(bus.segmentStartIdResolved);
    final stopIdx = route.stopIds.indexOf(stopId);
    final effectiveSpeed = bus.effectiveSpeedResolvedKmh ??
        RouteProgressService.defaultRouteSpeedKmh(route);

    if (distanceKm != null) {
      final distanceEta = RouteProgressService.etaMinutesForDistance(
        distanceKm: distanceKm,
        route: route,
        effectiveSpeedKmh: effectiveSpeed,
      );
      final intermediateStops = busIdx < 0 || stopIdx < 0
          ? 0
          : (stopIdx - busIdx - 1).clamp(0, route.stopIds.length);
      final dwellMins =
          ((intermediateStops * AppConstants.stopDwellTimeSeconds) / 60).ceil();
      return distanceEta + dwellMins;
    }

    if (busIdx < 0 || stopIdx < 0 || busIdx > stopIdx) {
      return bus.etaToNextStopMins;
    }

    final stopsAway = stopIdx - busIdx;
    return bus.etaToNextStopMins + (stopsAway > 1 ? (stopsAway - 1) * 6 : 0);
  }

  double _distanceFromOriginKm(BusRoute route, int stopIndex) {
    if (stopIndex <= 0) {
      return 0;
    }

    var distanceKm = 0.0;
    for (var i = 0; i < stopIndex; i++) {
      distanceKm += RouteProgressService.segmentDistanceKmForRoute(route, i);
    }
    return distanceKm;
  }

  _JourneyStopState _rowStateForIndex({
    required int index,
    required int currentIdx,
    required int nextIdx,
    required LiveBus liveBus,
  }) {
    if (!liveBus.isBetweenStops && index == currentIdx) {
      return _JourneyStopState.live;
    }

    if (liveBus.isBetweenStops && index == nextIdx) {
      return _JourneyStopState.approaching;
    }

    if (currentIdx >= 0 &&
        (index < currentIdx ||
            (liveBus.isBetweenStops && index <= currentIdx))) {
      return _JourneyStopState.passed;
    }

    return _JourneyStopState.future;
  }
}

enum _JourneyStopState { passed, live, approaching, future }

class _JourneyTimelineEntry {
  const _JourneyTimelineEntry({
    required this.stopId,
    required this.routeIndex,
    required this.anchorStopId,
    required this.isMinorStop,
    required this.hiddenMinorStopCount,
    required this.isExpanded,
  });

  final String stopId;
  final int routeIndex;
  final String anchorStopId;
  final bool isMinorStop;
  final int hiddenMinorStopCount;
  final bool isExpanded;
}

class _TopChips extends StatelessWidget {
  final LiveBus liveBus;
  final BusRoute route;

  const _TopChips({
    required this.liveBus,
    required this.route,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: _JourneyPalette.headerBlue,
      padding: const EdgeInsets.fromLTRB(14, 4, 14, 18),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _ChipPill(
              icon: Icons.today_outlined,
              label: _dateLabel(DateTime.now()),
            ),
            const SizedBox(width: 8),
            _ChipPill(
              icon: Icons.my_location_outlined,
              label: liveBus.sourceLabel,
            ),
            const SizedBox(width: 8),
            _ChipPill(
              icon: Icons.directions_bus_filled_outlined,
              label: route.busType.label,
            ),
            const SizedBox(width: 8),
            _ChipPill(
              icon: Icons.groups_2_outlined,
              label: liveBus.crowdLabel,
            ),
          ],
        ),
      ),
    );
  }

  static String _dateLabel(DateTime date) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${months[date.month - 1]} ${date.day}';
  }
}

class _ChipPill extends StatelessWidget {
  final IconData icon;
  final String label;

  const _ChipPill({
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.22),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.white),
          const SizedBox(width: 7),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroSummary extends StatelessWidget {
  final LiveBus liveBus;
  final BusRoute route;
  final BusStop userStop;
  final int currentIdx;
  final int nextIdx;
  final int userStopIdx;
  final bool showAllMinorStops;
  final int hiddenMinorStopCount;
  final VoidCallback? onToggleAllStops;

  const _HeroSummary({
    required this.liveBus,
    required this.route,
    required this.userStop,
    required this.currentIdx,
    required this.nextIdx,
    required this.userStopIdx,
    required this.showAllMinorStops,
    required this.hiddenMinorStopCount,
    this.onToggleAllStops,
  });

  @override
  Widget build(BuildContext context) {
    final lastPassedStop = VizagStops.resolve(
      liveBus.segmentStartIdResolved,
      fallbackName: route.from,
    );
    final nextStop =
        nextIdx >= 0 ? VizagStops.resolve(route.stopIds[nextIdx]) : null;
    final focusStop = nextStop ??
        lastPassedStop;
    final stopsAway = userStopIdx < 0 || currentIdx < 0
        ? 0
        : (userStopIdx - currentIdx).clamp(0, route.stopIds.length);
    final remainingKm = liveBus.remainingRouteKm?.toStringAsFixed(1) ?? '--';
    final totalRouteKm = RouteProgressService.routeDistanceKm(route);
    final routeProgressPct = totalRouteKm <= 0
        ? null
        : (((totalRouteKm - (liveBus.remainingRouteKm ?? totalRouteKm)) /
                    totalRouteKm)
                .clamp(0.0, 1.0) *
            100)
            .round();
    final nextEta = liveBus.etaToNextStopMins <= 0
        ? 'Now'
        : '${liveBus.etaToNextStopMins} min';
    final age = DateTime.now().difference(liveBus.lastUpdated);
    final lastUpdated =
        age.inSeconds < 60 ? '${age.inSeconds}s ago' : '${age.inMinutes}m ago';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onToggleAllStops,
        borderRadius: BorderRadius.circular(22),
        child: Container(
          margin: const EdgeInsets.fromLTRB(14, 14, 14, 14),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: _JourneyPalette.boardBorder),
            boxShadow: const [
              BoxShadow(
                color: Color(0x16000000),
                blurRadius: 14,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  RouteBadge(route.number),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${route.from} -> ${route.to}',
                          style: const TextStyle(
                            color: _JourneyPalette.ink,
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          liveBus.isBetweenStops
                              ? 'Last passed ${lastPassedStop.name} · Next ${focusStop.name}'
                              : 'Bus is tracking at ${lastPassedStop.name}',
                          style: const TextStyle(
                            color: _JourneyPalette.muted,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SourcePill(liveBus.source),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: _StatTile(
                      label: 'Your Stop',
                      value: stopsAway == 0 ? 'Here' : '$stopsAway away',
                      accent: _JourneyPalette.headerBlue,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _StatTile(
                      label: 'Next ETA',
                      value: nextEta,
                      accent: AppTheme.green,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _StatTile(
                      label: 'Progress',
                      value: routeProgressPct == null
                          ? '$remainingKm km'
                          : '$routeProgressPct%',
                      accent: AppTheme.amber,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  BusTypePill(liveBus.routeBusType),
                  const SizedBox(width: 10),
                  CrowdBar(liveBus.crowd),
                  const Spacer(),
                  Text(
                    'Updated $lastUpdated',
                    style: const TextStyle(
                      color: _JourneyPalette.subtle,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _JourneyPalette.softBlue,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  userStop.id == liveBus.segmentStartIdResolved &&
                          !liveBus.isBetweenStops
                      ? 'Bus is currently at your selected stop.'
                      : userStopIdx >= 0 &&
                              currentIdx >= 0 &&
                              userStopIdx >= currentIdx
                          ? '${userStop.name} is still ahead on this trip. Last passed ${lastPassedStop.name}; next stop ${focusStop.name}.'
                          : '${userStop.name} has already been passed on this run.',
                  style: const TextStyle(
                    color: _JourneyPalette.ink,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (onToggleAllStops != null) ...[
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: _JourneyPalette.canvas,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: _JourneyPalette.boardBorder),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        showAllMinorStops
                            ? Icons.alt_route
                            : Icons.location_searching,
                        color: _JourneyPalette.liveBlue,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          showAllMinorStops
                              ? 'Showing all stops. Tap to return to the major-stop view.'
                              : 'Tap this live card to reveal $hiddenMinorStopCount minor stops too.',
                          style: const TextStyle(
                            color: _JourneyPalette.ink,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(
                        showAllMinorStops
                            ? Icons.unfold_less
                            : Icons.unfold_more,
                        color: _JourneyPalette.liveBlue,
                        size: 18,
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  final String label;
  final String value;
  final Color accent;

  const _StatTile({
    required this.label,
    required this.value,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: _JourneyPalette.muted,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            value,
            style: TextStyle(
              color: accent,
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _TimelineHeader extends StatelessWidget {
  final LiveBus liveBus;
  final BusRoute route;
  final bool showAllMinorStops;
  final int hiddenMinorStopCount;
  final VoidCallback? onToggleAllStops;

  const _TimelineHeader({
    required this.liveBus,
    required this.route,
    required this.showAllMinorStops,
    required this.hiddenMinorStopCount,
    this.onToggleAllStops,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: _JourneyPalette.boardHeader,
      child: InkWell(
        onTap: onToggleAllStops,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              const SizedBox(
                width: 66,
                child: Text(
                  'ETA',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 38),
              Expanded(
                child: Text(
                  '${_weekdayLabel(DateTime.now())} · ${route.name}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (onToggleAllStops != null) ...[
                Icon(
                  showAllMinorStops ? Icons.unfold_less : Icons.unfold_more,
                  color: Colors.white70,
                  size: 18,
                ),
                const SizedBox(width: 6),
                Text(
                  showAllMinorStops ? 'Major' : 'All $hiddenMinorStopCount',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(width: 12),
              ],
              const Text(
                'KM',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _weekdayLabel(DateTime date) {
    const weekdays = [
      'Mon',
      'Tue',
      'Wed',
      'Thu',
      'Fri',
      'Sat',
      'Sun',
    ];
    return '${weekdays[date.weekday - 1]} ${date.day}';
  }
}

class _WarningBanner extends StatelessWidget {
  final String text;

  const _WarningBanner({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: const Color(0xFFFFF3D6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.info_outline,
            size: 16,
            color: AppTheme.amber,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: _JourneyPalette.ink,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _JourneyStopRow extends StatelessWidget {
  final BusStop stop;
  final BusRoute route;
  final LiveBus bus;
  final _JourneyStopState rowState;
  final int? etaMins;
  final double distanceFromOriginKm;
  final double? distanceToStopKm;
  final bool isUserStop;
  final bool isFirst;
  final bool isLast;
  final bool isMinorStop;
  final int hiddenMinorStopCount;
  final bool isExpanded;
  final VoidCallback? onToggleSubStops;
  final Animation<double> pulseAnimation;

  const _JourneyStopRow({
    super.key,
    required this.stop,
    required this.route,
    required this.bus,
    required this.rowState,
    required this.etaMins,
    required this.distanceFromOriginKm,
    required this.distanceToStopKm,
    required this.isUserStop,
    required this.isFirst,
    required this.isLast,
    required this.isMinorStop,
    required this.hiddenMinorStopCount,
    required this.isExpanded,
    this.onToggleSubStops,
    required this.pulseAnimation,
  });

  @override
  Widget build(BuildContext context) {
    final highlight = rowState == _JourneyStopState.live ||
        rowState == _JourneyStopState.approaching;
    final rowColor = highlight
        ? _JourneyPalette.currentRow
        : rowState == _JourneyStopState.passed
            ? _JourneyPalette.pastRow
            : Colors.transparent;
    final titleColor = rowState == _JourneyStopState.passed
        ? _JourneyPalette.subtle
        : _JourneyPalette.ink;
    final etaLabel = _etaLabel();
    final statusLabel = _statusLabel();
    final progressLabel = _progressLabel();
    final toggleLabel = hiddenMinorStopCount == 0
        ? null
        : isExpanded
            ? 'Hide $hiddenMinorStopCount sub-stop${hiddenMinorStopCount == 1 ? '' : 's'}'
            : 'Show $hiddenMinorStopCount sub-stop${hiddenMinorStopCount == 1 ? '' : 's'}';
    final minRowHeight = isMinorStop ? 92.0 : 108.0;

    return Material(
      color: rowColor,
      child: InkWell(
        onTap: onToggleSubStops,
        child: Padding(
          padding: EdgeInsets.fromLTRB(
              16, isMinorStop ? 8 : 10, 16, isMinorStop ? 8 : 10),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: minRowHeight),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    width: 66,
                    child: Center(
                      child: Text(
                        etaLabel,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: rowState == _JourneyStopState.passed
                              ? _JourneyPalette.subtle
                              : highlight
                                  ? _JourneyPalette.liveBlue
                                  : _JourneyPalette.ink,
                          fontSize: isMinorStop ? 12 : 13,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 38,
                    child: Column(
                      children: [
                        Expanded(
                          child: Container(
                            width: 3,
                            color: isFirst
                                ? Colors.transparent
                                : _connectorColor(),
                          ),
                        ),
                        _TimelineMarker(
                          rowState: rowState,
                          pulseAnimation: pulseAnimation,
                          isMinorStop: isMinorStop,
                        ),
                        Expanded(
                          child: Container(
                            width: 3,
                            color:
                                isLast ? Colors.transparent : _connectorColor(),
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(width: isMinorStop ? 20 : 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                stop.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: titleColor,
                                  fontSize:
                                      isMinorStop ? 13 : (highlight ? 15 : 14),
                                  fontWeight: isMinorStop
                                      ? FontWeight.w700
                                      : FontWeight.w800,
                                ),
                              ),
                            ),
                            if (onToggleSubStops != null)
                              Icon(
                                isExpanded
                                    ? Icons.expand_less
                                    : Icons.expand_more,
                                size: 18,
                                color: _JourneyPalette.liveBlue,
                              ),
                            if (isUserStop)
                              Container(
                                margin: const EdgeInsets.only(left: 8),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 9,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: AppTheme.green.withValues(alpha: 0.13),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: const Text(
                                  'Your stop',
                                  style: TextStyle(
                                    color: AppTheme.green,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        if (stop.nameTelugu.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            stop.nameTelugu,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: _JourneyPalette.muted,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                        const SizedBox(height: 5),
                        Text(
                          '${distanceFromOriginKm.toStringAsFixed(1)} km from ${route.from}',
                          style: const TextStyle(
                            color: _JourneyPalette.subtle,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          children: [
                            _RowTag(
                              label: statusLabel,
                              color: _statusColor(),
                            ),
                            if (progressLabel != null)
                              _RowTag(
                                label: progressLabel,
                                color: _JourneyPalette.liveBlue,
                              ),
                            if (isMinorStop)
                              const _RowTag(
                                label: 'Sub-stop',
                                color: _JourneyPalette.muted,
                              ),
                            if (toggleLabel != null)
                              _RowTag(
                                label: toggleLabel,
                                color: _JourneyPalette.liveBlue,
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 48,
                    child: Center(
                      child: Text(
                        distanceFromOriginKm.round().toString(),
                        style: TextStyle(
                          color: rowState == _JourneyStopState.passed
                              ? _JourneyPalette.subtle
                              : _JourneyPalette.ink,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Color _connectorColor() {
    return switch (rowState) {
      _JourneyStopState.passed => _JourneyPalette.trackPast,
      _JourneyStopState.live ||
      _JourneyStopState.approaching =>
        _JourneyPalette.trackLive,
      _JourneyStopState.future => _JourneyPalette.trackFuture,
    };
  }

  String _etaLabel() {
    return switch (rowState) {
      _JourneyStopState.passed => '--',
      _JourneyStopState.live => 'Now',
      _JourneyStopState.approaching =>
        etaMins == null || etaMins! <= 0 ? 'Next' : '~${etaMins}m',
      _JourneyStopState.future =>
        etaMins == null || etaMins! <= 0 ? '--' : '~${etaMins}m',
    };
  }

  String _statusLabel() {
    return switch (rowState) {
      _JourneyStopState.passed => 'Passed',
      _JourneyStopState.live => 'Bus is here',
      _JourneyStopState.approaching => 'Approaching next',
      _JourneyStopState.future => distanceToStopKm == null
          ? 'Upcoming stop'
          : '${distanceToStopKm!.toStringAsFixed(1)} km ahead',
    };
  }

  String? _progressLabel() {
    if (rowState == _JourneyStopState.live) {
      final speed = (bus.effectiveSpeedResolvedKmh ?? bus.speedKmh).round();
      return '$speed km/h';
    }

    if (rowState == _JourneyStopState.approaching) {
      final progressPct = (bus.segmentProgressResolved * 100).round();
      final distanceLabel = bus.distanceToNextStopKmResolved == null
          ? null
          : '${bus.distanceToNextStopKmResolved!.toStringAsFixed(1)} km left';
      return distanceLabel == null
          ? '$progressPct% from last stop'
          : '$progressPct% · $distanceLabel';
    }

    return null;
  }

  Color _statusColor() {
    return switch (rowState) {
      _JourneyStopState.passed => _JourneyPalette.subtle,
      _JourneyStopState.live => AppTheme.green,
      _JourneyStopState.approaching => _JourneyPalette.liveBlue,
      _JourneyStopState.future => _JourneyPalette.muted,
    };
  }
}

class _TimelineMarker extends StatelessWidget {
  final _JourneyStopState rowState;
  final Animation<double> pulseAnimation;
  final bool isMinorStop;

  const _TimelineMarker({
    required this.rowState,
    required this.pulseAnimation,
    this.isMinorStop = false,
  });

  @override
  Widget build(BuildContext context) {
    switch (rowState) {
      case _JourneyStopState.live:
        return ScaleTransition(
          scale: Tween<double>(begin: 1, end: 1.24).animate(pulseAnimation),
          child: Container(
            width: isMinorStop ? 16 : 18,
            height: isMinorStop ? 16 : 18,
            decoration: BoxDecoration(
              color: AppTheme.green,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 3),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x401D9E75),
                  blurRadius: 12,
                  spreadRadius: 1,
                ),
              ],
            ),
          ),
        );
      case _JourneyStopState.approaching:
        return ScaleTransition(
          scale: Tween<double>(begin: 1, end: 1.16).animate(pulseAnimation),
          child: Container(
            width: isMinorStop ? 14 : 16,
            height: isMinorStop ? 14 : 16,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              border: Border.all(
                color: _JourneyPalette.liveBlue,
                width: 4,
              ),
            ),
          ),
        );
      case _JourneyStopState.passed:
        return Container(
          width: isMinorStop ? 10 : 12,
          height: isMinorStop ? 10 : 12,
          decoration: const BoxDecoration(
            color: _JourneyPalette.trackPast,
            shape: BoxShape.circle,
          ),
        );
      case _JourneyStopState.future:
        return Container(
          width: isMinorStop ? 10 : 12,
          height: isMinorStop ? 10 : 12,
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            border: Border.all(
              color: _JourneyPalette.trackFuture,
              width: 3,
            ),
          ),
        );
    }
  }
}

class _RowTag extends StatelessWidget {
  final String label;
  final Color color;

  const _RowTag({
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _JourneyPalette {
  static const Color canvas = Color(0xFFE7EEF7);
  static const Color headerBlue = Color(0xFF0C63B3);
  static const Color board = Color(0xFFFDFDFE);
  static const Color boardBorder = Color(0xFFD5DEE9);
  static const Color boardHeader = Color(0xFF14202A);
  static const Color ink = Color(0xFF1B2430);
  static const Color muted = Color(0xFF64748B);
  static const Color subtle = Color(0xFF94A3B8);
  static const Color softBlue = Color(0xFFE9F2FF);
  static const Color currentRow = Color(0xFFE3E7EC);
  static const Color pastRow = Color(0xFFF6F8FB);
  static const Color liveBlue = Color(0xFF2E84D6);
  static const Color trackPast = Color(0xFF70B8F3);
  static const Color trackLive = Color(0xFF59A7EE);
  static const Color trackFuture = Color(0xFFD0D7E2);
}
