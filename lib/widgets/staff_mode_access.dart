import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../data/vizag_data.dart';
import '../screens/conductor_screen.dart';
import '../services/firestore_service.dart';
import '../utils/app_language.dart';
import '../utils/app_theme.dart';

Future<void> showStaffModeAccessSheet(
  BuildContext context, {
  String title = 'Staff Mode',
  String subtitle = 'Enter the staff password to open conductor tracking.',
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
  final TextEditingController _controller = TextEditingController();
  final FocusNode _passwordFocus = FocusNode();
  bool _submitting = false;
  bool _obscure = true;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final lang = AppLanguage.instance;
    final value = _controller.text.trim();

    FocusScope.of(context).unfocus();
    setState(() {
      _submitting = true;
      _error = null;
    });

    // The entered password IS the shared staff account's Firebase Auth
    // password. Verification, brute-force lockout and revocation (rotate
    // the password in the console) are handled by Firebase Auth — nothing
    // secret lives in the app binary and no per-device approval is needed.
    final firestore = FirestoreService();
    StaffAccessStatus status;
    try {
      status = await firestore.signInAsStaff(value);
    } on FirebaseAuthException catch (e) {
      await Future<void>.delayed(const Duration(milliseconds: 800));
      if (!mounted) return;
      setState(() {
        _submitting = false;
        if (e.code == 'network-requested' ||
            e.code == 'network-request-failed') {
          _error = lang.t(
            'Could not verify right now — check internet and retry.',
            'ఇప్పుడు సరిచూడలేం — ఇంటర్నెట్ తనిఖీ చేసి మళ్లీ ప్రయత్నించండి.',
          );
        } else if (e.code == 'too-many-requests') {
          _error = lang.t(
            'Too many attempts — try again in a few minutes.',
            'చాలా ప్రయత్నాలు — కొన్ని నిమిషాల్లో ప్రయత్నించండి.',
          );
        } else if (e.code == 'user-not-found' || e.code == 'operation-not-allowed') {
          _error = 'Staff account not set up yet — create '
              '${FirestoreService.staffEmail} in Firebase Authentication.';
        } else {
          _error = lang.t('Invalid password', 'తప్పు పాస్‌వర్డ్');
        }
      });
      return;
    } catch (e) {
      debugPrint('StaffModeAccess: staff sign-in unavailable: $e');
      if (!mounted) return;
      final detail = e.toString();
      final short =
          detail.length > 160 ? '${detail.substring(0, 160)}…' : detail;
      setState(() {
        _submitting = false;
        _error = lang.t(
              'Could not verify right now — check internet and retry.',
              'ఇప్పుడు సరిచూడలేం — ఇంటర్నెట్ తనిఖీ చేసి మళ్లీ ప్రయత్నించండి.',
            ) +
            ' ($short)';
      });
      return;
    }

    if (!mounted) return;

    if (!status.isConductor) {
      setState(() => _submitting = false);
      // One-time setup: the shared staff account exists but the depot admin
      // has not granted it the conductor role yet.
      await _showConductorRegistrationDialog(context, status.uid);
      return;
    }

    Navigator.pop(context, true);
  }

  Future<void> _showConductorRegistrationDialog(
    BuildContext dialogContext,
    String uid,
  ) {
    final lang = AppLanguage.instance;
    return showDialog<void>(
      context: dialogContext,
      builder: (dialogBuilder) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: Text(
          lang.t('Conductor approval needed', 'కండక్టర్ ఆమోదం అవసరం'),
          style: const TextStyle(
            color: Color(0xFFBA7517),
            fontSize: 17,
            fontWeight: FontWeight.w800,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              lang.t(
                'This device is not approved to publish live buses yet. '
                'Send this code to the depot admin:',
                '\u0c08 \u0c2b\u0c4b\u0c28\u0c4d \u0c07\u0c02\u0c15\u0c3e \u0c32\u0c48\u0c35\u0c4d \u0c2c\u0c38\u0c4d\u0c38\u0c41\u0c32 \u0c15\u0c4b\u0c38\u0c02 \u0c06\u0c2e\u0c4b\u0c26\u0c3f\u0c02\u0c1a\u0c2c\u0c21\u0c32\u0c47\u0c26\u0c41. '
                    '\u0c08 \u0c15\u0c4b\u0c21\u0c4d \u0c21\u0c3f\u0c2a\u0c4b \u0c05\u0c2d\u0c4d\u0c2f\u0c02\u0c24\u0c4d\u0c30\u0c2f\u0c3f\u0c15\u0c41 \u0c2a\u0c02\u0c2a\u0c02\u0c21\u0c3f:'),
              style:  TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 13,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.card,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppTheme.border),
              ),
              child: SelectableText(
                uid,
                style:  TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(
              lang.t('OK', '\u0c38\u0c30\u0c47'),
              style:  TextStyle(color: AppTheme.green),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final lang = AppLanguage.instance;
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
                lang.t(widget.title, 'స్టాఫ్ మోడ్'),
                style:  TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                lang.t(
                  'Enter the staff password to open conductor tracking.',
                  'కండక్టర్ ట్రాకింగ్ తెరవడానికి స్టాఫ్ పాస్‌వర్డ్ నిల్లండండి.',
                ),
                style:  TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _controller,
                focusNode: _passwordFocus,
                autofocus: true,
                obscureText: _obscure,
                enableSuggestions: false,
                autocorrect: false,
                enabled: !_submitting,
                textInputAction: TextInputAction.done,
                style:  TextStyle(color: AppTheme.textPrimary),
                decoration: InputDecoration(
                  hintText: lang.t('Staff password', 'స్టాఫ్ పాస్‌వర్డ్'),
                  hintStyle:  TextStyle(color: AppTheme.textMuted),
                  filled: true,
                  fillColor: AppTheme.card,
                  errorText: _error,
                  suffixIcon: IconButton(
                    onPressed: () => setState(() => _obscure = !_obscure),
                    icon: Icon(
                      _obscure
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                      size: 20,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide:  BorderSide(color: AppTheme.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide:  BorderSide(color: AppTheme.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide:  BorderSide(color: AppTheme.green),
                  ),
                ),
                onSubmitted: (_) {
                  if (!_submitting) {
                    _submit();
                  }
                },
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _submitting ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.green,
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
                          lang.t('Open Staff Mode', 'స్టాఫ్ మోడ్ తెరవండి'),
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
