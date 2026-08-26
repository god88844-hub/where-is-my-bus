import 'package:flutter/material.dart';

import '../data/vizag_data.dart';
import '../services/firestore_service.dart';
import '../utils/app_language.dart';
import '../utils/app_theme.dart';

/// Passenger complaint sheet — report a bus that didn't stop, or other
/// service problems. Writes to the Firestore `complaints` collection.
class ComplaintSheet extends StatefulWidget {
  final String? routeNumber;
  final String? stopId;
  final String? busId;

  const ComplaintSheet({
    super.key,
    this.routeNumber,
    this.stopId,
    this.busId,
  });

  static Future<void> show(
    BuildContext context, {
    String? routeNumber,
    String? stopId,
    String? busId,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (_) => ComplaintSheet(
        routeNumber: routeNumber,
        stopId: stopId,
        busId: busId,
      ),
    );
  }

  @override
  State<ComplaintSheet> createState() => _ComplaintSheetState();
}

class _ComplaintSheetState extends State<ComplaintSheet> {
  static const _reasons = <(String, String, String)>[
    (
      'not_stopped',
      'Bus did not stop at the stop',
      '\u0c2c\u0c38\u0c4d\u0c38\u0c41 \u0c38\u0c4d\u0c1f\u0c3e\u0c2a\u0c4d \u0c35\u0c26\u0c4d\u0c26 \u0c06\u0c17\u0c32\u0c47\u0c26\u0c41',
    ),
    (
      'early',
      'Bus left before time',
      '\u0c2c\u0c38\u0c4d\u0c38\u0c41 \u0c38\u0c2e\u0c2f\u0c02 \u0c15\u0c02\u0c1f\u0c47 \u0c2e\u0c41\u0c02\u0c26\u0c47 \u0c2c\u0c2f\u0c32\u0c41\u0c21\u0c41 \u0c15\u0c3e\u0c32\u0c4d\u0c38\u0c3f\u0c02\u0c26\u0c3f',
    ),
    (
      'late',
      'Bus is running very late',
      '\u0c2c\u0c38\u0c4d\u0c38\u0c41 \u0c1a\u0c3e\u0c32\u0c3e \u0c06\u0c32\u0c38\u0c4d\u0c2f\u0c17\u0c3e \u0c89\u0c02\u0c26\u0c3f',
    ),
    (
      'skipped_stop',
      'Bus skipped a route stop',
      '\u0c2c\u0c38\u0c4d\u0c38\u0c41 \u0c30\u0c42\u0c1f\u0c4d \u0c38\u0c4d\u0c1f\u0c3e\u0c2a\u0c4d \u0c26\u0c3e\u0c1f\u0c47\u0c38\u0c3f\u0c02\u0c26\u0c3f',
    ),
    (
      'other',
      'Other problem',
      '\u0c07\u0c24\u0c30 \u0c38\u0c2e\u0c38\u0c4d\u0c2f',
    ),
  ];

  String? _selectedType;
  final _noteCtrl = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final type = _selectedType;
    if (type == null || _submitting) return;
    setState(() => _submitting = true);

    final lang = AppLanguage.instance;
    final ok = await FirestoreService().submitComplaint(
      type: type,
      routeNumber: widget.routeNumber,
      stopId: widget.stopId,
      busId: widget.busId,
      note: _noteCtrl.text.trim(),
    );

    if (!mounted) return;
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: ok ? AppTheme.green : AppTheme.card,
        content: Text(
          ok
              ? lang.t(
                  'Complaint sent. Thank you.',
                  '\u0c2b\u0c3f\u0c30\u0c4d\u0c2f\u0c3e\u0c26\u0c41 \u0c2a\u0c02\u0c2a\u0c2c\u0c21\u0c3f\u0c02\u0c26\u0c3f. \u0c27\u0c28\u0c4d\u0c2f\u0c35\u0c3e\u0c26\u0c3e\u0c32\u0c41.')
              : lang.t(
                  'Could not send right now. Try again later.',
                  '\u0c07\u0c2a\u0c4d\u0c2a\u0c41\u0c21\u0c41 \u0c2a\u0c02\u0c2a\u0c21\u0c02 \u0c38\u0c3e\u0c27\u0c4d\u0c2f\u0c02 \u0c15\u0c3e\u0c32\u0c47\u0c26\u0c41. \u0c24\u0c30\u0c4d\u0c35\u0c3e\u0c24 \u0c2a\u0c4d\u0c30\u0c2f\u0c24\u0c4d\u0c28\u0c3f\u0c02\u0c1a\u0c02\u0c21\u0c3f.'),
          style: TextStyle(
            color: ok ? Colors.white : AppTheme.textPrimary,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final lang = AppLanguage.instance;
    final stopName =
        widget.stopId == null ? null : VizagStops.get(widget.stopId!)?.name;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          20,
          20,
          MediaQuery.viewInsetsOf(context).bottom + 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.report_problem_outlined,
                  color: Color(0xFFBA7517),
                  size: 22,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    lang.t('Report a problem', '\u0c38\u0c2e\u0c38\u0c4d\u0c2f \u0c28\u0c3f\u0c35\u0c47\u0c26\u0c3f\u0c02\u0c1a\u0c41'),
                    style: const TextStyle(
                      color: Color(0xFFBA7517),
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            if (stopName != null ||
                (widget.routeNumber ?? '').isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                [
                  if ((widget.routeNumber ?? '').isNotEmpty)
                    lang.t('Route', '\u0c30\u0c42\u0c1f\u0c4d') + ': ${widget.routeNumber}',
                  if (stopName != null)
                    lang.t('Stop', '\u0c38\u0c4d\u0c1f\u0c3e\u0c2a\u0c4d') + ': $stopName',
                ].join('  ·  '),
                style:  TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
            const SizedBox(height: 14),
            ..._reasons.map((reason) {
              final selected = _selectedType == reason.$1;
              return InkWell(
                onTap: () => setState(() => _selectedType = reason.$1),
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: selected
                        ? AppTheme.green.withValues(alpha: 0.12)
                        : AppTheme.card,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: selected ? AppTheme.green : AppTheme.border,
                      width: selected ? 1 : 0.5,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        selected
                            ? Icons.radio_button_checked
                            : Icons.radio_button_off,
                        size: 18,
                        color: selected ? AppTheme.green : AppTheme.textMuted,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          lang.t(reason.$2, reason.$3),
                          style:  TextStyle(
                            color: AppTheme.textPrimary,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
            const SizedBox(height: 4),
            TextField(
              controller: _noteCtrl,
              maxLines: 2,
              style:  TextStyle(color: AppTheme.textPrimary, fontSize: 14),
              decoration: InputDecoration(
                hintText: lang.t(
                  'Details (optional)',
                  '\u0c35\u0c3f\u0c35\u0c30\u0c3e\u0c32\u0c41 (\u0c10\u0c1a\u0c4d\u0c1b\u0c3f\u0c15\u0c02)'),
                hintStyle:  TextStyle(color: AppTheme.textMuted),
                filled: true,
                fillColor: AppTheme.card,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide:  BorderSide(color: AppTheme.border),
                ),
              ),
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _selectedType == null || _submitting ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFBA7517),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _submitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        lang.t('Send complaint', '\u0c2b\u0c3f\u0c30\u0c4d\u0c2f\u0c3e\u0c26\u0c41 \u0c2a\u0c02\u0c2a\u0c41'),
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
