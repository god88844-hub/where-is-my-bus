import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../data/vizag_data.dart';
import '../models/bus.dart';
import '../services/conductor_tracking_service.dart';
import '../utils/app_language.dart';
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
  final FocusNode _routeSearchFocus = FocusNode();

  bool _tracking = false;
  bool _loading = false;
  String? _selectedRoute;
  String? _selectedStopId;
  String? _segmentEndStopId;
  BusType _busType = BusType.redOrdinary;
  String? _tripFromStopId;
  String? _tripToStopId;
  BusCrowd _crowd = BusCrowd.moderate;
  String? _statusMessage;
  double? _lastLat;
  double? _lastLng;
  double? _lastSpeed;
  DateTime? _lastUpdate;
  double? _segmentProgress;
  double? _distanceToNextStopKm;
  double? _effectiveSpeedKmh;
  bool _autoStopEnabled = true;
  List<BusRoute> _filtered = [];
  bool _showDropdown = false;

  @override
  void initState() {
    super.initState();
    _filtered = _sortedRoutes(_routeSelectionRoutes);
    _searchCtrl.addListener(_onSearch);
    _routeSearchFocus.addListener(() {
      if (!_routeSearchFocus.hasFocus && _showDropdown) {
        setState(() => _showDropdown = false);
      }
    });
    _trackingService.addListener(_syncFromService);
    AppLanguage.instance.addListener(_onLanguageChanged);
    _syncFromService();
  }

  void _onLanguageChanged() {
    if (mounted) setState(() {});
  }

  BusRoute? get _activeRoute {
    if (_selectedRoute == null) return null;
    return VizagRoutes.byRouteId(_selectedRoute!);
  }

  bool get _routeHintActive =>
      (_trackingService.draftRouteHint ?? '').isNotEmpty;

  List<BusRoute> get _routeSelectionRoutes => VizagRoutes.primaryRoutes;

  BusRoute? get _returnRoute {
    final route = _activeRoute;
    final returnRouteId = route?.returnRouteNumber;
    if (returnRouteId == null) return null;
    return VizagRoutes.byRouteId(returnRouteId);
  }

  BusType get _resolvedBusType => _busType;

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
    final routes = _routeSelectionRoutes;
    setState(() {
      _filtered = q.isEmpty
          ? _sortedRoutes(routes)
          : _sortedRoutes(
              routes.where((r) {
                return r.number.toLowerCase().contains(q) ||
                    r.from.toLowerCase().contains(q) ||
                    r.to.toLowerCase().contains(q);
              }).toList(),
              query: q);
      _showDropdown = _routeSearchFocus.hasFocus && q.isNotEmpty;
    });
  }

  List<BusRoute> _sortedRoutes(List<BusRoute> routes, {String? query}) {
    final normalizedQuery = query?.trim().toLowerCase() ?? '';
    final sorted = [...routes];
    sorted.sort((a, b) {
      final rankCompare = _routeSearchRank(a, normalizedQuery)
          .compareTo(_routeSearchRank(b, normalizedQuery));
      if (rankCompare != 0) return rankCompare;

      final numberCompare = a.number.compareTo(b.number);
      if (numberCompare != 0) return numberCompare;

      final fromCompare = a.from.compareTo(b.from);
      if (fromCompare != 0) return fromCompare;

      return a.to.compareTo(b.to);
    });
    return sorted;
  }

  int _routeSearchRank(BusRoute route, String query) {
    if (query.isEmpty) return 0;

    final number = route.number.toLowerCase();
    final from = route.from.toLowerCase();
    final to = route.to.toLowerCase();

    if (number == query) return 0;
    if (number.startsWith(query)) return 1;
    if (number.contains(query)) return 2;
    if (from.startsWith(query) || to.startsWith(query)) return 3;
    if (from.contains(query) || to.contains(query)) return 4;
    return 5;
  }

  Future<void> _selectRoute(BusRoute route) async {
    if (_tracking) {
      _show('Stop tracking before changing the route number');
      return;
    }

    setState(() {
      _selectedRoute = route.routeId;
      _searchCtrl.text = '${route.number}: ${route.from} -> ${route.to}';
      _showDropdown = false;
      _selectedStopId = null;
      _busType = route.busType;
    });
    FocusScope.of(context).unfocus();

    try {
      await _trackingService.setDraftRoute(route);
      await _trackingService.setDraftBusType(_busType);
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
    setState(() => _loading = true);

    try {
      if (_tripFromStopId != null && _tripToStopId != null) {
        await _trackingService.setDraftTripStops(
          fromStopId: _tripFromStopId!,
          toStopId: _tripToStopId!,
        );
      }
      await _trackingService.setDraftBusType(_resolvedBusType);
      await _trackingService.setDraftCrowd(_crowd);
      final result = await _trackingService.startTracking();

      if (!mounted) return;
      setState(() {
        _loading = false;
        _tracking = result.ok;
      });
      _syncFromService();

      if (!result.ok && mounted) {
        _showStartFailure(result);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _statusMessage = 'Could not start tracking: $e';
      });
      _show('Could not start tracking');
    }
  }

  void _showStartFailure(StartTrackingResult result) {
    final route = result.route ?? _activeRoute;
    final stops = route?.stopIds ?? const <String>[];
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(sheetContext).size.height * 0.75,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 6),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.error_outline,
                        color: Color(0xFFE24B4A),
                        size: 22,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          result.title ?? 'Could not start tracking',
                          style: const TextStyle(
                            color: Color(0xFFE24B4A),
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
                  child: Text(
                    result.message ?? '',
                    style: const TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 13,
                      height: 1.4,
                    ),
                  ),
                ),
                if (result.detectedStopName != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFBA7517).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color:
                              const Color(0xFFBA7517).withValues(alpha: 0.4),
                        ),
                      ),
                      child: Text(
                        'Your current location is near: '
                        '${result.detectedStopName}'
                        '${result.detectedDistanceKm != null ? ' (${result.detectedDistanceKm!.toStringAsFixed(1)} km away)' : ''}',
                        style: const TextStyle(
                          color: Color(0xFFBA7517),
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                if (stops.isNotEmpty) ...[
                  const Padding(
                    padding: EdgeInsets.fromLTRB(20, 4, 20, 6),
                    child: Text(
                      'Stops on this route:',
                      style: TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.only(bottom: 12),
                      itemCount: stops.length,
                      itemBuilder: (listContext, i) {
                        final stop = VizagStops.all[stops[i]];
                        return ListTile(
                          dense: true,
                          leading: Text(
                            '${i + 1}',
                            style: const TextStyle(
                              color: AppTheme.textMuted,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          title: Text(
                            stop?.name ?? stops[i],
                            style: const TextStyle(
                              color: AppTheme.textPrimary,
                              fontSize: 14,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 6, 20, 18),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(sheetContext),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.green,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'OK, I will fix the From - To',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _syncNow() async {
    setState(() => _loading = true);
    try {
      await _trackingService.syncNow();
      if (_trackingService.lastCloudSyncSucceeded) {
        _show('Bus update sent to Firebase');
      } else {
        final error = _trackingService.lastCloudSyncError;
        setState(() {
          _statusMessage = error == null
              ? 'Firebase write failed'
              : 'Firebase write failed: $error';
        });
        _show('Could not write live location to Firebase');
      }
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

  void _show(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), duration: const Duration(seconds: 2)),
    );
  }

  Future<void> _pickTripStop({required bool isFrom}) async {
    final route = _activeRoute;
    if (_tracking || _loading) return;
    FocusScope.of(context).unfocus();

    // With a route hint the conductor picks along that corridor; without one
    // the whole stop network is searchable.
    final candidates = route != null
        ? route.stopIds
            .asMap()
            .entries
            .map((e) => MapEntry(e.key, e.value))
            .toList()
        : VizagStops.all.keys.map((id) => MapEntry(-1, id)).toList();

    final currentStopId = isFrom ? _tripFromStopId : _tripToStopId;
    final accent = isFrom ? const Color(0xFF1D9E75) : const Color(0xFFE24B4A);

    final selectedId = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (sheetContext) {
        var query = '';
        return StatefulBuilder(
          builder: (sheetContext, setSheetState) {
            final q = query.toLowerCase().trim();
            final filtered = q.isEmpty
                ? candidates
                : candidates
                    .where((entry) {
                      final stop = VizagStops.all[entry.value];
                      return (stop?.name ?? entry.value)
                              .toLowerCase()
                              .contains(q) ||
                          (stop?.nameTelugu ?? '').contains(query) ||
                          entry.value.contains(q);
                    })
                    .toList();
            return SafeArea(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(sheetContext).size.height * 0.8,
                ),
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 6),
                      child: Row(
                        children: [
                          Icon(Icons.place_outlined, size: 18, color: accent),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              isFrom
                                  ? AppLanguage.instance.t('Pick start stop (From)', 'ఎక్కడ నుండి (From)')
                                  : AppLanguage.instance.t('Pick destination stop (To)', 'ఎక్కడికి (To)'),
                              style: TextStyle(
                                color: accent,
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          Text(
                            '${filtered.length} stops',
                            style: const TextStyle(
                              color: AppTheme.textMuted,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
                      child: TextField(
                        autofocus: route == null,
                        style: const TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 15,
                        ),
                        decoration: InputDecoration(
                          hintText: AppLanguage.instance.t(
                              'Search stop name...', 'స్టాప్ పేరు వెతకండి...'),
                          hintStyle: const TextStyle(
                            color: AppTheme.textMuted,
                            fontSize: 14,
                          ),
                          prefixIcon: const Icon(
                            Icons.search,
                            size: 20,
                            color: AppTheme.textSecondary,
                          ),
                          filled: true,
                          fillColor: AppTheme.card,
                          isDense: true,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: AppTheme.border,
                            ),
                          ),
                        ),
                        onChanged: (value) =>
                            setSheetState(() => query = value),
                      ),
                    ),
                    const Divider(height: 1, color: AppTheme.divider),
                    Expanded(
                      child: filtered.isEmpty
                          ? Center(
                              child: Text(
                                AppLanguage.instance.t(
                                    'No stops match', 'స్టాప్‌లు లేవు'),
                                style: const TextStyle(
                                    color: AppTheme.textMuted),
                              ),
                            )
                          : ListView.builder(
                              itemCount: filtered.length,
                              itemBuilder: (sheetItemContext, i) {
                                final entry = filtered[i];
                                final stopIndex = entry.key;
                                final stopId = entry.value;
                                final stop = VizagStops.all[stopId];
                                final isSelected = stopId == currentStopId;
                                return InkWell(
                                  onTap: () =>
                                      Navigator.pop(sheetContext, stopId),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 20,
                                      vertical: 13,
                                    ),
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? accent.withValues(alpha: 0.12)
                                          : null,
                                      border: const Border(
                                        bottom: BorderSide(
                                          color: AppTheme.divider,
                                          width: 0.5,
                                        ),
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Container(
                                          width: 22,
                                          height: 22,
                                          decoration: BoxDecoration(
                                            color: isSelected
                                                ? accent
                                                : Colors.transparent,
                                            shape: BoxShape.circle,
                                            border: Border.all(
                                              color: accent,
                                              width: 2,
                                            ),
                                          ),
                                          child: isSelected
                                              ? const Icon(
                                                  Icons.check,
                                                  size: 14,
                                                  color: Colors.white,
                                                )
                                              : null,
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                stop?.name ?? stopId,
                                                style: const TextStyle(
                                                  color: AppTheme.textPrimary,
                                                  fontSize: 15,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                              if (stop != null &&
                                                  stop.nameTelugu.isNotEmpty)
                                                Text(
                                                  stop.nameTelugu,
                                                  style: const TextStyle(
                                                    color:
                                                        AppTheme.textSecondary,
                                                    fontSize: 12,
                                                  ),
                                                ),
                                            ],
                                          ),
                                        ),
                                        if (stopIndex >= 0)
                                          Text(
                                            '#${stopIndex + 1}',
                                            style: const TextStyle(
                                              color: AppTheme.textMuted,
                                              fontSize: 12,
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
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    if (selectedId == null || !mounted) return;

    String newFrom;
    String newTo;
    if (isFrom) {
      newFrom = selectedId;
      newTo = _tripToStopId ?? _guessCompanionStop(fromStopId: newFrom);
    } else {
      newFrom = _tripFromStopId ?? _guessCompanionStop(toStopId: selectedId);
      newTo = selectedId;
    }
    if (newFrom == newTo) {
      _show('Now pick the other stop to complete From - To');
      setState(() {
        _tripFromStopId = newFrom;
        _tripToStopId = newTo;
      });
      return;
    }

    setState(() => _loading = true);
    try {
      final ok = await _trackingService.setDraftTripStops(
        fromStopId: newFrom,
        toStopId: newTo,
      );
      if (!mounted) return;
      if (!ok) {
        _show('Pick a From stop that comes before the To stop');
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
        _syncFromService();
      }
    }
  }

  /// Sensible default for the other end of the trip when only one stop has
  /// been picked so far.
  String _guessCompanionStop({String? fromStopId, String? toStopId}) {
    final route = _activeRoute;
    if (route != null) {
      if (fromStopId != null &&
          route.stopIds.contains(fromStopId) &&
          route.stopIds.length > 1) {
        return route.stopIds.last;
      }
      if (toStopId != null && route.stopIds.contains(toStopId)) {
        return route.stopIds.first;
      }
    }
    return fromStopId ?? toStopId ?? '';
  }

  void _syncFromService() {
    if (!mounted) return;

    final serviceRoute = _trackingService.selectedRoute;
    final route =
        serviceRoute == null ? null : VizagRoutes.byRouteId(serviceRoute);
    final hint = _trackingService.draftRouteHint;
    final String routeLabel;
    if (route != null) {
      routeLabel = hint != null && hint != route.number
          ? '$hint: ${route.from} -> ${route.to}'
          : '${route.number}: ${route.from} -> ${route.to}';
    } else if (hint != null && hint.isNotEmpty) {
      routeLabel = hint;
    } else {
      routeLabel = '';
    }

    setState(() {
      _tracking = _trackingService.tracking;
      _selectedRoute = serviceRoute;
      _selectedStopId = _trackingService.selectedStopId;
      _tripFromStopId = _trackingService.tripFromStopId;
      _tripToStopId = _trackingService.tripToStopId;
      _busType = _trackingService.selectedBusType ??
          route?.busType ??
          _resolvedBusType;
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
      _autoStopEnabled = _trackingService.autoStopEnabled;
    });

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

  Future<void> _clearRouteSelection() async {
    if (_tracking || _loading) return;

    FocusScope.of(context).unfocus();
    _searchCtrl.clear();
    setState(() {
      _selectedRoute = null;
      _selectedStopId = null;
      _filtered = _sortedRoutes(_routeSelectionRoutes);
      _showDropdown = false;
    });

    await _trackingService.clearDraftRoute();
    if (mounted) {
      _syncFromService();
    }
  }

  @override
  void dispose() {
    _trackingService.removeListener(_syncFromService);
    AppLanguage.instance.removeListener(_onLanguageChanged);
    _searchCtrl.dispose();
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
        title: Text(
          AppLanguage.instance.t('Conductor Mode', 'కండక్టర్ మోడ్'),
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
              _SectionCard(
                title: AppLanguage.instance.t('Route ID (optional)', 'రూట్ నంబర్ (ఐచ్ఛికం)'),
                titleTelugu: 'రూట్ నంబర్',
                accent: const Color(0xFF185FA5),
                icon: Icons.confirmation_number_outlined,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _routeHintActive
                          ? 'Pinned to this route id. Leave it empty if the '
                              'bus has no route number yet.'
                          : 'Optional. Pick From - To and the route is found '
                              'automatically.',
                      style: const TextStyle(
                        color: AppTheme.textMuted,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _RouteSearchField(
                      controller: _searchCtrl,
                      focusNode: _routeSearchFocus,
                      enabled: !_loading && !_tracking,
                      showDropdown: _showDropdown,
                      filtered: _filtered,
                      onClear:
                          !_tracking && !_loading ? _clearRouteSelection : null,
                      onSelect: _selectRoute,
                    ),
                    if (_activeRoute != null) ...[
                      const SizedBox(height: 12),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF185FA5).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color:
                                const Color(0xFF185FA5).withValues(alpha: 0.3),
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFF185FA5),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                _activeRoute!.number,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                '${_activeRoute!.from} -> ${_activeRoute!.to}',
                                style: const TextStyle(
                                  color: AppTheme.textPrimary,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            Text(
                              '${_activeRoute!.stopIds.length} stops',
                              style: const TextStyle(
                                color: AppTheme.textMuted,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    if (_tracking) ...[
                      const SizedBox(height: 10),
                      const Text(
                        'Stop tracking before choosing another route number.',
                        style: TextStyle(
                          color: AppTheme.textMuted,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Text(
                AppLanguage.instance.t('Bus Type', 'బస్సు రకం'),
                style: TextStyle(
                  color: AppTheme.textMuted,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: BusTypes.inService.map((type) {
                  final selected = _resolvedBusType == type;
                  final color = Color(type.colorValue);
                  return GestureDetector(
                    onTap: _loading || _tracking
                        ? null
                        : () async {
                            setState(() => _busType = type);
                            await _trackingService.setDraftBusType(type);
                          },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: selected
                            ? color.withValues(alpha: 0.16)
                            : AppTheme.surface,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: selected ? color : AppTheme.divider,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.directions_bus_filled_outlined,
                            size: 16,
                            color: selected ? color : AppTheme.textMuted,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            AppLanguage.instance.isTelugu
                                ? type.labelTelugu
                                : type.label,
                            style: TextStyle(
                              color: selected ? color : AppTheme.textSecondary,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
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
                  color:
                      Color(_resolvedBusType.colorValue).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: Color(_resolvedBusType.colorValue)
                        .withValues(alpha: 0.3),
                  ),
                ),
                child: Text(
                  _activeRoute == null
                      ? AppLanguage.instance.t('Pick From - To to start', 'ప్రారంభించడానికి నుండి - వరకు ఎంచుకೋండి')
                      : 'Running today as: ${_resolvedBusType.label}',
                  style: TextStyle(
                    color: Color(_resolvedBusType.colorValue),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              _SectionCard(
                title: AppLanguage.instance.t('From - To Stops', 'నుండి - వరకు స్టాప్‌లు'),
                titleTelugu: 'స్టాప్‌లు',
                accent: const Color(0xFF1D9E75),
                icon: Icons.route_outlined,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _StopEndpointRow(
                      label: 'From',
                      stopName: VizagStops.all[_tripFromStopId]?.name ??
                          AppLanguage.instance.t('Pick start stop', 'ప్రారంభ స్టాప్ ఎంచుకోండి'),
                      color: const Color(0xFF1D9E75),
                      enabled: !_tracking && !_loading,
                      onTap: () => _pickTripStop(isFrom: true),
                    ),
                    const Padding(
                      padding: EdgeInsets.only(left: 9),
                      child: _SectionVLine(),
                    ),
                    _StopEndpointRow(
                      label: 'To',
                      stopName: VizagStops.all[_tripToStopId]?.name ??
                          AppLanguage.instance.t('Pick destination stop', 'గమ్య స్టాప్ ఎంచుకోండి'),
                      color: const Color(0xFFE24B4A),
                      enabled: !_tracking && !_loading,
                      onTap: () => _pickTripStop(isFrom: false),
                    ),
                    const SizedBox(height: 12),
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
                                ? AppLanguage.instance.t(
                                    'GPS will detect the current stop.',
                                    'గ్పస్ ప్రస్తుత స్టాప్ ని గుర్తిస్తుంది.')
                                : (_segmentProgress ?? 0) > 0.02 &&
                                        (_segmentProgress ?? 0) < 0.98
                                    ? '${AppLanguage.instance.t('Between stops', 'స్టాప్ల మధ్యలో')} · ${(100 * (_segmentProgress ?? 0)).round()}% ${AppLanguage.instance.t('to', 'కఁ')} $_nextStopName'
                                    : '${AppLanguage.instance.t('Next stop', 'తదుపరి స్టాప్')}: $_nextStopName',
                            style: const TextStyle(
                              color: AppTheme.textMuted,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (_returnRoute != null) ...[
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: _loading ? null : _reverseDirection,
                          icon: const Icon(Icons.swap_horiz, size: 18),
                          label: Text(
                            'Switch to ${_returnRoute!.number}: ${_returnRoute!.from} -> ${_returnRoute!.to}',
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
              Text(
                AppLanguage.instance.t('Crowd Level', 'క్రౌడ్ లెవెల్'),
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
                  final labels = [
                    AppLanguage.instance.t('Empty', 'ఖాళీ'),
                    AppLanguage.instance.t('Moderate', 'మధ్యస్థము'),
                    AppLanguage.instance.t('Full', 'నిండిపోయింది'),
                  ];
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
                title: Text(
                  AppLanguage.instance.t(
                    'Auto-detect stops from GPS',
                    'గ్పస్ ద్వారా స్టాప్లు గుర్తించు',
                  ),
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                subtitle: Text(
                  AppLanguage.instance.t(
                    'Moves forward as the bus enters each stop zone (0.5-1 km by stop spacing).',
                    'బస్సు స్టాప్ జోన్ లోకి వచ్చినప్పుడు ముందుకు వెళ్తుంది (0.5-1 కి.మీ).',
                  ),
                  style: const TextStyle(
                    color: AppTheme.textMuted,
                    fontSize: 12,
                  ),
                ),
              ),
              if (!_autoStopEnabled && _tracking) ...[
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.surface,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppTheme.divider),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Manual Stop Control',
                        style: TextStyle(
                          color: AppTheme.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Use only if GPS misses a stop.',
                        style: TextStyle(
                          color: AppTheme.textMuted,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _loading ||
                                      !_trackingService.canMoveToPreviousStop
                                  ? null
                                  : () async {
                                      setState(() => _loading = true);
                                      try {
                                        await _trackingService
                                            .moveToPreviousStop();
                                      } finally {
                                        if (mounted) {
                                          setState(() => _loading = false);
                                          _syncFromService();
                                        }
                                      }
                                    },
                              icon: const Icon(Icons.chevron_left, size: 18),
                              label: const Text('Previous Stop'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: _loading ||
                                      !_trackingService.canAdvanceToNextStop
                                  ? null
                                  : () async {
                                      setState(() => _loading = true);
                                      try {
                                        await _trackingService
                                            .advanceToNextStop();
                                      } finally {
                                        if (mounted) {
                                          setState(() => _loading = false);
                                          _syncFromService();
                                        }
                                      }
                                    },
                              icon: const Icon(Icons.chevron_right, size: 18),
                              label: const Text('Next Stop'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF185FA5),
                                foregroundColor: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
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
                        : Text(
                            AppLanguage.instance.t('Sync Now', 'ఇప్పుడే పంపు'),
                            style: const TextStyle(
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
                  child: ElevatedButton(
                    onPressed: _loading ? null : _stopTracking,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFE24B4A),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      AppLanguage.instance.t('Stop Tracking', 'ట్రాకింగ్ ఆపు'),
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
                      ? 'Live tracking is active. Stop tracking before changing the route number.'
                      : 'Select a route, choose the bus type, and start tracking once',
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
                    color: const Color(0xFF185FA5).withValues(alpha: 0.15),
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
          if (busTypeLabel != null) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
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
  final VoidCallback? onClear;
  final Future<void> Function(BusRoute) onSelect;

  const _RouteSearchField({
    required this.controller,
    required this.focusNode,
    required this.enabled,
    required this.showDropdown,
    required this.filtered,
    this.onClear,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ValueListenableBuilder<TextEditingValue>(
          valueListenable: controller,
          builder: (context, value, _) {
            return TextField(
              controller: controller,
              focusNode: focusNode,
              enabled: enabled,
              style: const TextStyle(color: AppTheme.textPrimary),
              decoration: InputDecoration(
                hintText: 'Search bus number (e.g. 28K, 38Y)',
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
                suffixIcon: value.text.trim().isEmpty || onClear == null
                    ? null
                    : IconButton(
                        onPressed: onClear,
                        tooltip: 'Clear route',
                        icon: const Icon(
                          Icons.close,
                          color: AppTheme.textMuted,
                          size: 20,
                        ),
                      ),
              ),
            );
          },
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
                      color: Color(route.busType.colorValue)
                          .withValues(alpha: 0.15),
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

/// Card chrome for the two route-setup sections (Route ID / From-To Stops).
class _SectionCard extends StatelessWidget {
  final String title;
  final String titleTelugu;
  final Color accent;
  final IconData icon;
  final Widget child;

  const _SectionCard({
    required this.title,
    required this.titleTelugu,
    required this.accent,
    required this.icon,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: accent.withValues(alpha: 0.35), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 16, color: accent),
              ),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  color: accent,
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                titleTelugu,
                style: TextStyle(
                  color: accent.withValues(alpha: 0.75),
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _StopEndpointRow extends StatelessWidget {
  final String label;
  final String stopName;
  final Color color;
  final bool enabled;
  final VoidCallback? onTap;

  const _StopEndpointRow({
    required this.label,
    required this.stopName,
    required this.color,
    this.enabled = true,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Opacity(
        opacity: enabled ? 1 : 0.55,
        child: Row(
          children: [
            Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                shape: BoxShape.circle,
                border: Border.all(color: color, width: 2),
              ),
            ),
            const SizedBox(width: 10),
            SizedBox(
              width: 42,
              child: Text(
                label == 'From'
                    ? AppLanguage.instance.t('From', 'నుండి')
                    : label == 'To'
                        ? AppLanguage.instance.t('To', 'వరకు')
                        : label,
                style: const TextStyle(
                  color: AppTheme.textMuted,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                stopName,
                style: const TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Icon(
              Icons.expand_more,
              size: 20,
              color: enabled ? color : AppTheme.textMuted,
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionVLine extends StatelessWidget {
  const _SectionVLine();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1.5,
      height: 10,
      margin: const EdgeInsets.symmetric(vertical: 2),
      color: AppTheme.divider,
    );
  }
}
