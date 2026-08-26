import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/bus.dart';
import '../services/firestore_service.dart';
import '../services/location_service.dart';
import '../utils/app_language.dart';
import '../utils/app_theme.dart';

/// Emergency reporting, mirroring the depot VTS app: a 2x2 category grid
/// (Women Safety / Breakdown / Medical Assistance / Accident). The report
/// lands in Firestore with the device's GPS position attached.
Future<void> showEmergencyReportSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppTheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
    ),
    builder: (_) => const _EmergencyReportSheet(),
  );
}

class _EmergencyCategory {
  final String label;
  final String labelTelugu;
  final IconData icon;
  final Color color;

  const _EmergencyCategory(this.label, this.labelTelugu, this.icon, this.color);
}

class _EmergencyReportSheet extends StatefulWidget {
  const _EmergencyReportSheet();

  @override
  State<_EmergencyReportSheet> createState() => _EmergencyReportSheetState();
}

class _EmergencyReportSheetState extends State<_EmergencyReportSheet> {
  static const _categories = [
    _EmergencyCategory(
      'Women Safety',
      'మహిళల భద్రత',
      Icons.shield_outlined,
      Color(0xFF993556),
    ),
    _EmergencyCategory(
      'Report Breakdown',
      'బస్సు పని చేయడం లేదు',
      Icons.handyman_outlined,
      Color(0xFFBA7517),
    ),
    _EmergencyCategory(
      'Medical Assistance',
      'వైద్య సహాయం',
      Icons.medical_services_outlined,
      Color(0xFFE24B4A),
    ),
    _EmergencyCategory(
      'Report Accident',
      'ప్రమాదం',
      Icons.car_crash_outlined,
      Color(0xFF185FA5),
    ),
  ];

  _EmergencyCategory? _selected;
  final _noteCtrl = TextEditingController();
  bool _sending = false;
  String? _result; // null = still on the form, otherwise success message

  @override
  void dispose() {
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final category = _selected;
    if (category == null || _sending) return;
    setState(() => _sending = true);

    double? lat;
    double? lng;
    try {
      final pos = await LocationService.getCurrentPosition();
      lat = pos?.latitude;
      lng = pos?.longitude;
    } catch (_) {
      // Location is best-effort — the report still goes out.
    }

    final ok = await FirestoreService().submitEmergencyReport(
      type: category.label,
      note: _noteCtrl.text.trim(),
      lat: lat,
      lng: lng,
    );

    if (!mounted) return;
    setState(() {
      _sending = false;
      _result = ok
          ? 'Report sent. Help information has been shared.'
          : 'Could not send right now — check internet and retry.';
    });
  }

  @override
  Widget build(BuildContext context) {
    final lang = AppLanguage.instance;
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return SafeArea(
      top: false,
      child: AnimatedPadding(
        duration: const Duration(milliseconds: 150),
        padding: EdgeInsets.fromLTRB(20, 20, 20, bottomInset + 20),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.emergency_outlined,
                      size: 22, color: AppTheme.red),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      lang.t('Emergency Category', 'అత్యవసర విభాగం'),
                      style: TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                lang.t(
                  'Please select an emergency category',
                  'అత్యవసర విభాగాన్ని ఎంచుకోండి',
                ),
                style: TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 16),
              if (_result != null) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: (_result!.startsWith('Report sent')
                            ? AppTheme.green
                            : AppTheme.amber)
                        .withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: (_result!.startsWith('Report sent')
                              ? AppTheme.green
                              : AppTheme.amber)
                          .withValues(alpha: 0.4),
                    ),
                  ),
                  child: Text(
                    _result!,
                    style: TextStyle(
                      color: _result!.startsWith('Report sent')
                          ? AppTheme.green
                          : AppTheme.amber,
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ],
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 1.45,
                children: _categories.map((c) {
                  final selected = _selected == c;
                  return InkWell(
                    onTap: () => setState(() => _selected = c),
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: selected
                            ? c.color.withValues(alpha: 0.12)
                            : AppTheme.card,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: selected ? c.color : AppTheme.border,
                          width: selected ? 1.5 : 0.8,
                        ),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(c.icon, size: 34, color: c.color),
                          const SizedBox(height: 8),
                          Text(
                            lang.t(c.label, c.labelTelugu),
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: selected ? c.color : AppTheme.textPrimary,
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
              if (_selected != null && _result == null) ...[
                const SizedBox(height: 16),
                TextField(
                  controller: _noteCtrl,
                  maxLines: 2,
                  maxLength: 200,
                  style: TextStyle(color: AppTheme.textPrimary),
                  decoration: InputDecoration(
                    hintText: lang.t(
                        'What happened? (optional)',
                        'ఏం జరిగింది? (ఐచ్ఛికం)'),
                    hintStyle: TextStyle(color: AppTheme.textMuted),
                    filled: true,
                    fillColor: AppTheme.card,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: AppTheme.border),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: AppTheme.border),
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  lang.t(
                    'Your GPS location is attached automatically.',
                    'మీ GPS స్థానం స్వయంగా జోడించబడుతుంది.',
                  ),
                  style: TextStyle(color: AppTheme.textMuted, fontSize: 11),
                ),
                const SizedBox(height: 12),
              ],
              if (_selected != null && _result == null)
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _sending ? null : _send,
                    icon: _sending
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.send_outlined, size: 18),
                    label: Text(
                      lang.t('Send report', 'నివేదిక పంపండి'),
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.red,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () =>
                      launchUrl(Uri.parse('tel:112')), 
                  icon: const Icon(Icons.call_outlined, size: 18),
                  label: Text(
                    lang.t('Call emergency 112', 'అత్యవసరం 112 కు కాల్ చేయండి'),
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.red,
                    side: BorderSide(
                        color: AppTheme.red.withValues(alpha: 0.5)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
