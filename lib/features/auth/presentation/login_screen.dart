import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/api_client.dart';
import '../../../core/utils/validators.dart';
import '../data/session_controller.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _login = TextEditingController();
  final _password = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _login.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await ref
          .read(sessionControllerProvider.notifier)
          .login(login: _login.text.trim(), password: _password.text);
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
                    Text(
                      'Iniciar sesión',
                      style: theme.textTheme.headlineMedium,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 32),
                    TextFormField(
                      key: const Key('login'),
                      controller: _login,
                      decoration: const InputDecoration(
                        labelText: 'Celular o correo',
                        hintText: '0981 123 456',
                      ),
                      keyboardType: TextInputType.emailAddress,
                      autofillHints: const [
                        AutofillHints.telephoneNumber,
                        AutofillHints.email,
                      ],
                      validator: validateLogin,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      key: const Key('password'),
                      controller: _password,
                      decoration: const InputDecoration(
                        labelText: 'Contraseña',
                      ),
                      obscureText: true,
                      autofillHints: const [AutofillHints.password],
                      validator: validateCurrentPassword,
                      onFieldSubmitted: (_) => _submit(),
                    ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        key: const Key('forgot-password'),
                        onPressed: () => context.go(
                          Uri(
                            path: '/recuperar',
                            queryParameters: {
                              if (_login.text.trim().isNotEmpty)
                                'login': _login.text.trim(),
                            },
                          ).toString(),
                        ),
                        child: const Text('¿Olvidaste tu contraseña?'),
                      ),
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 16),
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
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Ingresar'),
                    ),
                    const SizedBox(height: 16),
                    OutlinedButton(
                      key: const Key('create-account'),
                      onPressed: () => context.go('/crear-cuenta'),
                      child: const Text('Crear cuenta'),
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: () => context.go('/invitacion'),
                      child: const Text('Tengo una invitación'),
                    ),
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
