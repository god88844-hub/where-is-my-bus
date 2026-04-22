import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/vizag_data.dart';
import '../models/bus.dart';
import '../services/app_provider.dart';
import '../services/route_progress_service.dart';
import '../utils/app_theme.dart';
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
  static const double _rowExtent = 116;

  final ScrollController _scrollController = ScrollController();
  late final AnimationController _pulseController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1150),
  )..repeat(reverse: true);

  int? _lastAutoScrollIndex;

  @override
  void dispose() {
    _pulseController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final liveBus = provider.buses.where((b) => b.id == widget.bus.id).firstOrNull ??
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

    _scheduleAutoScroll(focusIdx);

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
                    _TimelineHeader(liveBus: liveBus, route: route),
                    if (liveBus.isStale)
                      const _WarningBanner(
                        text:
                            'Live position is stale. The board will update automatically when the next GPS sample arrives.',
                      ),
                    Expanded(
                      child: ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.only(bottom: 12),
                        itemExtent: _rowExtent,
                        itemCount: route.stopIds.length,
                        itemBuilder: (context, index) {
                          final stopId = route.stopIds[index];
                          final stop = VizagStops.resolve(stopId);

                          final rowState = _rowStateForIndex(
                            index: index,
                            currentIdx: currentIdx,
                            nextIdx: nextIdx,
                            liveBus: liveBus,
                          );

                          final etaMins = rowState == _JourneyStopState.passed
                              ? null
                              : provider.etaToStopMins(liveBus, stopId);
                          final distanceFromOriginKm =
                              _distanceFromOriginKm(route, index);
                          final distanceToStopKm = liveBus.distanceToStopKm(stopId);

                          return _JourneyStopRow(
                            stop: stop,
                            route: route,
                            bus: liveBus,
                            rowState: rowState,
                            etaMins: etaMins,
                            distanceFromOriginKm: distanceFromOriginKm,
                            distanceToStopKm: distanceToStopKm,
                            isUserStop: stop.id == widget.stop.id,
                            isFirst: index == 0,
                            isLast: index == route.stopIds.length - 1,
                            pulseAnimation: CurvedAnimation(
                              parent: _pulseController,
                              curve: Curves.easeInOut,
                            ),
                          );
                        },
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

    if (liveBus.isBetweenStops && nextIdx >= 0 && nextIdx < route.stopIds.length) {
      return nextIdx;
    }

    if (currentIdx >= 0 && currentIdx < route.stopIds.length) {
      return currentIdx;
    }

    return 0;
  }

  void _scheduleAutoScroll(int targetIndex) {
    if (_lastAutoScrollIndex == targetIndex) {
      return;
    }

    _lastAutoScrollIndex = targetIndex;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) {
        return;
      }

      final viewport = _scrollController.position.viewportDimension;
      final targetOffset = (targetIndex * _rowExtent) - (viewport * 0.34);
      final clampedOffset = targetOffset.clamp(
        _scrollController.position.minScrollExtent,
        _scrollController.position.maxScrollExtent,
      );

      _scrollController.animateTo(
        clampedOffset,
        duration: const Duration(milliseconds: 420),
        curve: Curves.easeOutCubic,
      );
    });
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
        (index < currentIdx || (liveBus.isBetweenStops && index <= currentIdx))) {
      return _JourneyStopState.passed;
    }

    return _JourneyStopState.future;
  }
}

enum _JourneyStopState { passed, live, approaching, future }

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

  const _HeroSummary({
    required this.liveBus,
    required this.route,
    required this.userStop,
    required this.currentIdx,
    required this.nextIdx,
    required this.userStopIdx,
  });

  @override
  Widget build(BuildContext context) {
    final nextStop =
        nextIdx >= 0 ? VizagStops.resolve(route.stopIds[nextIdx]) : null;
    final focusStop = nextStop ??
        VizagStops.resolve(
          liveBus.segmentStartIdResolved,
          fallbackName: route.from,
        );
    final stopsAway = userStopIdx < 0 || currentIdx < 0
        ? 0
        : (userStopIdx - currentIdx).clamp(0, route.stopIds.length);
    final remainingKm = liveBus.remainingRouteKm?.toStringAsFixed(1) ?? '--';
    final nextEta =
        liveBus.etaToNextStopMins <= 0 ? 'Now' : '${liveBus.etaToNextStopMins} min';
    final age = DateTime.now().difference(liveBus.lastUpdated);
    final lastUpdated =
        age.inSeconds < 60 ? '${age.inSeconds}s ago' : '${age.inMinutes}m ago';

    return Container(
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
                          ? 'Approaching ${focusStop.name}'
                          : 'Bus is tracking near ${focusStop.name}',
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
                  label: 'Remain',
                  value: '$remainingKm km',
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
              userStop.id == liveBus.segmentStartIdResolved && !liveBus.isBetweenStops
                  ? 'Bus is currently at your selected stop.'
                  : userStopIdx >= 0 && currentIdx >= 0 && userStopIdx >= currentIdx
                      ? '${userStop.name} is still ahead on this trip.'
                      : '${userStop.name} has already been passed on this run.',
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

  const _TimelineHeader({
    required this.liveBus,
    required this.route,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: _JourneyPalette.boardHeader,
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
          const SizedBox(width: 12),
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
  final Animation<double> pulseAnimation;

  const _JourneyStopRow({
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

    return Container(
      color: rowColor,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
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
                  fontSize: 13,
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
                    color: isFirst ? Colors.transparent : _connectorColor(),
                  ),
                ),
                _TimelineMarker(
                  rowState: rowState,
                  pulseAnimation: pulseAnimation,
                ),
                Expanded(
                  child: Container(
                    width: 3,
                    color: isLast ? Colors.transparent : _connectorColor(),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
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
                          fontSize: highlight ? 15 : 14,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    if (isUserStop)
                      Container(
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
    );
  }

  Color _connectorColor() {
    return switch (rowState) {
      _JourneyStopState.passed => _JourneyPalette.trackPast,
      _JourneyStopState.live || _JourneyStopState.approaching =>
        _JourneyPalette.trackLive,
      _JourneyStopState.future => _JourneyPalette.trackFuture,
    };
  }

  String _etaLabel() {
    return switch (rowState) {
      _JourneyStopState.passed => '--',
      _JourneyStopState.live => 'Now',
      _JourneyStopState.approaching => etaMins == null || etaMins! <= 0
          ? 'Next'
          : '~${etaMins}m',
      _JourneyStopState.future => etaMins == null || etaMins! <= 0
          ? '--'
          : '~${etaMins}m',
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

  const _TimelineMarker({
    required this.rowState,
    required this.pulseAnimation,
  });

  @override
  Widget build(BuildContext context) {
    switch (rowState) {
      case _JourneyStopState.live:
        return ScaleTransition(
          scale: Tween<double>(begin: 1, end: 1.24).animate(pulseAnimation),
          child: Container(
            width: 18,
            height: 18,
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
            width: 16,
            height: 16,
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
          width: 12,
          height: 12,
          decoration: const BoxDecoration(
            color: _JourneyPalette.trackPast,
            shape: BoxShape.circle,
          ),
        );
      case _JourneyStopState.future:
        return Container(
          width: 12,
          height: 12,
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
