import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../data/vizag_data.dart';
import '../services/app_provider.dart';
import '../services/firestore_service.dart';
import '../utils/app_theme.dart';
import '../widgets/shared_widgets.dart';
import '../widgets/stop_search.dart';
import 'route_results_screen.dart';
import 'stop_detail_screen.dart';
import 'beacon_screen.dart';
import 'conductor_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AppProvider>(builder: (context, p, _) {
      return Scaffold(
        backgroundColor: AppTheme.bg,
        body: SafeArea(
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: _TopBar(p: p),
              ),
              SliverToBoxAdapter(
                child: _SearchPanel(p: p),
              ),
              if (p.nearbyStops.isNotEmpty)
                SliverToBoxAdapter(
                  child: _NearbyStopChips(stops: p.nearbyStops),
                ),
              SliverToBoxAdapter(
                child: SectionHeader(
                  'Buses near you',
                  subtitle: p.hasLocation
                      ? '${p.nearbyBuses.length} buses incoming'
                      : 'Enable location for live buses',
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
              if (!p.hasLocation && !p.locLoading)
                const SliverToBoxAdapter(
                  child: EmptyState(
                    'Location not available',
                    sub: 'Allow location access to see nearby buses',
                    icon: Icons.location_off_outlined,
                  ),
                )
              else if (p.locLoading)
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: Center(
                      child: CircularProgressIndicator(
                        color: AppTheme.green,
                        strokeWidth: 1.5,
                      ),
                    ),
                  ),
                )
              else if (p.nearbyBuses.isEmpty)
                const SliverToBoxAdapter(
                  child: EmptyState(
                    'No buses nearby right now',
                    sub: 'Try searching FROM -> TO to find routes',
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (_, i) => IncomingBusCard(
                        p.nearbyBuses[i],
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                StopDetailScreen(stop: p.nearbyBuses[i].stop),
                          ),
                        ),
                      ),
                      childCount: p.nearbyBuses.length,
                    ),
                  ),
                ),
              const SliverToBoxAdapter(child: SizedBox(height: 100)),
            ],
          ),
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const BeaconScreen()),
          ),
          backgroundColor: AppTheme.green,
          foregroundColor: Colors.white,
          icon: Icon(
            p.beacon.isActive ? Icons.wifi_tethering : Icons.wifi_tethering_off,
            size: 18,
          ),
          label: Text(
            p.beacon.isActive ? 'Beacon ON' : 'Beacon',
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
        ),
      );
    });
  }
}

class _TopBar extends StatefulWidget {
  final AppProvider p;
  const _TopBar({required this.p});

  @override
  State<_TopBar> createState() => _TopBarState();
}

class _TopBarState extends State<_TopBar> {
  static const String _staffCode = 'vizag2026';
  int _tapCount = 0;
  DateTime? _lastTapAt;

  void _onVersionTap() {
    final now = DateTime.now();
    if (_lastTapAt == null || now.difference(_lastTapAt!).inSeconds > 2) {
      _tapCount = 0;
    }
    _lastTapAt = now;
    _tapCount += 1;
    if (_tapCount >= 5) {
      _tapCount = 0;
      _showStaffUnlockSheet();
    }
  }

  Future<void> _showStaffUnlockSheet() async {
    final controller = TextEditingController();
    String? error;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.fromLTRB(
                20,
                20,
                20,
                MediaQuery.of(context).viewInsets.bottom + 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Staff Mode',
                    style: TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Tap the version label five times, then enter the demo access code.',
                    style: TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: controller,
                    autofocus: true,
                    obscureText: true,
                    style: const TextStyle(color: AppTheme.textPrimary),
                    decoration: InputDecoration(
                      hintText: 'Access code',
                      hintStyle: const TextStyle(color: AppTheme.textMuted),
                      filled: true,
                      fillColor: AppTheme.card,
                      errorText: error,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppTheme.border),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppTheme.border),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppTheme.green),
                      ),
                    ),
                    onSubmitted: (_) => _submitStaffCode(
                      controller.text.trim(),
                      sheetContext,
                      setModalState,
                      (msg) => error = msg,
                    ),
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => _submitStaffCode(
                        controller.text.trim(),
                        sheetContext,
                        setModalState,
                        (msg) => error = msg,
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.green,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Open Staff Mode',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _submitStaffCode(
    String value,
    BuildContext sheetContext,
    StateSetter setModalState,
    void Function(String) setError,
  ) async {
    if (value == _staffCode) {
      // Promote user to conductor role in Firestore
      try {
        await FirestoreService().promoteToConductor();
      } catch (_) {}
      if (!mounted) return;
      if (sheetContext.mounted) Navigator.pop(sheetContext);
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const ConductorScreen()),
      );
    } else {
      setModalState(() => setError('Invalid access code'));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      color: AppTheme.surface,
      child: Row(
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
                  color: AppTheme.green.withOpacity(0.8),
                ),
              ),
              const SizedBox(height: 2),
              GestureDetector(
                onTap: _onVersionTap,
                child: const Text(
                  'v2.0 demo',
                  style: TextStyle(
                    fontSize: 10,
                    color: AppTheme.textMuted,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: AppTheme.greenDim,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: AppTheme.green.withOpacity(0.3),
                width: 0.5,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: const BoxDecoration(
                    color: AppTheme.green,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 5),
                Text(
                  '${widget.p.buses.length} live',
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppTheme.green,
                    fontWeight: FontWeight.w600,
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

class _SearchPanel extends StatelessWidget {
  final AppProvider p;
  const _SearchPanel({required this.p});

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
          const Text(
            'Find a route',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const _DotLine(color: AppTheme.green),
              const SizedBox(width: 10),
              Expanded(
                child: StopSearchField(
                  hint: 'From stop',
                  value: p.fromStop,
                  exclude: p.toStop,
                  onSelected: p.setFromStop,
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(left: 6),
            child: _VLine(),
          ),
          Row(
            children: [
              const _DotLine(color: AppTheme.red),
              const SizedBox(width: 10),
              Expanded(
                child: StopSearchField(
                  hint: 'To stop',
                  value: p.toStop,
                  exclude: p.fromStop,
                  onSelected: p.setToStop,
                ),
              ),
            ],
          ),
          if (p.fromStop != null && p.toStop != null) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
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
                    borderRadius: BorderRadius.circular(10),
                  ),
                  elevation: 0,
                ),
                child: const Text(
                  'Search buses',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
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
        color: color.withOpacity(0.15),
        shape: BoxShape.circle,
        border: Border.all(color: color, width: 2),
      ),
    );
  }
}

class _VLine extends StatelessWidget {
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

class _NearbyStopChips extends StatelessWidget {
  final List<BusStop> stops;
  const _NearbyStopChips({required this.stops});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 4, 16, 8),
          child: Text(
            'Nearby stops',
            style: TextStyle(
              fontSize: 12,
              color: AppTheme.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        SizedBox(
          height: 34,
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
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppTheme.card,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: AppTheme.border, width: 0.5),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.place_outlined,
                        size: 12,
                        color: AppTheme.textSecondary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        stop.name,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppTheme.textPrimary,
                          fontWeight: FontWeight.w500,
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
