import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../data/vizag_data.dart';
import '../models/bus.dart';
import '../services/app_provider.dart';
import '../services/location_service.dart';
import '../utils/app_language.dart';
import '../utils/app_theme.dart';
import '../widgets/shared_widgets.dart';
import '../widgets/staff_mode_access.dart';
import '../widgets/stop_search.dart';
import 'bus_journey_screen.dart';
import 'route_results_screen.dart';
import 'stop_detail_screen.dart';

/// The nearby stop this bus will reach next (if any), with its ETA.
({BusStop stop, int eta})? _nearestApproach(AppProvider p, LiveBus bus) {
  for (final stop in p.nearbyStops) {
    if (!bus.canBoardAtStop(stop.id)) continue;
    return (stop: stop, eta: p.etaToStopMins(bus, stop.id));
  }
  return null;
}

String _crowdTelugu(LiveBus bus) {
  switch (bus.crowd) {
    case BusCrowd.empty:
      return 'ఖాళీ';
    case BusCrowd.moderate:
      return 'మధ్యస్థము';
    case BusCrowd.full:
      return 'నిండిపోయింది';
  }
}

double? _busDistanceKm(AppProvider p, LiveBus bus) {
  final pos = p.userPos;
  if (pos == null) return null;
  return LocationService.distanceKm(pos.latitude, pos.longitude, bus.lat, bus.lng);
}

/// Live buses sorted closest -> farthest from the user; buses without a
/// usable position go last, freshest first.
List<LiveBus> _busesByDistance(AppProvider p) {
  final list = [...p.buses];
  list.sort((a, b) {
    final da = _busDistanceKm(p, a);
    final db = _busDistanceKm(p, b);
    if (da == null && db == null) {
      return b.lastUpdated.compareTo(a.lastUpdated);
    }
    if (da == null) return 1;
    if (db == null) return -1;
    return da.compareTo(db);
  });
  return list;
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: AppLanguage.instance,
      builder: (context, _) => Consumer<AppProvider>(
        builder: (context, p, _) {
          final lang = AppLanguage.instance;
          return Scaffold(
            backgroundColor: AppTheme.bg,
            body: SafeArea(
              child: CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(
                    child: _TopBar(p: p, lang: lang),
                  ),
                  SliverToBoxAdapter(
                    child: _SearchPanel(p: p, lang: lang),
                  ),
                  if (p.nearbyStops.isNotEmpty)
                    SliverToBoxAdapter(
                      child: _NearbyStopChips(stops: p.nearbyStops),
                    ),
                  SliverToBoxAdapter(
                    child: SectionHeader(
                      lang.t('Live buses', 'లైవ్ బస్సులు'),
                      subtitle: p.hasLocation
                          ? lang.t(
                              '${p.buses.length} on the road · ${p.nearbyBuses.length} near you',
                              'రోడ్డుపై ${p.buses.length} · మీ దగ్గర ${p.nearbyBuses.length}')
                          : lang.t(
                              '${p.buses.length} on the road',
                              'రోడ్డుపై ${p.buses.length}'),
                      action: p.busLoading
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(
                                strokeWidth: 1.5,
                                color: AppTheme.green,
                              ),
                            )
                          : null,
                    ),
                  ),
                  if (p.buses.isEmpty)
                    SliverToBoxAdapter(
                      child: EmptyState(
                        lang.t(
                            'No buses running right now',
                            'ప్రస్తుతం బస్సులు లేవు'),
                        sub: lang.t(
                            'Buses appear here the moment a conductor starts a trip',
                            'కండక్టర్ ట్రిప్ ప్రారంభించగానే బస్సులు ఇక్కడ కనిపిస్తాయి'),
                      ),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, i) {
                            final bus = _busesByDistance(p)[i];
                            final nearby = _nearestApproach(p, bus);
                            return _LiveBusCard(
                              bus: bus,
                              approachStop: nearby?.stop,
                              etaMins: nearby?.eta,
                              distanceKm: _busDistanceKm(p, bus),
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => BusJourneyScreen(
                                    bus: bus,
                                    stop: nearby?.stop ??
                                        VizagStops.resolve(bus.currentStopId),
                                  ),
                                ),
                              ),
                            );
                          },
                          childCount: p.buses.length,
                        ),
                      ),
                    ),
                  const SliverToBoxAdapter(child: SizedBox(height: 100)),
                ],
              ),
            ),

          );
        },
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  final AppProvider p;
  final AppLanguage lang;
  const _TopBar({required this.p, required this.lang});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      color: AppTheme.surface,
      child: Column(
        children: [
          Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Vizag Bus Live',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  Text(
                    'విశాఖ బస్ లైవ్',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppTheme.green.withValues(alpha: 0.8),
                    ),
                  ),
                ],
              ),
              const Spacer(),
              // Language toggle: English / తెలుగు
              Container(
                decoration: BoxDecoration(
                  color: AppTheme.card,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: AppTheme.border, width: 0.5),
                ),
                child: Row(
                  children: [
                    _LangChip(
                      label: 'English',
                      selected: !lang.isTelugu,
                      onTap: () => AppLanguage.instance.setTelugu(false),
                    ),
                    _LangChip(
                      label: 'తెలుగు',
                      selected: lang.isTelugu,
                      onTap: () => AppLanguage.instance.setTelugu(true),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _ModeCard(
                  icon: Icons.people_alt_outlined,
                  title: lang.t('Passenger Mode', 'ప్రయాణికుల మోడ్'),
                  subtitle: lang.t(
                    'Search routes and live buses',
                    'రూట్లు, లైవ్ బస్సుల వెతకండి'),
                  color: AppTheme.blue,
                  active: true,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _ModeCard(
                  icon: Icons.badge_outlined,
                  title: lang.t('Staff Mode', 'స్టాఫ్ మోడ్'),
                  subtitle: lang.t(
                    'Enter password for conductor tracking',
                    'కండక్టర్ ట్రాకింగ్ కోసం పాస్‌వర్డ్ నిల్లండండి'),
                  color: AppTheme.green,
                  onTap: () => showStaffModeAccessSheet(context),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LangChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _LangChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? AppTheme.green : Colors.transparent,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : AppTheme.textSecondary,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _ModeCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final bool active;
  final VoidCallback? onTap;

  const _ModeCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    this.active = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: active ? color.withValues(alpha: 0.12) : AppTheme.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: active ? color.withValues(alpha: 0.35) : AppTheme.border,
            width: active ? 1 : 0.5,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, size: 18, color: color),
                ),
                const Spacer(),
                if (active)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      'Current',
                      style: TextStyle(
                        color: color,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              title,
              style: const TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: const TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 11,
                height: 1.35,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SearchPanel extends StatelessWidget {
  final AppProvider p;
  final AppLanguage lang;
  const _SearchPanel({required this.p, required this.lang});

  void _swapStops() {
    final from = p.fromStop;
    final to = p.toStop;
    p.setFromStop(to);
    p.setToStop(from);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.border, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                lang.t('Find a route', 'మార్గం వెతకండి'),
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const _DotLine(color: AppTheme.green),
              const SizedBox(width: 10),
              Expanded(
                child: StopSearchField(
                  hint: lang.t('From stop', 'ఎక్కడ నుండి'),
                  value: p.fromStop,
                  exclude: p.toStop,
                  onSelected: p.setFromStop,
                ),
              ),
            ],
          ),
          const Padding(
            padding: EdgeInsets.only(left: 6),
            child: _VLine(),
          ),
          Row(
            children: [
              const _DotLine(color: AppTheme.red),
              const SizedBox(width: 10),
              Expanded(
                child: StopSearchField(
                  hint: lang.t('To stop', 'ఎక్కడికి'),
                  value: p.toStop,
                  exclude: p.fromStop,
                  onSelected: p.setToStop,
                ),
              ),
              const SizedBox(width: 10),
              // Swap From <-> To (AbhiBus-style helper for common mistakes).
              SizedBox(
                width: 54,
                height: 54,
                child: OutlinedButton(
                  onPressed: (p.fromStop != null || p.toStop != null)
                      ? _swapStops
                      : null,
                  style: OutlinedButton.styleFrom(
                    padding: EdgeInsets.zero,
                    side: const BorderSide(color: AppTheme.border, width: 0.5),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Icon(
                    Icons.swap_vert,
                    size: 22,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ),
            ],
          ),
          if (p.fromStop != null && p.toStop != null) ...[
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => RouteResultsScreen(
                      from: p.fromStop!,
                      to: p.toStop!,
                    ),
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.green,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                icon: const Icon(Icons.search, size: 20),
                label: Text(
                  lang.t('Search buses', 'బస్సులు వెతకండి'),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
          const SizedBox(height: 14),
          const _RouteNumberQuickSearch(),
        ],
      ),
    );
  }
}

class _RouteNumberQuickSearch extends StatefulWidget {
  const _RouteNumberQuickSearch();

  @override
  State<_RouteNumberQuickSearch> createState() =>
      _RouteNumberQuickSearchState();
}

class _RouteNumberQuickSearchState extends State<_RouteNumberQuickSearch> {
  final _ctrl = TextEditingController();

  void _openRoute() {
    final raw = _ctrl.text.trim().toUpperCase();
    if (raw.isEmpty) return;
    final query = raw.endsWith('-R') ? raw.substring(0, raw.length - 2) : raw;
    final route = VizagRoutes.byNumber(query);
    FocusScope.of(context).unfocus();

    if (route == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppTheme.card,
          content: Text(
            'Route $query not found. Try the route number on the bus.',
            style: const TextStyle(color: AppTheme.textPrimary),
          ),
        ),
      );
      return;
    }

    // Live buses on this route number: open the live journey directly —
    // that is what "where is my bus right now" means.
    final provider = context.read<AppProvider>();
    final liveBuses = provider.buses
        .where((b) => b.routeNumber == route.number)
        .toList()
      ..sort((a, b) => b.lastUpdated.compareTo(a.lastUpdated));

    if (liveBuses.isNotEmpty) {
      final bus = liveBuses.first;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => BusJourneyScreen(
            bus: bus,
            stop: VizagStops.resolve(bus.currentStopId),
          ),
        ),
      );
      return;
    }

    final origin = VizagStops.resolve(route.origin);
    final terminus = VizagStops.resolve(route.terminus);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => RouteResultsScreen(from: origin, to: terminus),
      ),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              AppLanguage.instance.t(
                  'Know the route number?', 'బస్సు నంబర్ తెలుసా?'),
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppTheme.textSecondary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          height: 50,
          decoration: BoxDecoration(
            color: AppTheme.card,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.border, width: 0.5),
          ),
          child: Row(
            children: [
              const SizedBox(width: 14),
              const Icon(
                Icons.directions_bus_outlined,
                size: 20,
                color: AppTheme.textSecondary,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: _ctrl,
                  textCapitalization: TextCapitalization.characters,
                  style: const TextStyle(
                    fontSize: 16,
                    color: AppTheme.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                  decoration: const InputDecoration(
                    hintText: 'e.g. 28K, 10K, 300C',
                    hintStyle: TextStyle(
                      fontSize: 15,
                      color: AppTheme.textMuted,
                      fontWeight: FontWeight.w400,
                    ),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                  onSubmitted: (_) => _openRoute(),
                ),
              ),
              TextButton(
                onPressed: _openRoute,
                style: TextButton.styleFrom(
                  foregroundColor: AppTheme.green,
                  textStyle: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                child: const Text('GO'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DotLine extends StatelessWidget {
  final Color color;
  const _DotLine({required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 12,
      height: 12,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        shape: BoxShape.circle,
        border: Border.all(color: color, width: 2),
      ),
    );
  }
}

class _VLine extends StatelessWidget {
  const _VLine();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1.5,
      height: 8,
      margin: const EdgeInsets.symmetric(vertical: 2),
      color: AppTheme.border,
    );
  }
}

/// Compact live card: route, where the bus is right now, and (when the bus
/// serves a stop near the user) the ETA to that stop. Tap opens the journey.
class _LiveBusCard extends StatelessWidget {
  final LiveBus bus;
  final BusStop? approachStop;
  final int? etaMins;
  final double? distanceKm;
  final VoidCallback onTap;

  const _LiveBusCard({
    required this.bus,
    required this.onTap,
    this.approachStop,
    this.etaMins,
    this.distanceKm,
  });

  String _timeAgo(DateTime t) {
    final diff = DateTime.now().difference(t).inSeconds;
    if (diff < 10) return 'just now';
    if (diff < 60) return '${diff}s ago';
    return '${diff ~/ 60}m ago';
  }

  @override
  Widget build(BuildContext context) {
    final lang = AppLanguage.instance;
    final dist = distanceKm;
    final currentName =
        VizagStops.resolve(bus.segmentStartIdResolved).name;
    final nextId = bus.segmentEndIdResolved;
    final nextName = nextId.isEmpty ? '' : VizagStops.resolve(nextId).name;
    final progressPct = (bus.segmentProgressResolved * 100).round();
    final stale = bus.isStale;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: stale
                ? const Color(0xFFBA7517).withValues(alpha: 0.4)
                : AppTheme.border,
            width: 0.5,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                RouteBadge(bus.routeNumber),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    bus.displayBusIdentity,
                    style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (approachStop != null && etaMins != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.green.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: AppTheme.green.withValues(alpha: 0.4),
                        width: 0.5,
                      ),
                    ),
                    child: Text(
                      '$etaMins min to ${approachStop!.name}',
                      style: const TextStyle(
                        color: AppTheme.green,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: AppTheme.green,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    nextName.isEmpty
                        ? lang.t('At', 'వద్ద') + ' $currentName'
                        : lang.t('Passed', 'దాటింది') + ' $currentName -> '
                            + lang.t('Next', 'తదుపరి') + ': $nextName',
                    style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  '$progressPct%',
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                if (dist != null) ...[
                  const Icon(
                    Icons.near_me_outlined,
                    size: 12,
                    color: AppTheme.textMuted,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    dist < 1
                        ? '${(dist * 1000).round()} ${lang.t('m away', 'మీ దూరంలో')}'
                        : '${dist.toStringAsFixed(1)} ${lang.t('km away', 'కి.మీ దూరంలో')}',
                    style: const TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 10),
                ],
                Text(
                  stale
                      ? lang.t('Last seen', 'చివరిగా కనిపించింది')
                      : lang.t('Updated', 'అప్డేట్'),
                  style: const TextStyle(
                    color: AppTheme.textMuted,
                    fontSize: 11,
                  ),
                ),
                Text(
                  ' ${_timeAgo(bus.lastUpdated)}'
                  ' · ${lang.t(bus.crowdLabel, _crowdTelugu(bus))}'
                  ' · ' + lang.t('tap for live journey', 'లైవ్ జర్నీ కోసం నొక్కండి'),
                  style: const TextStyle(
                    color: AppTheme.textMuted,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _NearbyStopChips extends StatelessWidget {
  final List<BusStop> stops;
  const _NearbyStopChips({required this.stops});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          child: Text(
            AppLanguage.instance.t('Nearby stops', 'సమీపం స్టాప్లు'),
            style: TextStyle(
              fontSize: 12,
              color: AppTheme.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        SizedBox(
          height: 44,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: stops.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, i) {
              final stop = stops[i];
              return GestureDetector(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => StopDetailScreen(stop: stop),
                  ),
                ),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppTheme.card,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: AppTheme.border, width: 0.5),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.place_outlined,
                        size: 16,
                        color: AppTheme.textSecondary,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        stop.name,
                        style: const TextStyle(
                          fontSize: 14,
                          color: AppTheme.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 4),
      ],
    );
  }
}
