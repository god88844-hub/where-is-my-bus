import 'package:flutter/material.dart';

import '../screens/conductor_screen.dart';
import '../services/firestore_service.dart';
import '../utils/app_theme.dart';

Future<void> showStaffModeAccessSheet(
  BuildContext context, {
  String title = 'Staff Mode',
  String subtitle = 'Tap below to verify your staff access.',
  String buttonLabel = 'Open Staff Mode',
}) async {
  final shouldOpenConductor = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppTheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
    ),
    builder: (_) => _StaffModeAccessSheet(
      title: title,
      subtitle: subtitle,
      buttonLabel: buttonLabel,
    ),
  );

  if (shouldOpenConductor == true && context.mounted) {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ConductorScreen()),
    );
  }
}

class _StaffModeAccessSheet extends StatefulWidget {
  final String title;
  final String subtitle;
  final String buttonLabel;

  const _StaffModeAccessSheet({
    required this.title,
    required this.subtitle,
    required this.buttonLabel,
  });

  @override
  State<_StaffModeAccessSheet> createState() => _StaffModeAccessSheetState();
}

class _StaffModeAccessSheetState extends State<_StaffModeAccessSheet> {
  bool _submitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    // Immediately verify staff access on open — no client-side code gate.
    _verifyAccess();
  }

  Future<void> _verifyAccess() async {
    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      final status = await FirestoreService().getStaffAccessStatus();
      if (!mounted) return;

      if (!status.isConductor) {
        setState(() {
          _submitting = false;
          _error = 'This account is not approved for conductor mode';
        });

        await showDialog<void>(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: AppTheme.surface,
            title: const Text(
              'Approve This Device',
              style: TextStyle(color: AppTheme.textPrimary),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Add this UID in Firestore under users/{uid} with role = conductor or admin, then try again.',
                  style: TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Current UID',
                  style: TextStyle(
                    color: AppTheme.textMuted,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                SelectableText(
                  status.uid,
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
            ],
          ),
        );
        return;
      }

      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _error = 'Could not verify staff access. Please try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return SafeArea(
      top: false,
      child: AnimatedPadding(
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOut,
        padding: EdgeInsets.fromLTRB(20, 20, 20, bottomInset + 20),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.title,
                style: const TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                _submitting ? 'Verifying your staff access...' : widget.subtitle,
                style: const TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 16),
              if (_error != null) ...[                Text(
                  _error!,
                  style: const TextStyle(
                    color: AppTheme.red,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 14),
              ],
              if (_submitting)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 14),
                    child: SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppTheme.green,
                      ),
                    ),
                  ),
                )
              else
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _verifyAccess,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      widget.buttonLabel,
                      style: const TextStyle(fontWeight: FontWeight.w700),
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
