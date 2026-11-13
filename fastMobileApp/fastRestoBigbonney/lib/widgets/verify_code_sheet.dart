import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../api/api_exceptions.dart';
import '../l10n/tr.dart';
import '../providers/auth_provider.dart';
import '../services/auth_service.dart';
import '../theme.dart';
import 'fast_ui.dart';

enum VerifyTarget { email, phone }

/// Bottom sheet that sends a 6-digit code to the account's email or phone
/// and confirms it. Returns `true` when the address/number is verified.
Future<bool> showVerifyCodeSheet(
  BuildContext context, {
  required VerifyTarget target,
  required String destination,
}) async {
  final ok = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) =>
        _VerifyCodeSheet(target: target, destination: destination),
  );
  return ok ?? false;
}

class _VerifyCodeSheet extends StatefulWidget {
  final VerifyTarget target;
  final String destination;

  const _VerifyCodeSheet({required this.target, required this.destination});

  @override
  State<_VerifyCodeSheet> createState() => _VerifyCodeSheetState();
}

class _VerifyCodeSheetState extends State<_VerifyCodeSheet> {
  final _code = TextEditingController();
  final _service = AuthService();
  Timer? _ticker;
  int _cooldown = 0;
  bool _sending = false;
  bool _verifying = false;
  bool _sent = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _send();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _code.dispose();
    super.dispose();
  }

  void _startCooldown() {
    _ticker?.cancel();
    setState(() => _cooldown = 60);
    _ticker = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return t.cancel();
      setState(() => _cooldown--);
      if (_cooldown <= 0) t.cancel();
    });
  }

  Future<void> _send() async {
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      final devCode = widget.target == VerifyTarget.email
          ? await _service.requestEmailCode()
          : await _service.requestPhoneCodeDev(widget.destination);
      if (!mounted) return;
      // A dev backend without a mail/SMS provider returns the code.
      if (kDebugMode && devCode != null) _code.text = devCode;
      setState(() => _sent = true);
      _startCooldown();
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = tr(context, 'generic_error'));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _verify() async {
    final code = _code.text.trim();
    if (code.length != 6) return;
    setState(() {
      _verifying = true;
      _error = null;
    });
    final auth = context.read<AuthProvider>();
    try {
      if (widget.target == VerifyTarget.email) {
        await _service.verifyEmailCode(code);
        auth.markVerified(email: true);
      } else {
        await _service.confirmAccountPhone(widget.destination, code);
        auth.markVerified(phone: true, newPhone: widget.destination);
      }
      if (!mounted) return;
      HapticFeedback.mediumImpact();
      Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (!mounted) return;
      HapticFeedback.heavyImpact();
      _code.clear();
      setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = tr(context, 'generic_error'));
    } finally {
      if (mounted) setState(() => _verifying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final fast = context.fast;
    final isEmail = widget.target == VerifyTarget.email;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        FASTSpace.s24,
        FASTSpace.s24,
        FASTSpace.s24,
        MediaQuery.viewInsetsOf(context).bottom + FASTSpace.s24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: const BoxDecoration(
                  gradient: FASTBrand.ctaGradient,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isEmail ? Icons.mark_email_read_outlined : Icons.sms_outlined,
                  color: Colors.white,
                  size: 22,
                ),
              ),
              const SizedBox(width: FASTSpace.s12),
              Expanded(
                child: Text(
                  tr(
                    context,
                    isEmail ? 'verify_email_title' : 'verify_phone_title',
                  ),
                  style: FASTText.item.copyWith(color: fast.t1),
                ),
              ),
            ],
          ),
          const SizedBox(height: FASTSpace.s16),
          Text(
            tr(context, 'verify_code_hint'),
            style: FASTText.body.copyWith(color: fast.t2),
          ),
          const SizedBox(height: FASTSpace.s4),
          Text(
            widget.destination,
            textDirection: TextDirection.ltr,
            style: FASTText.body.copyWith(
              color: fast.t1,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: FASTSpace.s16),
          TextField(
            controller: _code,
            autofocus: true,
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            maxLength: 6,
            autofillHints: const [AutofillHints.oneTimeCode],
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w900,
              letterSpacing: 10,
            ),
            decoration: InputDecoration(
              counterText: '',
              hintText: '••••••',
              errorText: _error,
              errorMaxLines: 3,
            ),
            onChanged: (v) {
              if (v.length == 6) _verify();
            },
          ),
          const SizedBox(height: FASTSpace.s16),
          FastButton(
            label: tr(context, 'verify_confirm'),
            loading: _verifying,
            onPressed: _sent ? _verify : null,
          ),
          const SizedBox(height: FASTSpace.s8),
          Center(
            child: TextButton(
              onPressed: _sending || _cooldown > 0 ? null : _send,
              child: Text(
                _cooldown > 0
                    ? '${tr(context, 'verify_resend_in')} ${_cooldown}s'
                    : tr(context, _sent ? 'resend_code' : 'verify_send_code'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
