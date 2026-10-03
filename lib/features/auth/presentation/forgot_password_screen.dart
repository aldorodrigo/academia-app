import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/api_client.dart';
import '../../../core/utils/validators.dart';
import '../data/session_controller.dart';

/// "Olvidé mi contraseña": primero el celular o el correo (llega un código por
/// WhatsApp o por correo), después el código y la contraseña nueva. Al
/// terminar, la sesión queda iniciada y el router sigue.
class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key, this.login});

  /// Lo que ya escribió en "Iniciar sesión".
  final String? login;

  @override
  ConsumerState<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  late final _login = TextEditingController(text: widget.login);
  final _code = TextEditingController();
  final _password = TextEditingController();
  final _confirmation = TextEditingController();
  bool _codeSent = false;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _login.dispose();
    _code.dispose();
    _password.dispose();
    _confirmation.dispose();
    super.dispose();
  }

  bool get _byEmail => _login.text.contains('@');

  Future<void> _run(Future<void> Function() action) async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await action();
    } catch (e) {
      if (mounted) setState(() => _error = apiErrorMessage(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _sendCode() => _run(() async {
    await ref
        .read(sessionControllerProvider.notifier)
        .forgotPassword(_login.text.trim());
    if (mounted) setState(() => _codeSent = true);
  });

  Future<void> _reset() => _run(
    () => ref
        .read(sessionControllerProvider.notifier)
        .resetPassword(
          login: _login.text.trim(),
          code: _code.text.trim(),
          password: _password.text,
          passwordConfirmation: _confirmation.text,
        ),
  );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Recuperar la contraseña'),
        leading: BackButton(onPressed: () => context.go('/ingresar')),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (!_codeSent) ...[
                      Text(
                        'Ingresá tu celular o tu correo y te mandamos un código '
                        'para elegir una contraseña nueva.',
                        style: theme.textTheme.bodyLarge,
                      ),
                      const SizedBox(height: 24),
                      TextFormField(
                        key: const Key('login'),
                        controller: _login,
                        decoration: const InputDecoration(
                          labelText: 'Celular o correo',
                          hintText: '0981 123 456',
                        ),
                        keyboardType: TextInputType.emailAddress,
                        validator: validateLogin,
                        onFieldSubmitted: (_) => _sendCode(),
                      ),
                    ] else ...[
                      Text(
                        _byEmail
                            ? 'Si hay una cuenta con ese correo, te mandamos un '
                                  'código. Si no lo ves, revisá la carpeta de spam.'
                            : 'Si hay una cuenta con ese número, te mandamos un '
                                  'código por WhatsApp.',
                        key: const Key('code-sent'),
                        style: theme.textTheme.bodyLarge,
                      ),
                      const SizedBox(height: 24),
                      TextFormField(
                        key: const Key('code'),
                        controller: _code,
                        autofocus: true,
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
                        validator: validateCode,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        key: const Key('password'),
                        controller: _password,
                        decoration: const InputDecoration(
                          labelText: 'Contraseña nueva',
                          helperText: 'Al menos $minPasswordLength caracteres.',
                        ),
                        obscureText: true,
                        autofillHints: const [AutofillHints.newPassword],
                        validator: validateNewPassword,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        key: const Key('confirmation'),
                        controller: _confirmation,
                        decoration: const InputDecoration(
                          labelText: 'Repetí la contraseña',
                        ),
                        obscureText: true,
                        validator: (value) =>
                            validatePasswordConfirmation(value, _password.text),
                        onFieldSubmitted: (_) => _reset(),
                      ),
                    ],
                    if (_error != null) ...[
                      const SizedBox(height: 16),
                      Text(
                        _error!,
                        style: TextStyle(color: theme.colorScheme.error),
                      ),
                    ],
                    const SizedBox(height: 24),
                    FilledButton(
                      key: const Key('submit'),
                      onPressed: _loading
                          ? null
                          : (_codeSent ? _reset : _sendCode),
                      child: _loading
                          ? const SizedBox.square(
                              dimension: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(
                              _codeSent
                                  ? 'Cambiar contraseña'
                                  : 'Mandar código',
                            ),
                    ),
                    if (_codeSent) ...[
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: _loading
                            ? null
                            : () => setState(() {
                                _codeSent = false;
                                _error = null;
                                _code.clear();
                              }),
                        child: const Text('Pedir otro código'),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
