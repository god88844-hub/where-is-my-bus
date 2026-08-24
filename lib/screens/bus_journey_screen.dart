import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/vizag_data.dart';
import '../models/bus.dart';
import '../services/app_provider.dart';
import '../services/follow_notification_service.dart';
import '../services/route_progress_service.dart';
import '../utils/app_language.dart';
import '../utils/app_theme.dart';
import '../widgets/complaint_sheet.dart';

/// "Where is my Train"-style live journey view.
///
/// One glance answers everything:
///   - which stops the bus already passed,
///   - exactly where the bus is right now (between which stops, % progress),
///   - what comes next and in how many minutes,
///   - when the bus reaches YOUR stop.
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

class _BusJourneyScreenState extends State<BusJourneyScreen> {
  final ScrollController _scrollController = ScrollController();
  bool _autoScrolled = false;
  bool _following = false;

  static const double _rowHeight = 72;
  static const double _busMarkerHeight = 64;

  @override
  void initState() {
    super.initState();
    // Opening a live bus starts the ongoing notification (bus position +
    // next stop) so the passenger can track it from anywhere in the app.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      FollowBusNotification.instance.follow(widget.bus);
      if (mounted) setState(() => _following = true);
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _toggleFollow() async {
    if (_following) {
      await FollowBusNotification.instance.stop();
      if (mounted) setState(() => _following = false);
    } else {
      await FollowBusNotification.instance.follow(widget.bus);
      if (mounted) setState(() => _following = true);
    }
  }

  void _autoScrollToBus(int currentIdx) {
    if (_autoScrolled || currentIdx < 0) return;
    _autoScrolled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      final maxExtent = _scrollController.position.maxScrollExtent;
      final target = (currentIdx * _rowHeight - 100).clamp(0.0, maxExtent);
      _scrollController.jumpTo(target);
    });
  }

  int? _etaFor(LiveBus bus, BusRoute route, int stopIndex) {
    final distanceKm = bus.distanceToStopKm(route.stopIds[stopIndex]);
    if (distanceKm == null || distanceKm <= 0) return null;
    return RouteProgressService.etaMinutesForDistance(
      distanceKm: distanceKm,
      route: route,
      effectiveSpeedKmh: bus.effectiveSpeedResolvedKmh,
    );
  }

  String _timeAgo(DateTime t) {
    final diff = DateTime.now().difference(t).inSeconds;
    if (diff < 10) return 'just now';
    if (diff < 60) return '${diff}s ago';
    return '${diff ~/ 60}m ago';
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
        backgroundColor: AppTheme.bg,
        appBar: AppBar(
          backgroundColor: AppTheme.surface,
          title: const Text('Journey'),
        ),
        body: const Center(
          child: Text(
            'Route not found',
            style: TextStyle(color: AppTheme.textSecondary),
          ),
        ),
      );
    }

    final stopIds = route.stopIds;
    final currentIdx = stopIds.indexOf(liveBus.segmentStartIdResolved);
    final progress = liveBus.segmentProgressResolved;
    final progressPct = (progress * 100).round();
    final userStopIdx = stopIds.indexOf(widget.stop.id);
    final tripToIdx = liveBus.tripToStopId == null ||
            liveBus.tripToStopId!.isEmpty
        ? -1
        : stopIds.indexOf(liveBus.tripToStopId!);

    final nextIdx = currentIdx >= 0 && currentIdx + 1 < stopIds.length
        ? currentIdx + 1
        : -1;
    final nextEta = nextIdx >= 0 ? _etaFor(liveBus, route, nextIdx) : null;
    final nextName = nextIdx >= 0
        ? (VizagStops.get(stopIds[nextIdx])?.name ?? stopIds[nextIdx])
        : '';

    if (currentIdx >= 0) {
      _autoScrollToBus(currentIdx);
    }

    final lang = AppLanguage.instance;
    final speedKmh = (liveBus.effectiveSpeedResolvedKmh ?? liveBus.speedKmh);
    final speedLabel = speedKmh >= 1
        ? '${speedKmh.round()} km/h'
        : 'Stopped';
    final updatedLabel = liveBus.isStale
        ? 'Last seen ${_timeAgo(liveBus.lastUpdated)}'
        : 'Updated ${_timeAgo(liveBus.lastUpdated)}';

    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(
        backgroundColor: const Color(0xFF185FA5),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            tooltip: _following
                ? 'Stop live notification'
                : 'Show live notification',
            icon: Icon(
              _following
                  ? Icons.notifications_active
                  : Icons.notifications_off_outlined,
              size: 20,
            ),
            onPressed: _toggleFollow,
          ),
          IconButton(
            tooltip: 'Report a problem',
            icon: const Icon(Icons.report_problem_outlined, size: 20),
            onPressed: () => ComplaintSheet.show(
              context,
              routeNumber: liveBus.routeNumber,
              busId: liveBus.id,
            ),
          ),
        ],
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              liveBus.displayBusIdentity,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
            Text(
              '${route.from} -> ${route.to}',
              style: const TextStyle(
                fontSize: 12,
                color: Colors.white70,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          // ── Live status strip (the "where is it right now" answer) ──
          Container(
            width: double.infinity,
            color: AppTheme.surface,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: liveBus.isStale
                            ? const Color(0xFFBA7517)
                            : AppTheme.green,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      liveBus.isStale
                          ? lang.t('LIVE (delayed)', 'లైవ్ (ఆలస్యం)')
                          : lang.t('LIVE', 'లైవ్'),
                      style: TextStyle(
                        color: liveBus.isStale
                            ? const Color(0xFFBA7517)
                            : AppTheme.green,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      updatedLabel == 'Updated just now'
                          ? lang.t('Updated just now', 'ఇప్పుడే అప్డేట్ అయింది')
                          : updatedLabel,
                      style: const TextStyle(
                        color: AppTheme.textMuted,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (currentIdx >= 0 && nextIdx >= 0) ...[
                  Text(
                    '${lang.t('Next', 'తదుపరి')}: $nextName',
                    style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '$progressPct% ${lang.t('covered', 'పూర్తయింది')}'
                    '${nextEta != null ? ' · ${lang.t('ETA', 'చేరే సమయం')} $nextEta ${lang.t('min', 'నిమి')}' : ''}'
                    ' · $speedLabel · ${liveBus.crowdLabel}',
                    style: const TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(99),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 6,
                      backgroundColor: AppTheme.card,
                      color: AppTheme.green,
                    ),
                  ),
                ] else ...[
                  Text(
                    lang.t('Waiting for live location...', 'లైవ్ రాకు వేచి ఉంది...'),
                    style: TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ),
          ),
          // ── Stop-by-stop timeline ──
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              itemCount: stopIds.length + 1,
              itemBuilder: (context, i) {
                if (i == currentIdx + 1 && currentIdx >= 0) {
                  return _BusMarkerRow(
                    height: _busMarkerHeight,
                    progressPct: progressPct,
                    nextName: nextName,
                  );
                }
                final stopIndex = i > currentIdx + 1 ? i - 1 : i;
                if (stopIndex >= stopIds.length) {
                  return const SizedBox(height: 24);
                }
                return _StopRow(
                  height: _rowHeight,
                  stopId: stopIds[stopIndex],
                  route: route,
                  state: stopIndex < currentIdx
                      ? _StopRowState.passed
                      : stopIndex == currentIdx
                          ? _StopRowState.current
                          : _StopRowState.upcoming,
                  isFirst: stopIndex == 0,
                  isLast: stopIndex == stopIds.length - 1,
                  isNext: stopIndex == nextIdx,
                  isUserStop: stopIndex == userStopIdx,
                  isTripEnd: stopIndex == tripToIdx,
                  beyondTrip: tripToIdx >= 0 && stopIndex > tripToIdx,
                  eta: stopIndex > currentIdx
                      ? _etaFor(liveBus, route, stopIndex)
                      : null,
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

enum _StopRowState { passed, current, upcoming }

class _BusMarkerRow extends StatelessWidget {
  final double height;
  final int progressPct;
  final String nextName;

  const _BusMarkerRow({
    required this.height,
    required this.progressPct,
    required this.nextName,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      padding: const EdgeInsets.only(left: 16),
      child: Row(
        children: [
          // bus marker on the line
          SizedBox(
            width: 32,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: AppTheme.green,
                    shape: BoxShape.circle,
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x331D9E75),
                        blurRadius: 10,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.directions_bus,
                    size: 20,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            decoration: BoxDecoration(
              color: AppTheme.green.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: AppTheme.green, width: 1),
            ),
            child: Text(
              '${AppLanguage.instance.t('Bus running', 'బస్సు వెలుతోంది')} · $progressPct% ${AppLanguage.instance.t('to', 'కఁ')} $nextName',
              style: const TextStyle(
                color: AppTheme.green,
                fontSize: 13,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StopRow extends StatelessWidget {
  final double height;
  final String stopId;
  final BusRoute route;
  final _StopRowState state;
  final bool isFirst;
  final bool isLast;
  final bool isNext;
  final bool isUserStop;
  final bool isTripEnd;
  final bool beyondTrip;
  final int? eta;

  const _StopRow({
    required this.height,
    required this.stopId,
    required this.route,
    required this.state,
    required this.isFirst,
    required this.isLast,
    required this.isNext,
    required this.isUserStop,
    required this.isTripEnd,
    required this.beyondTrip,
    required this.eta,
  });

  Color get _lineColor {
    if (state == _StopRowState.passed || state == _StopRowState.current) {
      return AppTheme.green;
    }
    return AppTheme.border;
  }

  Color get _dotColor {
    if (state == _StopRowState.passed) return AppTheme.green;
    if (state == _StopRowState.current) return AppTheme.green;
    if (isNext) return const Color(0xFF185FA5);
    return AppTheme.border;
  }

  String get _rightLabel {
    final lang = AppLanguage.instance;
    if (beyondTrip) return lang.t('Not on trip', 'ఈ ట్రిప్ కాదు');
    if (isTripEnd) return lang.t('Trip ends', 'ట్రిప్ ముగింపు');
    if (state == _StopRowState.passed) return lang.t('Done', 'అయిపోయింది');
    if (isNext) {
      return eta != null
          ? '${lang.t('Next', 'తదుపరి')} · $eta ${lang.t('min', 'నిమి')}'
          : lang.t('Next', 'తదుపరి');
    }
    if (state == _StopRowState.upcoming) {
      return eta != null
          ? '${lang.t('ETA', 'చేరే సమయం')} $eta ${lang.t('min', 'నిమి')}'
          : '';
    }
    return '';
  }

  @override
  Widget build(BuildContext context) {
    final stop = VizagStops.get(stopId);
    final name = stop?.name ?? stopId;
    final telugu = stop?.nameTelugu ?? '';
    final highlight = isUserStop || isTripEnd;
    final dimmed = state == _StopRowState.passed || beyondTrip;

    return Container(
      height: height,
      color: highlight ? AppTheme.green.withValues(alpha: 0.08) : null,
      padding: const EdgeInsets.only(left: 16, right: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // marker column
          SizedBox(
            width: 32,
            child: Column(
              children: [
                SizedBox(
                  height: 24,
                  child: isFirst
                      ? const SizedBox()
                      : _HalfLine(color: _lineColor, bottom: true),
                ),
                Container(
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    color: state == _StopRowState.passed
                        ? AppTheme.green
                        : AppTheme.bg,
                    shape: BoxShape.circle,
                    border: Border.all(color: _dotColor, width: 3),
                  ),
                  child: state == _StopRowState.passed
                      ? const Icon(Icons.check,
                          size: 9, color: Colors.white)
                      : null,
                ),
                Expanded(
                  child: isLast
                      ? const SizedBox()
                      : _HalfLine(color: _lineColor, bottom: false),
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: dimmed
                              ? AppTheme.textMuted
                              : AppTheme.textPrimary,
                          fontSize: 15,
                          fontWeight: isNext || highlight
                              ? FontWeight.w800
                              : FontWeight.w600,
                          decoration:
                              beyondTrip ? TextDecoration.lineThrough : null,
                        ),
                      ),
                    ),
                    if (isUserStop) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.green,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          AppLanguage.instance.t('YOUR STOP', 'మీ స్టాప్'),
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                if (telugu.isNotEmpty)
                  Text(
                    telugu,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppTheme.textMuted,
                      fontSize: 11,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                _rightLabel,
                style: TextStyle(
                  color: isNext
                      ? const Color(0xFF185FA5)
                      : dimmed
                          ? AppTheme.textMuted
                          : AppTheme.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (isUserStop && eta != null)
                Text(
                  '$eta min',
                  style: const TextStyle(
                    color: AppTheme.green,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HalfLine extends StatelessWidget {
  final Color color;
  final bool bottom;

  const _HalfLine({required this.color, required this.bottom});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: bottom ? Alignment.topCenter : Alignment.bottomCenter,
      child: Container(width: 3, color: color),
    );
  }
}
