// lib/widgets/shared_widgets.dart

import 'package:flutter/material.dart';
import '../models/bus.dart';
import '../data/vizag_data.dart';
import '../utils/app_theme.dart';

// ── Route number badge ──────────────────────────────────────────────
class RouteBadge extends StatelessWidget {
  final String number;
  final double fontSize;
  const RouteBadge(this.number, {super.key, this.fontSize = 12});

  @override
  Widget build(BuildContext context) {
    final color = AppTheme.routeColor(number);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.4), width: 0.5),
      ),
      child: Text(number.replaceAll(RegExp(r'-R$'), ''),
          style: TextStyle(
              color: color,
              fontSize: fontSize,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.3)),
    );
  }
}

// ── Crowd indicator ────────────────────────────────────────────────
class CrowdBar extends StatelessWidget {
  final BusCrowd crowd;
  const CrowdBar(this.crowd, {super.key});

  @override
  Widget build(BuildContext context) {
    final (label, color, filled) = switch (crowd) {
      BusCrowd.empty => ('Empty', AppTheme.green, 1),
      BusCrowd.moderate => ('Moderate', AppTheme.amber, 2),
      BusCrowd.full => ('Full', AppTheme.red, 3),
    };
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ...List.generate(
            3,
            (i) => Container(
                  width: 6,
                  height: 10,
                  margin: const EdgeInsets.only(right: 2),
                  decoration: BoxDecoration(
                    color: i < filled ? color : color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(2),
                  ),
                )),
        const SizedBox(width: 4),
        Text(label,
            style: TextStyle(
                fontSize: 11, color: color, fontWeight: FontWeight.w500)),
      ],
    );
  }
}

// ── Source pill ────────────────────────────────────────────────────
class SourcePill extends StatelessWidget {
  final BusDataSource source;
  const SourcePill(this.source, {super.key});

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (source) {
      BusDataSource.beacon => ('● Live', AppTheme.green),
      BusDataSource.manual => ('✎ Updated', AppTheme.amber),
      BusDataSource.timetable => ('⏱ Scheduled', AppTheme.textSecondary),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.3), width: 0.5),
      ),
      child: Text(label,
          style: TextStyle(
              fontSize: 10, color: color, fontWeight: FontWeight.w600)),
    );
  }
}

class BusTypePill extends StatelessWidget {
  final BusType type;
  const BusTypePill(this.type, {super.key});

  @override
  Widget build(BuildContext context) {
    final color = Color(type.colorValue);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.3), width: 0.5),
      ),
      child: Text(
        type.label,
        style: TextStyle(
          fontSize: 10,
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

// ── Incoming bus card (used in nearby + stop detail) ────────────────
class IncomingBusCard extends StatelessWidget {
  final NearbyBus nb;
  final VoidCallback? onTap;

  const IncomingBusCard(this.nb, {super.key, this.onTap});

  @override
  Widget build(BuildContext context) {
    final bus = nb.bus;
    final stop = nb.stop;
    final route = bus.routeRef;
    final routeColor = AppTheme.routeColor(bus.routeNumber);
    final currentStop = VizagStops.resolve(bus.segmentStartIdResolved);
    final nextStop = bus.segmentEndIdResolved.isEmpty
        ? null
        : VizagStops.resolve(bus.segmentEndIdResolved);
    final busType = bus.routeBusType;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppTheme.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.border, width: 0.5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Row 1: badge + destination + ETA
            Row(
              children: [
                RouteBadge(bus.routeNumber),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(route?.name ?? bus.routeNumber,
                          style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: AppTheme.textPrimary),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                      if (route != null)
                        Text(route.nameTelugu,
                            style: const TextStyle(
                                fontSize: 11, color: AppTheme.textSecondary)),
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          BusTypePill(busType),
                          SourcePill(bus.source),
                        ],
                      ),
                    ],
                  ),
                ),
                // ETA bubble
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: nb.etaToStopMins <= 3
                        ? AppTheme.greenDim
                        : AppTheme.amberDim,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: nb.etaToStopMins <= 3
                          ? AppTheme.green.withValues(alpha: 0.4)
                          : AppTheme.amber.withValues(alpha: 0.4),
                      width: 0.5,
                    ),
                  ),
                  child: Column(
                    children: [
                      Text('${nb.etaToStopMins}',
                          style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              color: nb.etaToStopMins <= 3
                                  ? AppTheme.green
                                  : AppTheme.amber)),
                      Text('min',
                          style: TextStyle(
                              fontSize: 10,
                              color: nb.etaToStopMins <= 3
                                  ? AppTheme.green
                                  : AppTheme.amber)),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 10),
            const Divider(color: AppTheme.divider, height: 1),
            const SizedBox(height: 10),

            // Row 2: current stop → next stop + crowd + source
            Row(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Icon(Icons.location_on_outlined,
                          size: 12, color: routeColor),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          _stopName(currentStop.id) +
                              (nextStop != null ? ' → ${nextStop.name}' : ''),
                          style: const TextStyle(
                              fontSize: 11, color: AppTheme.textSecondary),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                CrowdBar(bus.crowd),
                const SizedBox(width: 8),
                SourcePill(bus.source),
              ],
            ),

            if (bus.hasContinuousProgress && nextStop != null) ...[
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  minHeight: 6,
                  value: bus.segmentProgressResolved,
                  backgroundColor: routeColor.withValues(alpha: 0.12),
                  valueColor: AlwaysStoppedAnimation<Color>(routeColor),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '${(bus.segmentProgressResolved * 100).round()}% to ${nextStop.name}'
                '${bus.distanceToNextStopKmResolved == null ? '' : ' · ${bus.distanceToNextStopKmResolved!.toStringAsFixed(2)} km left'}',
                style: const TextStyle(
                  fontSize: 11,
                  color: AppTheme.textSecondary,
                ),
              ),
            ],

            if (nb.distanceKm > 0) ...[
              const SizedBox(height: 6),
              Text(
                'Stop ${stop.name} · ${(nb.distanceKm * 1000).round()} m away',
                style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _stopName(String id) => VizagStops.resolve(id).name;
}

// ── Section header ─────────────────────────────────────────────────
class SectionHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? action;
  const SectionHeader(this.title, {super.key, this.subtitle, this.action});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 10),
        child: Row(
          children: [
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title,
                  style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary)),
              if (subtitle != null)
                Text(subtitle!,
                    style: const TextStyle(
                        fontSize: 11, color: AppTheme.textSecondary)),
            ]),
            const Spacer(),
            if (action != null) action!,
          ],
        ),
      );
}

// ── Empty state ────────────────────────────────────────────────────
class EmptyState extends StatelessWidget {
  final String message;
  final String? sub;
  final IconData icon;
  const EmptyState(this.message,
      {super.key, this.sub, this.icon = Icons.directions_bus_outlined});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 40, color: AppTheme.textMuted),
            const SizedBox(height: 12),
            Text(message,
                style: const TextStyle(
                    fontSize: 14,
                    color: AppTheme.textSecondary,
                    fontWeight: FontWeight.w500),
                textAlign: TextAlign.center),
            if (sub != null) ...[
              const SizedBox(height: 6),
              Text(sub!,
                  style:
                      const TextStyle(fontSize: 12, color: AppTheme.textMuted),
                  textAlign: TextAlign.center),
            ],
          ],
        ),
      );
}
