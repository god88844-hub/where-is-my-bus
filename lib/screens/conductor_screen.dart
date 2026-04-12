import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../data/bus_plate_registry.dart';
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
  final TextEditingController _plateCtrl = TextEditingController();
  final FocusNode _routeSearchFocus = FocusNode();

  bool _tracking = false;
  bool _loading = false;
  String? _selectedRoute;
  String? _selectedStopId;
  String? _segmentEndStopId;
  BusCrowd _crowd = BusCrowd.moderate;
  String? _statusMessage;
  double? _lastLat;
  double? _lastLng;
  double? _lastSpeed;
  DateTime? _lastUpdate;
  double? _segmentProgress;
  double? _distanceToNextStopKm;
  double? _effectiveSpeedKmh;
  bool _debugSimulationActive = false;
  bool _autoStopEnabled = true;
  List<BusRoute> _filtered = [];
  bool _showDropdown = false;

  @override
  void initState() {
    super.initState();
    _filtered = _sortedRoutes(VizagRoutes.all);
    _searchCtrl.addListener(_onSearch);
    _routeSearchFocus.addListener(() {
      if (!_routeSearchFocus.hasFocus && _showDropdown) {
        setState(() => _showDropdown = false);
      }
    });
    _trackingService.addListener(_syncFromService);
    _syncFromService();
  }

  BusRoute? get _activeRoute {
    if (_selectedRoute == null) return null;
    return VizagRoutes.byRouteId(_selectedRoute!);
  }

  BusType get _resolvedBusType {
    return BusPlateRegistry.resolveType(
          plateNumber: _plateCtrl.text,
          routeNumber: _selectedRoute,
        ) ??
        _activeRoute?.busType ??
        BusType.redOrdinary;
  }

  String get _normalizedPlate => _plateCtrl.text.toUpperCase().trim();

  int get _currentStopIndex {
    final route = _activeRoute;
    if (route == null || _selectedStopId == null) return -1;
    return route.stopIds.indexOf(_selectedStopId!);
  }

  String? get _nextStopId {
    if (_segmentEndStopId != null) return _segmentEndStopId;
    final route = _activeRoute;
    final index = _currentStopIndex;
    if (route == null || index < 0 || index >= route.stopIds.length - 1) {
      return null;
    }
    return route.stopIds[index + 1];
  }

  String? get _currentStopName =>
      _selectedStopId == null ? null : VizagStops.all[_selectedStopId!]?.name;

  String? get _nextStopName =>
      _nextStopId == null ? null : VizagStops.all[_nextStopId!]?.name;

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
      _showDropdown = _routeSearchFocus.hasFocus && q.isNotEmpty;
    });
  }

  List<BusRoute> _sortedRoutes(List<BusRoute> routes) {
    final sorted = [...routes];
    sorted.sort((a, b) => a.number.compareTo(b.number));
    return sorted;
  }

  Future<void> _selectRoute(BusRoute route) async {
    setState(() {
      _selectedRoute = route.routeId;
      _searchCtrl.text = '${route.number}: ${route.from} -> ${route.to}';
      _showDropdown = false;
      if (!_tracking) {
        _selectedStopId = null;
      }
    });
    FocusScope.of(context).unfocus();

    try {
      if (_tracking) {
        setState(() {
          _loading = true;
          _statusMessage =
              'Changing route to ${route.number}: ${route.from} -> ${route.to}';
        });
        await _trackingService.changeRoute(route);
        if (mounted) {
          _show('Route changed to ${route.number}');
        }
      } else {
        await _trackingService.setDraftRoute(route);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _statusMessage = 'Could not change route: $e';
      });
      _show('Could not change route');
    } finally {
      if (mounted) {
        setState(() => _loading = false);
        _syncFromService();
      }
    }
  }

  Future<void> _startTracking() async {
    if (_activeRoute == null) {
      _show('Please select a route first');
      return;
    }
    if (_normalizedPlate.isEmpty) {
      _show('Please enter the bus plate number');
      return;
    }

    setState(() => _loading = true);

    try {
      if (_activeRoute != null) {
        await _trackingService.setDraftRoute(_activeRoute!);
      }
      await _trackingService.setDraftPlate(_plateCtrl.text);
      await _trackingService.setDraftCrowd(_crowd);
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
        _statusMessage = 'Could not start tracking: $e';
      });
      _show('Could not start tracking');
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

  Future<void> _toggleDebugSimulation() async {
    setState(() => _loading = true);
    try {
      if (_debugSimulationActive) {
        await _trackingService.stopDebugSimulation();
        _show('Debug simulation stopped');
      } else {
        await _trackingService.startDebugSimulation();
        _show('Debug simulation started');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _statusMessage = 'Could not toggle debug simulation: $e';
      });
      _show('Could not toggle debug simulation');
    } finally {
      if (mounted) {
        setState(() => _loading = false);
        _syncFromService();
      }
    }
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
        serviceRoute == null ? null : VizagRoutes.byRouteId(serviceRoute);
    final normalizedPlate = _trackingService.normalizedPlate;
    final routeLabel =
        route == null ? '' : '${route.number}: ${route.from} -> ${route.to}';

    setState(() {
      _tracking = _trackingService.tracking;
      _selectedRoute = serviceRoute;
      _selectedStopId = _trackingService.selectedStopId;
      _crowd = _trackingService.crowd;
      _statusMessage = _trackingService.statusMessage;
      _lastLat = _trackingService.lastLat;
      _lastLng = _trackingService.lastLng;
      _lastSpeed = _trackingService.lastSpeed;
      _lastUpdate = _trackingService.lastUpdate;
      _segmentEndStopId = _trackingService.nextStopId;
      _segmentProgress = _trackingService.segmentProgress;
      _distanceToNextStopKm = _trackingService.distanceToNextStopKm;
      _effectiveSpeedKmh = _trackingService.effectiveSpeedKmh;
      _debugSimulationActive = _trackingService.debugSimulationActive;
      _autoStopEnabled = _trackingService.autoStopEnabled;
    });

    if (_plateCtrl.text != normalizedPlate) {
      _plateCtrl.value = _plateCtrl.value.copyWith(
        text: normalizedPlate,
        selection: TextSelection.collapsed(offset: normalizedPlate.length),
      );
    }

    if (!_routeSearchFocus.hasFocus && _searchCtrl.text != routeLabel) {
      _searchCtrl.value = _searchCtrl.value.copyWith(
        text: routeLabel,
        selection: TextSelection.collapsed(offset: routeLabel.length),
      );
    }
  }

  Future<void> _reverseDirection() async {
    setState(() => _loading = true);
    try {
      await _trackingService.reverseDirection();
      if (!mounted) return;
      _show('Trip direction reversed');
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _statusMessage = 'Could not reverse direction: $e';
      });
      _show('Could not reverse direction');
    } finally {
      if (mounted) {
        setState(() => _loading = false);
        _syncFromService();
      }
    }
  }

  @override
  void dispose() {
    _trackingService.removeListener(_syncFromService);
    _searchCtrl.dispose();
    _plateCtrl.dispose();
    _routeSearchFocus.dispose();
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
                routeNumber: _activeRoute?.number,
                plateNumber: _normalizedPlate.isEmpty ? null : _normalizedPlate,
                busTypeLabel:
                    _activeRoute == null ? null : _resolvedBusType.label,
                stopName: _selectedStopId == null
                    ? null
                    : VizagStops.all[_selectedStopId!]?.name,
                nextStopName: _nextStopName,
                lat: _lastLat,
                lng: _lastLng,
                speed: _effectiveSpeedKmh ?? _lastSpeed,
                segmentProgress: _segmentProgress,
                distanceToNextStopKm: _distanceToNextStopKm,
                lastUpdate: _lastUpdate,
                statusMessage: _statusMessage,
                isBetweenStops: (_segmentProgress ?? 0) > 0.02 &&
                    (_segmentProgress ?? 0) < 0.98,
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
                focusNode: _routeSearchFocus,
                enabled: !_loading,
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
                'Bus Plate Number',
                style: TextStyle(
                  color: AppTheme.textMuted,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _plateCtrl,
                enabled: !_loading && !_tracking,
                textCapitalization: TextCapitalization.characters,
                style: const TextStyle(color: AppTheme.textPrimary),
                decoration: InputDecoration(
                  hintText: 'Example: AP31TE5929',
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
                ),
                onChanged: (_) {
                  setState(() {});
                  unawaited(_trackingService.setDraftPlate(_plateCtrl.text));
                },
              ),
              const SizedBox(height: 10),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: Color(_resolvedBusType.colorValue).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: Color(_resolvedBusType.colorValue).withOpacity(0.3),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.directions_bus_filled_outlined,
                      size: 16,
                      color: Color(_resolvedBusType.colorValue),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Bus type auto-filled: ${_resolvedBusType.label}',
                        style: TextStyle(
                          color: Color(_resolvedBusType.colorValue),
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
                'GPS Stop Detection',
                style: TextStyle(
                  color: AppTheme.textMuted,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppTheme.divider),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.my_location_outlined,
                          size: 16,
                          color: Color(0xFF185FA5),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _currentStopName ??
                                'Waiting for GPS to resolve the nearest stop',
                            style: const TextStyle(
                              color: AppTheme.textPrimary,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _nextStopName == null
                          ? 'The app will detect the current stop automatically when tracking starts.'
                          : (_segmentProgress ?? 0) > 0.02 &&
                                  (_segmentProgress ?? 0) < 0.98
                              ? 'Between stops · ${(100 * (_segmentProgress ?? 0)).round()}% to $_nextStopName'
                              : 'Next stop: $_nextStopName',
                      style: const TextStyle(
                        color: AppTheme.textMuted,
                        fontSize: 12,
                      ),
                    ),
                    if (_activeRoute?.returnRouteNumber != null) ...[
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: _loading ? null : _reverseDirection,
                          icon: const Icon(Icons.swap_horiz, size: 18),
                          label: Text(
                            'Reverse To ${_activeRoute!.to} -> ${_activeRoute!.from}',
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF185FA5),
                            side: const BorderSide(
                              color: Color(0xFF185FA5),
                              width: 0.8,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                    ],
                  ],
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
                activeColor: const Color(0xFF1D9E75),
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
                if (kDebugMode) ...[
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _loading ? null : _toggleDebugSimulation,
                      icon: Icon(
                        _debugSimulationActive
                            ? Icons.pause_circle_outline
                            : Icons.play_circle_outline,
                        size: 18,
                      ),
                      label: Text(
                        _debugSimulationActive
                            ? 'Stop Debug Simulation'
                            : 'Start Debug Simulation',
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF185FA5),
                        side: const BorderSide(
                          color: Color(0xFF185FA5),
                          width: 0.8,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                ],
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
                      ? _debugSimulationActive
                          ? 'Debug simulation is driving the bus forward using the same route-snapping logic as live GPS.'
                          : 'Live tracking is active. Selecting another route above switches the same bus to the new route.'
                      : 'Select a route, enter the bus plate, and start tracking once',
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
  final String? nextStopName;
  final double? lat;
  final double? lng;
  final double? speed;
  final double? segmentProgress;
  final double? distanceToNextStopKm;
  final DateTime? lastUpdate;
  final String? statusMessage;
  final bool isBetweenStops;

  const _StatusCard({
    required this.tracking,
    this.routeNumber,
    this.plateNumber,
    this.busTypeLabel,
    this.stopName,
    this.nextStopName,
    this.lat,
    this.lng,
    this.speed,
    this.segmentProgress,
    this.distanceToNextStopKm,
    this.lastUpdate,
    this.statusMessage,
    this.isBetweenStops = false,
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
              isBetweenStops
                  ? 'Last passed stop: $stopName'
                  : 'Current stop: $stopName',
              style: const TextStyle(
                color: AppTheme.textPrimary,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ],
          if (nextStopName != null) ...[
            const SizedBox(height: 4),
            Text(
              distanceToNextStopKm == null
                  ? 'Next stop: $nextStopName'
                  : 'Next stop: $nextStopName · ${distanceToNextStopKm!.toStringAsFixed(2)} km left',
              style: const TextStyle(
                color: AppTheme.textMuted,
                fontSize: 12,
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
                if (segmentProgress != null) ...[
                  _Stat(
                    label: 'Progress',
                    value: '${(segmentProgress! * 100).round()}%',
                  ),
                  const SizedBox(width: 24),
                ],
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
  final FocusNode focusNode;
  final bool enabled;
  final bool showDropdown;
  final List<BusRoute> filtered;
  final Future<void> Function(BusRoute) onSelect;

  const _RouteSearchField({
    required this.controller,
    required this.focusNode,
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
          focusNode: focusNode,
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
                  onTap: () async => onSelect(route),
                );
              },
            ),
          ),
      ],
    );
  }
}
