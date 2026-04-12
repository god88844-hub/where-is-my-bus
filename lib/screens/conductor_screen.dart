import 'dart:async';
import 'package:flutter/material.dart';
import '../data/vizag_data.dart';
import '../models/bus.dart';
import '../services/conductor_tracking_service.dart';
import '../utils/app_theme.dart';

class ConductorScreen extends StatefulWidget {
  const ConductorScreen({super.key});

  @override
  State<ConductorScreen> createState() => _ConductorScreenState();
}

class _ConductorScreenState extends State<ConductorScreen> {
  final ConductorTrackingService _trackingService =
      ConductorTrackingService.instance;
  final TextEditingController _searchCtrl = TextEditingController();

  bool _tracking = false;
  bool _loading = false;
  String? _selectedRoute;
  String? _selectedStopId;
  BusType? _selectedBusType;
  BusCrowd _crowd = BusCrowd.moderate;
  String? _statusMessage;
  String? _busId;
  double? _lastLat;
  double? _lastLng;
  double? _lastSpeed;
  DateTime? _lastUpdate;
  bool _autoStopEnabled = true;
  List<BusRoute> _filtered = [];
  bool _showDropdown = false;

  @override
  void initState() {
    super.initState();
    _filtered = _sortedRoutes(VizagRoutes.all);
    _searchCtrl.addListener(_onSearch);
    _trackingService.addListener(_syncFromService);
    _syncFromService();
  }

  BusRoute? get _activeRoute {
    if (_selectedRoute == null) return null;
    for (final route in VizagRoutes.all) {
      if (route.number == _selectedRoute) return route;
    }
    return null;
  }

  List<BusStop> get _routeStops {
    final route = _activeRoute;
    if (route == null) return const [];
    return route.stopIds
        .map((id) => VizagStops.all[id])
        .whereType<BusStop>()
        .toList();
  }

  BusType? get _resolvedBusType {
    return _selectedBusType ?? _activeRoute?.busType;
  }

  String get _normalizedPlate => ''; // Deprecated

  int get _currentStopIndex {
    final route = _activeRoute;
    if (route == null || _selectedStopId == null) return -1;
    return route.stopIds.indexOf(_selectedStopId!);
  }

  String? get _nextStopId {
    final route = _activeRoute;
    final index = _currentStopIndex;
    if (route == null || index < 0 || index >= route.stopIds.length - 1) {
      return null;
    }
    return route.stopIds[index + 1];
  }

  void _onSearch() {
    final q = _searchCtrl.text.toLowerCase().trim();
    setState(() {
      _filtered = q.isEmpty
          ? _sortedRoutes(VizagRoutes.all)
          : _sortedRoutes(VizagRoutes.all.where((r) {
              return r.number.toLowerCase().contains(q) ||
                  r.from.toLowerCase().contains(q) ||
                  r.to.toLowerCase().contains(q);
            }).toList());
      _showDropdown = q.isNotEmpty;
    });
  }

  List<BusRoute> _sortedRoutes(List<BusRoute> routes) {
    final sorted = [...routes];
    sorted.sort((a, b) => a.number.compareTo(b.number));
    return sorted;
  }

  void _selectRoute(BusRoute route) {
    setState(() {
      _selectedRoute = route.number;
      _selectedStopId = route.stopIds.isNotEmpty ? route.stopIds.first : null;
      _searchCtrl.text = '${route.number}: ${route.from} -> ${route.to}';
      _showDropdown = false;
    });
    unawaited(_trackingService.setDraftRoute(route));
    FocusScope.of(context).unfocus();
  }

  static const List<BusType> _busTypeChoices = [
    BusType.redOrdinary,
    BusType.metro,
    BusType.palleVelugu,
    BusType.ultraDeluxe,
  ];

  Future<void> _selectBusType(BusType type) async {
    setState(() => _selectedBusType = type);
    await _trackingService.setDraftBusType(type);
    if (_tracking) {
      await _trackingService.syncNow();
    }
  }

  void _clearRouteSearch() {
    _searchCtrl.clear();
    FocusScope.of(context).requestFocus(FocusNode());
    setState(() {
      _filtered = _sortedRoutes(VizagRoutes.all);
      _showDropdown = false;
    });
  }

  Future<void> _startTracking() async {
    if (_activeRoute == null) {
      _show('Please select a route first');
      return;
    }
    if (_selectedBusType == null) {
      _show('Please select the bus type');
      return;
    }
    if (_selectedStopId == null) {
      _show('Please select the current stop');
      return;
    }

    setState(() => _loading = true);

    try {
      await _trackingService.setDraftBusType(_selectedBusType!);
      await _trackingService.setDraftStop(_selectedStopId);
      await _trackingService.setDraftCrowd(_crowd);
      if (_activeRoute != null) {
        await _trackingService.setDraftRoute(_activeRoute!);
        await _trackingService.setDraftStop(_selectedStopId);
      }
      final started = await _trackingService.startTracking();

      if (!mounted) return;
      setState(() {
        _loading = false;
        _tracking = started;
      });
      _syncFromService();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _statusMessage = 'Firebase write failed: $e';
      });
      _show('Could not write to Firebase');
    }
  }

  Future<void> _syncNow() async {
    setState(() => _loading = true);
    try {
      await _trackingService.syncNow();
      _show('Bus update sent to Firebase');
    } catch (e) {
      setState(() {
        _statusMessage = 'Firebase write failed: $e';
      });
      _show('Could not write to Firebase');
    } finally {
      if (mounted) {
        setState(() => _loading = false);
        _syncFromService();
      }
    }
  }

  Future<void> _stopTracking() async {
    await _trackingService.stopTracking();
    if (!mounted) return;
    setState(() => _loading = false);
    _syncFromService();
  }

  Future<void> _changeRoute() async {
    if (_activeRoute == null) return;
    _show('Route changed to $_selectedRoute');
  }

  void _show(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), duration: const Duration(seconds: 2)),
    );
  }

  void _syncFromService() {
    if (!mounted) return;

    final serviceRoute = _trackingService.selectedRoute;
    final route =
        serviceRoute == null ? null : VizagRoutes.byNumber(serviceRoute);
    final routeLabel =
        route == null ? '' : '${route.number}: ${route.from} -> ${route.to}';

    setState(() {
      _tracking = _trackingService.tracking;
      _selectedRoute = serviceRoute;
      _selectedStopId = _trackingService.selectedStopId;
      _selectedBusType = _trackingService.selectedBusType;
      _crowd = _trackingService.crowd;
      _statusMessage = _trackingService.statusMessage;
      _busId = _trackingService.busId;
      _lastLat = _trackingService.lastLat;
      _lastLng = _trackingService.lastLng;
      _lastSpeed = _trackingService.lastSpeed;
      _lastUpdate = _trackingService.lastUpdate;
      _autoStopEnabled = _trackingService.autoStopEnabled;
    });

    if (_searchCtrl.text != routeLabel) {
      _searchCtrl.value = _searchCtrl.value.copyWith(
        text: routeLabel,
        selection: TextSelection.collapsed(offset: routeLabel.length),
      );
    }
  }

  @override
  void dispose() {
    _trackingService.removeListener(_syncFromService);
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(
        backgroundColor: AppTheme.surface,
        elevation: 0,
        title: const Text(
          'Conductor Mode',
          style: TextStyle(
            color: AppTheme.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppTheme.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _StatusCard(
                tracking: _tracking,
                routeNumber: _selectedRoute,
                plateNumber: _normalizedPlate.isEmpty ? null : _normalizedPlate,
                busTypeLabel:
                    _activeRoute == null ? null : _resolvedBusType.label,
                stopName: _selectedStopId == null
                    ? null
                    : VizagStops.all[_selectedStopId!]?.name,
                lat: _lastLat,
                lng: _lastLng,
                speed: _lastSpeed,
                lastUpdate: _lastUpdate,
                statusMessage: _statusMessage,
              ),
              const SizedBox(height: 24),
              const Text(
                'Route Number',
                style: TextStyle(
                  color: AppTheme.textMuted,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              _RouteSearchField(
                controller: _searchCtrl,
                enabled: !_loading && !_tracking,
                showDropdown: _showDropdown,
                filtered: _filtered,
                onSelect: _selectRoute,
              ),
              if (_activeRoute != null) ...[
                const SizedBox(height: 10),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: Color(_activeRoute!.busType.colorValue)
                        .withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: Color(_activeRoute!.busType.colorValue)
                          .withOpacity(0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.directions_bus_filled_outlined,
                        size: 16,
                        color: Color(_activeRoute!.busType.colorValue),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Bus type will be set automatically: ${_activeRoute!.busType.label}',
                          style: TextStyle(
                            color: Color(_activeRoute!.busType.colorValue),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 20),
              const Text(
                'Bus Type',
                style: TextStyle(
                  color: AppTheme.textMuted,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: _busTypeChoices.map((type) {
                  final selected = _selectedBusType == type;
                  final color = Color(type.colorValue);
                  return GestureDetector(
                    onTap: _loading ? null : () => _selectBusType(type),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: selected ? color : AppTheme.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: selected ? color : AppTheme.divider,
                        ),
                        boxShadow: selected
                            ? [
                                BoxShadow(
                                  color: color.withValues(alpha: 0.2),
                                  blurRadius: 12,
                                  offset: const Offset(0, 6),
                                ),
                              ]
                            : null,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            selected
                                ? Icons.check_circle
                                : Icons.directions_bus_filled_outlined,
                            size: 18,
                            color: selected ? Colors.white : color,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            type.label,
                            style: TextStyle(
                              color: selected ? Colors.white : color,
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 10),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: (_resolvedBusType == null
                          ? const Color(0xFF185FA5)
                          : Color(_resolvedBusType!.colorValue))
                      .withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: (_resolvedBusType == null
                            ? const Color(0xFF185FA5)
                            : Color(_resolvedBusType!.colorValue))
                        .withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      size: 16,
                      color: _resolvedBusType == null
                          ? const Color(0xFF185FA5)
                          : Color(_resolvedBusType!.colorValue),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _resolvedBusType == null
                            ? 'Choose the bus category for this trip.'
                            : 'Selected: ${_resolvedBusType!.label}',
                        style: TextStyle(
                          color: _resolvedBusType == null
                              ? const Color(0xFF185FA5)
                              : Color(_resolvedBusType!.colorValue),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Current Stop',
                style: TextStyle(
                  color: AppTheme.textMuted,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppTheme.divider),
                ),
                child: DropdownButtonFormField<String>(
                  initialValue: _selectedStopId,
                  isExpanded: true,
                  dropdownColor: AppTheme.surface,
                  decoration: const InputDecoration(
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    border: InputBorder.none,
                  ),
                  style: const TextStyle(color: AppTheme.textPrimary),
                  hint: const Text(
                    'Select current stop',
                    style: TextStyle(color: AppTheme.textMuted),
                  ),
                  items: _routeStops.map((stop) {
                    return DropdownMenuItem<String>(
                      value: stop.id,
                      child: Text(
                        stop.name,
                        overflow: TextOverflow.ellipsis,
                      ),
                    );
                  }).toList(),
                  onChanged: _loading
                      ? null
                      : (value) async {
                          setState(() => _selectedStopId = value);
                          await _trackingService.setDraftStop(value);
                        },
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Crowd Level',
                style: TextStyle(
                  color: AppTheme.textMuted,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: BusCrowd.values.map((c) {
                  final selected = _crowd == c;
                  const colors = [
                    Color(0xFF1D9E75),
                    Color(0xFFBA7517),
                    Color(0xFFE24B4A),
                  ];
                  const labels = ['Empty', 'Moderate', 'Full'];
                  return Expanded(
                    child: GestureDetector(
                      onTap: () async {
                        setState(() => _crowd = c);
                        await _trackingService.setDraftCrowd(c);
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        margin: const EdgeInsets.only(right: 8),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: selected ? colors[c.index] : AppTheme.surface,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color:
                                selected ? colors[c.index] : AppTheme.divider,
                          ),
                        ),
                        child: Text(
                          labels[c.index],
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: selected ? Colors.white : AppTheme.textMuted,
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 32),
              SwitchListTile(
                value: _autoStopEnabled,
                onChanged: _loading
                    ? null
                    : (value) async {
                        setState(() {
                          _autoStopEnabled = value;
                          _statusMessage = value
                              ? 'Auto stop detection is on'
                              : 'Auto stop detection is off';
                        });
                        await _trackingService.setAutoStopEnabled(value);
                      },
                activeThumbColor: const Color(0xFF1D9E75),
                contentPadding: EdgeInsets.zero,
                title: const Text(
                  'Auto-detect stops from GPS',
                  style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                subtitle: const Text(
                  'The app will move to the next stop when the bus gets close to it.',
                  style: TextStyle(
                    color: AppTheme.textMuted,
                    fontSize: 12,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              if (!_tracking) ...[
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _loading ? null : _startTracking,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1D9E75),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _loading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Text(
                            'Start Tracking',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                  ),
                ),
              ] else ...[
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _loading ? null : _syncNow,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF185FA5),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _loading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Text(
                            'Sync Now',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: _loading ? null : _changeRoute,
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFF185FA5)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Change Route',
                      style: TextStyle(
                        color: Color(0xFF185FA5),
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _loading ? null : _stopTracking,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFE24B4A),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Stop Tracking',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 24),
              Center(
                child: Text(
                  _tracking
                      ? 'Live tracking is active. Reopening Staff Mode restores this trip.'
                      : 'Select route, enter bus plate, and begin tracking',
                  style: const TextStyle(
                    color: AppTheme.textMuted,
                    fontSize: 13,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  final bool tracking;
  final String? routeNumber;
  final String? plateNumber;
  final String? busTypeLabel;
  final String? stopName;
  final double? lat;
  final double? lng;
  final double? speed;
  final DateTime? lastUpdate;
  final String? statusMessage;

  const _StatusCard({
    required this.tracking,
    this.routeNumber,
    this.plateNumber,
    this.busTypeLabel,
    this.stopName,
    this.lat,
    this.lng,
    this.speed,
    this.lastUpdate,
    this.statusMessage,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: tracking ? const Color(0xFF1D9E75) : AppTheme.divider,
          width: tracking ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color:
                      tracking ? const Color(0xFF1D9E75) : AppTheme.textMuted,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                tracking ? 'LIVE' : 'OFFLINE',
                style: TextStyle(
                  color:
                      tracking ? const Color(0xFF1D9E75) : AppTheme.textMuted,
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                  letterSpacing: 1.2,
                ),
              ),
              if (routeNumber != null) ...[
                const Spacer(),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF185FA5).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'Route $routeNumber',
                    style: const TextStyle(
                      color: Color(0xFF185FA5),
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ],
          ),
          if (stopName != null) ...[
            const SizedBox(height: 10),
            Text(
              'Current stop: $stopName',
              style: const TextStyle(
                color: AppTheme.textPrimary,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ],
          if (plateNumber != null || busTypeLabel != null) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (plateNumber != null)
                  _InfoChip(
                    icon: Icons.badge_outlined,
                    label: plateNumber!,
                  ),
                if (busTypeLabel != null)
                  _InfoChip(
                    icon: Icons.directions_bus_filled_outlined,
                    label: busTypeLabel!,
                  ),
              ],
            ),
          ],
          if (tracking && lat != null) ...[
            const SizedBox(height: 12),
            const Divider(color: AppTheme.divider, height: 1),
            const SizedBox(height: 12),
            Row(
              children: [
                _Stat(
                  label: 'Speed',
                  value: '${speed?.toStringAsFixed(0) ?? '--'} km/h',
                ),
                const SizedBox(width: 24),
                _Stat(label: 'Lat', value: lat!.toStringAsFixed(5)),
                const SizedBox(width: 24),
                _Stat(label: 'Lng', value: lng!.toStringAsFixed(5)),
              ],
            ),
          ],
          if (statusMessage != null) ...[
            const SizedBox(height: 10),
            Text(
              statusMessage!,
              style: const TextStyle(color: AppTheme.textMuted, fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String label;
  final String value;

  const _Stat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(color: AppTheme.textMuted, fontSize: 11),
        ),
        Text(
          value,
          style: const TextStyle(
            color: AppTheme.textPrimary,
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
        ),
      ],
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _InfoChip({
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppTheme.divider),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: AppTheme.textSecondary),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _RouteSearchField extends StatelessWidget {
  final TextEditingController controller;
  final bool enabled;
  final bool showDropdown;
  final List<BusRoute> filtered;
  final void Function(BusRoute) onSelect;

  const _RouteSearchField({
    required this.controller,
    required this.enabled,
    required this.showDropdown,
    required this.filtered,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TextField(
          controller: controller,
          enabled: enabled,
          style: const TextStyle(color: AppTheme.textPrimary),
          decoration: InputDecoration(
            hintText: 'Search route (e.g. 38Y, Gajuwaka)',
            hintStyle: const TextStyle(color: AppTheme.textMuted),
            filled: true,
            fillColor: AppTheme.surface,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: AppTheme.divider),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: AppTheme.divider),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFF185FA5)),
            ),
            prefixIcon: const Icon(
              Icons.search,
              color: AppTheme.textMuted,
              size: 20,
            ),
          ),
        ),
        if (showDropdown && filtered.isNotEmpty)
          Container(
            constraints: const BoxConstraints(maxHeight: 260),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppTheme.divider),
            ),
            child: ListView.separated(
              shrinkWrap: true,
              padding: EdgeInsets.zero,
              itemCount: filtered.length > 15 ? 15 : filtered.length,
              separatorBuilder: (_, __) =>
                  const Divider(height: 1, color: AppTheme.divider),
              itemBuilder: (_, i) {
                final route = filtered[i];
                return ListTile(
                  dense: true,
                  leading: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: Color(route.busType.colorValue).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(5),
                    ),
                    child: Text(
                      route.number,
                      style: TextStyle(
                        color: Color(route.busType.colorValue),
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  title: Text(
                    '${route.from} -> ${route.to}',
                    style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 13,
                    ),
                  ),
                  subtitle: route.viaStops.isNotEmpty
                      ? Text(
                          'via ${route.viaStops.take(2).join(', ')}',
                          style: const TextStyle(
                            color: AppTheme.textMuted,
                            fontSize: 11,
                          ),
                        )
                      : null,
                  onTap: () => onSelect(route),
                );
              },
            ),
          ),
      ],
    );
  }
}
