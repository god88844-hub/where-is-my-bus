import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../data/vizag_data.dart';
import '../models/bus.dart';
import '../services/app_provider.dart';
import '../utils/app_theme.dart';
import '../widgets/shared_widgets.dart';
import '../widgets/staff_mode_access.dart';
import 'home_screen.dart';

class DemoDashboardScreen extends StatelessWidget {
  const DemoDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final buses = provider.buses;
    final routes = buses.map((b) => b.routeNumber).toSet().toList()..sort();
    final lastUpdated = _latestUpdate(buses);

    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(
        backgroundColor: AppTheme.surface,
        title: const Text('Vizag Bus Live Demo'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _HeroCard(
            liveBusCount: buses.length,
            routeCount: routes.length,
            lastUpdated: lastUpdated,
          ),
          const SizedBox(height: 16),
          _ActionGrid(
            onOpenPassengerView: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const HomeScreen()),
            ),
            onOpenPassengerHelp: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const HomeScreen()),
            ),
            onOpenStaffMode: () => showStaffModeAccessSheet(
              context,
              title: 'Staff Access',
            ),
          ),
          const SizedBox(height: 18),
          const Text(
            'System overview',
            style: TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          const _OverviewCard(),
          const SizedBox(height: 18),
          SectionHeader(
            'Live tracked buses',
            subtitle: buses.isEmpty
                ? 'No conductor session is active right now'
                : '${buses.length} active live buses',
          ),
          if (buses.isEmpty)
            const EmptyState(
              'No active live buses',
              sub: 'Start one conductor trip to demonstrate live tracking',
            )
          else
            ...buses.map((bus) => _LiveBusTile(bus: bus)),
          const SizedBox(height: 18),
          SectionHeader(
            'Routes currently tracked',
            subtitle: routes.isEmpty
                ? 'No active routes'
                : '${routes.length} routes in live demo',
          ),
          if (routes.isEmpty)
            const EmptyState(
              'No live routes',
              sub: 'Open Staff Mode and start a trip to populate this section',
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: routes.map((routeNumber) {
                final route = VizagRoutes.byNumber(routeNumber);
                return Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppTheme.card,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppTheme.border, width: 0.5),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      RouteBadge(routeNumber),
                      if (route != null) ...[
                        const SizedBox(width: 8),
                        Text(
                          route.busType.label,
                          style: TextStyle(
                            color: Color(route.busType.colorValue),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ],
                  ),
                );
              }).toList(),
            ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  DateTime? _latestUpdate(List<LiveBus> buses) {
    if (buses.isEmpty) return null;
    final sorted = [...buses]
      ..sort((a, b) => b.lastUpdated.compareTo(a.lastUpdated));
    return sorted.first.lastUpdated;
  }
}

class _HeroCard extends StatelessWidget {
  final int liveBusCount;
  final int routeCount;
  final DateTime? lastUpdated;

  const _HeroCard({
    required this.liveBusCount,
    required this.routeCount,
    required this.lastUpdated,
  });

  @override
  Widget build(BuildContext context) {
    final lastUpdatedText = lastUpdated == null
        ? 'No live update yet'
        : 'Last live update ${_timeAgo(lastUpdated!)}';

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF173B34), Color(0xFF101B18)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        border:
            Border.all(color: AppTheme.green.withValues(alpha: 0.25), width: 0.8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Vizag Bus Live',
            style: TextStyle(
              color: AppTheme.green,
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.4,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Real-time conductor tracking for Vizag city buses',
            style: TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 20,
              fontWeight: FontWeight.w800,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            lastUpdatedText,
            style: const TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _HeroStat(
                label: 'Live buses',
                value: '$liveBusCount',
                color: AppTheme.green,
              ),
              const SizedBox(width: 12),
              _HeroStat(
                label: 'Routes active',
                value: '$routeCount',
                color: AppTheme.blue,
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _timeAgo(DateTime time) {
    final diff = DateTime.now().difference(time);
    if (diff.inSeconds < 60) return '${diff.inSeconds}s ago';
    return '${diff.inMinutes}m ago';
  }
}

class _HeroStat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _HeroStat({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: TextStyle(
                color: color,
                fontSize: 24,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionGrid extends StatelessWidget {
  final VoidCallback onOpenPassengerView;
  final VoidCallback onOpenPassengerHelp;
  final VoidCallback onOpenStaffMode;

  const _ActionGrid({
    required this.onOpenPassengerView,
    required this.onOpenPassengerHelp,
    required this.onOpenStaffMode,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _ActionCard(
            icon: Icons.people_alt_outlined,
            title: 'Passenger View',
            subtitle: 'Open the rider experience',
            color: AppTheme.blue,
            onTap: onOpenPassengerView,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _ActionCard(
            icon: Icons.admin_panel_settings_outlined,
            title: 'Staff Mode',
            subtitle: 'Open conductor tracking',
            color: AppTheme.green,
            onTap: onOpenStaffMode,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _ActionCard(
            icon: Icons.wifi_tethering_outlined,
            title: 'Passenger Help',
            subtitle: 'Open contribution mode',
            color: AppTheme.amber,
            onTap: onOpenPassengerHelp,
          ),
        ),
      ],
    );
  }
}

class _ActionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _ActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppTheme.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.border, width: 0.5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 18, color: color),
            ),
            const SizedBox(height: 12),
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
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OverviewCard extends StatelessWidget {
  const _OverviewCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.border, width: 0.5),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'This demo uses one conductor phone to broadcast a live bus journey into Firebase. Passenger screens read the same live stream and show the current stop, next stop, bus type, and latest update time.',
            style: TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 13,
              height: 1.5,
            ),
          ),
          SizedBox(height: 10),
          Text(
            'Passenger reporting stays separate from authoritative bus tracking, so one rider switching buses cannot corrupt the main live feed.',
            style: TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 12,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _LiveBusTile extends StatelessWidget {
  final LiveBus bus;

  const _LiveBusTile({required this.bus});

  @override
  Widget build(BuildContext context) {
    final route = bus.routeRef;
    final current = VizagStops.get(bus.segmentStartIdResolved);
    final next = VizagStops.get(bus.segmentEndIdResolved);
    final routeColor = Color(bus.routeBusType.colorValue);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.border, width: 0.5),
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
                  route?.name ?? bus.routeNumber,
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              BusTypePill(bus.routeBusType),
            ],
          ),
          const SizedBox(height: 10),
          if (bus.busPlateNumber.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                bus.busPlateNumber,
                style: const TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          Row(
            children: [
              Icon(Icons.radio_button_checked, size: 12, color: routeColor),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  current == null
                      ? 'Current stop unknown'
                      : bus.isBetweenStops
                          ? 'Passed ${current.name}'
                          : current.name,
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Text(
                _timeAgo(bus.lastUpdated),
                style: const TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 11,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              const Icon(Icons.arrow_forward, size: 12, color: AppTheme.green),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  next == null ? 'Next stop unavailable' : next.name,
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ),
              CrowdBar(bus.crowd),
            ],
          ),
        ],
      ),
    );
  }

  String _timeAgo(DateTime time) {
    final diff = DateTime.now().difference(time);
    if (diff.inSeconds < 60) return '${diff.inSeconds}s ago';
    return '${diff.inMinutes}m ago';
  }
}
