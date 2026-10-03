import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/api_client.dart';
import '../../../core/utils/validators.dart';
import '../data/session_controller.dart';

/// Crear cuenta con el celular (código por WhatsApp) o, si no tiene WhatsApp,
/// con el correo. Al terminar, la sesión queda iniciada y el router lleva a
/// ingresar el código.
class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirmation = TextEditingController();
  bool _terms = false;
  bool _useEmail = false;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _email.dispose();
    _password.dispose();
    _confirmation.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final valid = _formKey.currentState!.validate();
    setState(() => _error = _terms ? null : validateTerms(_terms));
    if (!valid || !_terms) return;

    setState(() => _loading = true);
    try {
      await ref
          .read(sessionControllerProvider.notifier)
          .register(
            name: _name.text.trim(),
            phone: _useEmail ? null : _phone.text.trim(),
            email: _useEmail ? _email.text.trim() : null,
            password: _password.text,
            passwordConfirmation: _confirmation.text,
          );
    } catch (e) {
      setState(() => _error = apiErrorMessage(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Crear cuenta'),
        leading: BackButton(onPressed: () => context.go('/crear-cuenta')),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: AutofillGroup(
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Primero, tu cuenta. Después armamos el club juntos.',
                        style: theme.textTheme.bodyLarge,
                      ),
                      const SizedBox(height: 24),
                      TextFormField(
                        key: const Key('name'),
                        controller: _name,
                        decoration: const InputDecoration(
                          labelText: 'Nombre y apellido',
                        ),
                        textCapitalization: TextCapitalization.words,
                        autofillHints: const [AutofillHints.name],
                        validator: validateName,
                      ),
                      const SizedBox(height: 16),
                      if (_useEmail)
                        TextFormField(
                          key: const Key('email'),
                          controller: _email,
                          decoration: const InputDecoration(
                            labelText: 'Correo electrónico',
                            helperText:
                                'Te mandamos un código para confirmarlo.',
                          ),
                          keyboardType: TextInputType.emailAddress,
                          autofillHints: const [AutofillHints.email],
                          validator: validateEmail,
                        )
                      else
                        TextFormField(
                          key: const Key('phone'),
                          controller: _phone,
                          decoration: const InputDecoration(
                            labelText: 'Celular (WhatsApp)',
                            hintText: '0981 123 456',
                            helperText: 'Te mandamos un código por WhatsApp para confirmarlo.',
                          ),
                          keyboardType: TextInputType.phone,
                          autofillHints: const [AutofillHints.telephoneNumber],
                          validator: validatePhone,
                        ),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton(
                          key: const Key('switch-channel'),
                          onPressed: () =>
                              setState(() => _useEmail = !_useEmail),
                          child: Text(
                            _useEmail
                                ? 'Usar mi celular (WhatsApp)'
                                : 'No tengo WhatsApp, usar mi correo',
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        key: const Key('password'),
                        controller: _password,
                        decoration: const InputDecoration(
                          labelText: 'Elegí una contraseña',
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
                        onFieldSubmitted: (_) => _submit(),
                      ),
                      const SizedBox(height: 8),
                      CheckboxListTile(
                        key: const Key('terms'),
                        contentPadding: EdgeInsets.zero,
                        controlAffinity: ListTileControlAffinity.leading,
                        value: _terms,
                        onChanged: (v) => setState(() {
                          _terms = v ?? false;
                          if (_terms) _error = null;
                        }),
                        title: const Text(
                          'Acepto los términos de uso y la política de datos personales.',
                        ),
                      ),
                      if (_error != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          _error!,
                          style: TextStyle(color: theme.colorScheme.error),
                        ),
                      ],
                      const SizedBox(height: 24),
                      FilledButton(
                        onPressed: _loading ? null : _submit,
                        child: _loading
                            ? const SizedBox.square(
                                dimension: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text('Crear cuenta'),
                      ),
                      const SizedBox(height: 16),
                      TextButton(
                        onPressed: () => context.go('/ingresar'),
                        child: const Text('Ya tengo cuenta'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
