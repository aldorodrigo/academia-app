import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/utils/validators.dart';
import '../data/session_controller.dart';

/// Código de 6 dígitos que llega por WhatsApp (o por correo, si la cuenta se
/// creó con el correo). Al verificarlo, el router sigue (a "Tu club" si
/// todavía no tiene organización).
class VerifyAccountScreen extends ConsumerStatefulWidget {
  const VerifyAccountScreen({super.key});

  /// Segundos de espera para volver a pedir el código.
  static const resendSeconds = 60;

  @override
  ConsumerState<VerifyAccountScreen> createState() =>
      _VerifyAccountScreenState();
}

class _VerifyAccountScreenState extends ConsumerState<VerifyAccountScreen> {
  final _code = TextEditingController();
  bool _loading = false;
  String? _error;
  String? _info;
  int _wait = VerifyAccountScreen.resendSeconds;

  /// El usuario pidió el código por correo en lugar de WhatsApp.
  bool _byEmail = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _code.dispose();
    super.dispose();
  }

  void _startTimer() {
    _timer?.cancel();
    setState(() => _wait = VerifyAccountScreen.resendSeconds);
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_wait <= 1) timer.cancel();
      setState(() => _wait--);
    });
  }

  Future<void> _submit() async {
    final error = validateCode(_code.text);
    if (error != null) {
      setState(() => _error = error);
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
      _info = null;
    });
    try {
      await ref
          .read(sessionControllerProvider.notifier)
          .verify(_code.text.trim());
    } catch (e) {
      if (mounted) setState(() => _error = apiErrorMessage(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _resend({bool byEmail = false}) async {
    setState(() {
      _error = null;
      _info = null;
    });
    try {
      await ref
          .read(sessionControllerProvider.notifier)
          .resendCode(byEmail: byEmail);
      _code.clear();
      _startTimer();
      setState(() {
        _byEmail = byEmail || _byEmail;
        _info = byEmail
            ? 'Te mandamos un código nuevo por correo.'
            : 'Te mandamos un código nuevo.';
      });
    } catch (e) {
      setState(() => _error = apiErrorMessage(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final session = ref.watch(sessionControllerProvider).value;
    final byWhatsApp = session?.phone != null && !_byEmail;
    final destination = byWhatsApp ? session!.contact : session?.email ?? '';
    final canUseEmail = byWhatsApp && session!.email != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(byWhatsApp ? 'Confirmá tu número' : 'Confirmá tu correo'),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Icon(
                    byWhatsApp
                        ? Icons.mark_chat_read_outlined
                        : Icons.mark_email_read_outlined,
                    size: 48,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    byWhatsApp
                        ? 'Te mandamos un código de 6 dígitos por WhatsApp al'
                        : 'Te mandamos un código de 6 dígitos a',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyLarge,
                  ),
                  Text(
                    destination,
                    key: const Key('destination'),
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleMedium,
                  ),
                  if (!byWhatsApp) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Si no lo ves, revisá la carpeta de spam.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                  const SizedBox(height: 24),
                  TextField(
                    key: const Key('code'),
                    controller: _code,
                    autofocus: true,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      letterSpacing: 8,
                    ),
                    keyboardType: TextInputType.number,
                    autofillHints: const [AutofillHints.oneTimeCode],
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(6),
                    ],
                    decoration: const InputDecoration(
                      labelText: 'Código',
                      counterText: '',
                    ),
                    onChanged: (value) {
                      if (value.length == 6 && !_loading) _submit();
                    },
                    onSubmitted: (_) => _submit(),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 16),
                    Text(
                      _error!,
                      style: TextStyle(color: theme.colorScheme.error),
                    ),
                  ],
                  if (_info != null) ...[
                    const SizedBox(height: 16),
                    Text(_info!),
                  ],
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: _loading ? null : _submit,
                    child: _loading
                        ? const SizedBox.square(
                            dimension: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Confirmar'),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: _wait > 0 ? null : _resend,
                    child: Text(
                      _wait > 0
                          ? 'Reenviar código en $_wait s'
                          : 'Reenviar código',
                    ),
                  ),
                  if (canUseEmail)
                    TextButton(
                      key: const Key('resend-email'),
                      onPressed: _wait > 0
                          ? null
                          : () => _resend(byEmail: true),
                      child: const Text('¿No te llegó? Mandámelo por correo'),
                    ),
                  TextButton(
                    onPressed: () =>
                        ref.read(sessionControllerProvider.notifier).logout(),
                    child: Text(
                      byWhatsApp
                          ? '¿No es tu número? Empezar de nuevo'
                          : '¿No es tu correo? Empezar de nuevo',
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
