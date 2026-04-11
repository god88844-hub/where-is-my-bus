import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/app_provider.dart';
import '../data/vizag_data.dart';
import '../utils/app_theme.dart';
import '../widgets/shared_widgets.dart';

class BeaconScreen extends StatefulWidget {
  const BeaconScreen({super.key});

  @override
  State<BeaconScreen> createState() => _BeaconScreenState();
}

class _BeaconScreenState extends State<BeaconScreen> {
  String? _selectedRoute;
  bool _loading = false;
  String? _error;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final active = provider.beacon.isActive;
    final passengerRoutes = VizagRoutes.passengerRoutes;

    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(
        backgroundColor: AppTheme.surface,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back,
            size: 20,
            color: AppTheme.textPrimary,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Passenger Help Mode'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(0.5),
          child: Divider(height: 0.5, color: AppTheme.divider),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: active ? AppTheme.greenDim : AppTheme.surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: active
                          ? AppTheme.green.withOpacity(0.4)
                          : AppTheme.border,
                      width: active ? 1 : 0.5,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            active
                                ? Icons.wifi_tethering
                                : Icons.wifi_tethering_off,
                            color: active
                                ? AppTheme.green
                                : AppTheme.textSecondary,
                            size: 20,
                          ),
                          const SizedBox(width: 10),
                          Text(
                            active
                                ? 'Passenger reporting active'
                                : 'Passenger help mode',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: active
                                  ? AppTheme.green
                                  : AppTheme.textPrimary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Passenger reports help validate buses and crowd signals. They do not directly control the official live bus position shown to riders.',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppTheme.textSecondary,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        active
                            ? 'Reports are being sent every 10 seconds'
                            : 'Reporting is currently off',
                        style: TextStyle(
                          fontSize: 12,
                          color: active ? AppTheme.green : AppTheme.textMuted,
                        ),
                      ),
                      if (active && provider.beacon.activeRoute != null) ...[
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            RouteBadge(provider.beacon.activeRoute!),
                            const SizedBox(width: 8),
                            Text(
                              'Route ${provider.beacon.activeRoute!}',
                              style: const TextStyle(
                                fontSize: 13,
                                color: AppTheme.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                if (!active) ...[
                  const Text(
                    'Select your route',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Which route are you travelling on right now?',
                    style:
                        TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                  ),
                  const SizedBox(height: 12),
                  ...passengerRoutes.map((route) {
                    final selected = _selectedRoute == route.number;
                    final color = AppTheme.routeColor(route.number);
                    return GestureDetector(
                      onTap: () =>
                          setState(() => _selectedRoute = route.number),
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: selected
                              ? color.withOpacity(0.08)
                              : AppTheme.card,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: selected ? color : AppTheme.border,
                            width: selected ? 1.5 : 0.5,
                          ),
                        ),
                        child: Row(
                          children: [
                            RouteBadge(route.number),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    route.name,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      color: AppTheme.textPrimary,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  Text(
                                    route.nameTelugu,
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: AppTheme.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (selected)
                              Icon(Icons.check_circle, color: color, size: 18),
                          ],
                        ),
                      ),
                    );
                  }),
                  const SizedBox(height: 16),
                ],
              ],
            ),
          ),
          Container(
            padding: EdgeInsets.fromLTRB(
                16, 16, 16, MediaQuery.of(context).padding.bottom + 16),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              border:
                  Border(top: BorderSide(color: AppTheme.border, width: 0.5)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  offset: const Offset(0, -4),
                  blurRadius: 10,
                )
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_error != null) ...[
                  Text(_error!,
                      style:
                          const TextStyle(fontSize: 12, color: AppTheme.red)),
                  const SizedBox(height: 10),
                ],
                if (!active)
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed:
                          _selectedRoute == null || _loading ? null : _start,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.green,
                        disabledBackgroundColor:
                            AppTheme.green.withOpacity(0.3),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                      child: _loading
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white),
                            )
                          : const Text(
                              'Start reporting',
                              style: TextStyle(
                                  fontSize: 15, fontWeight: FontWeight.w600),
                            ),
                    ),
                  )
                else
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: _stop,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.red,
                        side: const BorderSide(color: AppTheme.red, width: 0.5),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('Stop reporting',
                          style: TextStyle(
                              fontSize: 15, fontWeight: FontWeight.w500)),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _start() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final provider = context.read<AppProvider>();
      await provider.beacon.start(routeNumber: _selectedRoute!);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _stop() async {
    final provider = context.read<AppProvider>();
    await provider.beacon.stop();
    if (mounted) Navigator.pop(context);
  }
}
