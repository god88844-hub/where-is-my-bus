// lib/screens/route_results_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/app_provider.dart';
import '../models/bus.dart';
import '../data/vizag_data.dart';
import 'package:url_launcher/url_launcher.dart';

import '../utils/app_language.dart';
import '../utils/app_theme.dart';
import '../widgets/shared_widgets.dart';
import 'bus_journey_screen.dart';

class RouteResultsScreen extends StatelessWidget {
  final BusStop from;
  final BusStop to;
  const RouteResultsScreen({super.key, required this.from, required this.to});

  @override
  Widget build(BuildContext context) {
    final lang = AppLanguage.instance;
    final p = context.watch<AppProvider>();
    final results = p.searchRoutes(from, to);
    final connectingResults = results.isEmpty
        ? p.searchConnectingRoutes(from, to)
        : const <ConnectingRouteResult>[];
    final _ = lang;
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
      body: results.isEmpty && connectingResults.isEmpty
          ? const _NoDataFallback(from: null, to: null)
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (results.isNotEmpty) ...[
                  _ResultsHeader(
                    title: lang.t('Direct buses', 'డఈరెక్ట్ బస్సులు'),
                    subtitle:
                        '${results.length} route${results.length == 1 ? '' : 's'} found',
                  ),
                  ...results.map(
                    (result) => _RouteResultCard(
                      result: result,
                      from: from,
                      to: to,
                    ),
                  ),
                ],
                if (results.isEmpty && connectingResults.isNotEmpty) ...[
                  _ResultsHeader(
                    title: lang.t('Connecting buses', 'కనెక్టింగ్ బస్సులు'),
                    subtitle: lang.t(
                      'No direct bus found. Transfer options are sorted by ETA.',
                      'డఈరెక్ట్ బస్సు లేదు. బదలి ఎక్కడికి ఎట్టి తక్కువ క్రಮం లో చూపించబడతాయి.',
                    ),
                  ),
                  ...connectingResults.map(
                    (result) => _ConnectingRouteCard(result: result),
                  ),
                ],
              ],
            ),
    );
  }
}

class _ResultsHeader extends StatelessWidget {
  final String title;
  final String subtitle;

  const _ResultsHeader({
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
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

class _ConnectingRouteCard extends StatelessWidget {
  final ConnectingRouteResult result;

  const _ConnectingRouteCard({required this.result});

  @override
  Widget build(BuildContext context) {
    final transferSummary = result.transferStops.map((s) => s.name).toList();
    final transferLabel = result.changeCount == 1
        ? 'Change at ${transferSummary.first}'
        : 'Change ${result.changeCount} times';
    final transferStopsLabel = result.changeCount <= 1
        ? null
        : transferSummary.length <= 2
            ? transferSummary.join(' → ')
            : '${transferSummary.take(2).join(' → ')} +${transferSummary.length - 2}';

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
          Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          for (var i = 0; i < result.legs.length; i++) ...[
                            RouteBadge(
                              result.legs[i].route.number,
                              fontSize: 13,
                            ),
                            if (i < result.legs.length - 1)
                              const Icon(
                                Icons.arrow_forward_rounded,
                                size: 16,
                                color: AppTheme.textMuted,
                              ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        transferLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      Text(
                        transferStopsLabel ??
                            '${result.totalStopCount} stops · ${result.changeCount} ${result.changeCount == 1 ? 'change' : 'changes'}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                _EtaBadge(
                  mins: result.totalEtaMins,
                  label: 'total',
                  urgent: result.totalEtaMins <= 45,
                ),
              ],
            ),
          ),
          const Divider(color: AppTheme.divider, height: 1),
          ..._buildLegRows(context),
        ],
      ),
    );
  }

  List<Widget> _buildLegRows(BuildContext context) {
    final rows = <Widget>[];
    for (var i = 0; i < result.legs.length; i++) {
      final leg = result.legs[i];
      final trackBus = _trackableBusForLeg(leg);
      if (i > 0) {
        rows.add(
          _TransferRow(
            stop: result.transferStops[i - 1],
            waitMins: result.transferWaitMinsByLeg[i - 1],
          ),
        );
      }

      rows.add(
        _ConnectionLegRow(
          legNumber: i + 1,
          leg: leg,
          trailingLabel: i == 0
              ? 'Board in ${leg.nextBusEtaMins} min'
              : 'Wait ~${result.transferWaitMinsByLeg[i - 1]} min',
          onTap: trackBus == null
              ? null
              : () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => BusJourneyScreen(
                        bus: trackBus,
                        stop: leg.fromStop,
                      ),
                    ),
                  ),
        ),
      );
    }
    return rows;
  }
}

class _ConnectionLegRow extends StatelessWidget {
  final int legNumber;
  final RouteResult leg;
  final String trailingLabel;
  final VoidCallback? onTap;

  const _ConnectionLegRow({
    required this.legNumber,
    required this.leg,
    required this.trailingLabel,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final routeColor = AppTheme.routeColor(leg.route.number);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          child: Row(
            children: [
              Container(
                width: 24,
                height: 24,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: routeColor.withValues(alpha: 0.13),
                  shape: BoxShape.circle,
                ),
                child: Text(
                  '$legNumber',
                  style: TextStyle(
                    color: routeColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              RouteBadge(leg.route.number),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${leg.fromStop.name} → ${leg.toStop.name}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '~${leg.rideMins} min ride · ${leg.stopCount} stops',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    trailingLabel,
                    textAlign: TextAlign.right,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.amber,
                    ),
                  ),
                  if (onTap != null) ...[
                    const SizedBox(height: 4),
                    const Icon(
                      Icons.chevron_right_rounded,
                      size: 16,
                      color: AppTheme.textMuted,
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TransferRow extends StatelessWidget {
  final BusStop stop;
  final int waitMins;

  const _TransferRow({
    required this.stop,
    required this.waitMins,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
      decoration: const BoxDecoration(
        border: Border(
          top: BorderSide(color: AppTheme.divider, width: 0.5),
          bottom: BorderSide(color: AppTheme.divider, width: 0.5),
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.transfer_within_a_station_rounded,
            size: 16,
            color: AppTheme.green,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Change buses at ${stop.name}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 12,
                color: AppTheme.textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '~$waitMins min wait',
            style: const TextStyle(
              fontSize: 11,
              color: AppTheme.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _EtaBadge extends StatelessWidget {
  final int mins;
  final String label;
  final bool urgent;

  const _EtaBadge({
    required this.mins,
    required this.label,
    required this.urgent,
  });

  @override
  Widget build(BuildContext context) {
    final color = urgent ? AppTheme.green : AppTheme.amber;
    final bg = urgent ? AppTheme.greenDim : AppTheme.amberDim;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: color.withValues(alpha: 0.4),
          width: 0.5,
        ),
      ),
      child: Column(
        children: [
          Text(
            '$mins',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 9,
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

LiveBus? _trackableBusForLeg(RouteResult leg) {
  for (final bus in leg.liveBuses) {
    if (bus.isApproachingStop(leg.fromStop.id)) {
      return bus;
    }
  }
  return null;
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


/// Shown when neither a direct nor a connecting bus exists in our network:
/// offers a Google Maps transit search for the same trip.
class _NoDataFallback extends StatelessWidget {
  final dynamic from;
  final dynamic to;

  const _NoDataFallback({required this.from, required this.to});

  Future<void> _openGoogleMaps() async {
    final originPart =
        from != null ? '${from.lat},${from.lng}' : 'Visakhapatnam';
    final destPart =
        to != null ? '${to.lat},${to.lng}' : 'Visakhapatnam';
    final url = 'https://www.google.com/maps/dir/?api=1'
        '&origin=${Uri.encodeComponent(originPart)}'
        '&destination=${Uri.encodeComponent(destPart)}'
        '&travelmode=transit';
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = AppLanguage.instance;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.route_outlined,
              size: 44,
              color: AppTheme.textMuted,
            ),
            const SizedBox(height: 14),
            Text(
              lang.t(
                'No bus data for this destination',
                'ఈ గమ్యాలకు బస్సు సమాచారం లేదు'),
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              lang.t(
                'Our network does not cover it yet. Try a nearby stop, or search the trip in Google Maps.',
                'మా నెట్వర్క్ ఇంకా అక్కడికి విస్తరించదు. పక్క స్టాప్ ప్రయత్నించండి లేదా Google Maps లో వెతకండి.'),
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 13,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 18),
            OutlinedButton.icon(
              onPressed: _openGoogleMaps,
              icon: const Icon(Icons.map_outlined, size: 18),
              label: Text(
                lang.t('Open in Google Maps', 'Google Maps తెరవండి'),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.green,
                side: const BorderSide(color: AppTheme.green, width: 0.8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
