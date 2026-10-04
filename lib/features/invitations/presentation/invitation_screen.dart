import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/api_client.dart';
import '../../../core/utils/validators.dart';
import '../../auth/data/session_controller.dart';
import '../../auth/presentation/terms_checkbox.dart';
import '../data/invitation_repository.dart';
import '../data/models.dart';

/// Muestra la invitación y la acepta: crea la cuenta o pide la contraseña
/// de la cuenta existente.
class InvitationScreen extends ConsumerWidget {
  const InvitationScreen({super.key, required this.token});

  final String token;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final invitation = ref.watch(invitationProvider(token));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Invitación'),
        leading: BackButton(onPressed: () => context.go('/ingresar')),
      ),
      body: SafeArea(
        child: invitation.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                apiErrorMessage(error),
                key: const Key('invitation-error'),
                textAlign: TextAlign.center,
              ),
            ),
          ),
          data: (invitation) => _AcceptForm(invitation: invitation),
        ),
      ),
    );
  }
}

class _AcceptForm extends ConsumerStatefulWidget {
  const _AcceptForm({required this.invitation});

  final Invitation invitation;

  @override
  ConsumerState<_AcceptForm> createState() => _AcceptFormState();
}

class _AcceptFormState extends ConsumerState<_AcceptForm> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _password = TextEditingController();
  final _confirmation = TextEditingController();
  bool _terms = false;
  bool _loading = false;
  String? _error;

  bool get _newAccount => !widget.invitation.userExists;

  @override
  void initState() {
    super.initState();
    // El nombre que cargó quien invitó; se puede corregir.
    _name.text = widget.invitation.name?.trim() ?? '';
  }

  @override
  void dispose() {
    _name.dispose();
    _password.dispose();
    _confirmation.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final valid = _formKey.currentState!.validate();
    // Una cuenta nueva acepta los términos, como en el registro.
    final terms = _newAccount ? validateTerms(_terms) : null;
    setState(() => _error = terms);
    if (!valid || terms != null) return;

    setState(() => _loading = true);

    try {
      await ref
          .read(sessionControllerProvider.notifier)
          .acceptInvitation(
            widget.invitation.token,
            name: _newAccount ? _name.text.trim() : null,
            password: _password.text,
            passwordConfirmation: _newAccount ? _confirmation.text : null,
            acceptedTerms: _newAccount && _terms,
          );
      if (mounted) context.go('/inicio');
    } catch (e) {
      setState(() => _error = apiErrorMessage(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final invitation = widget.invitation;

    return Center(
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
                  invitation.organization.name,
                  style: theme.textTheme.headlineSmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  invitation.roleLabels.isEmpty
                      ? 'Te invitaron a sumarte.'
                      : 'Te invitaron como ${invitation.roleLabels.join(', ')}.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 4),
                Text(
                  invitation.contact,
                  style: theme.textTheme.bodySmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                if (_newAccount) ...[
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
                ],
                TextFormField(
                  key: const Key('password'),
                  controller: _password,
                  decoration: InputDecoration(
                    labelText: _newAccount
                        ? 'Elegí una contraseña'
                        : 'Tu contraseña',
                    helperText: _newAccount
                        ? 'Al menos $minPasswordLength caracteres.'
                        : invitation.phone != null
                        ? 'Ya tenés una cuenta con este número.'
                        : 'Ya tenés una cuenta con este correo.',
                  ),
                  obscureText: true,
                  autofillHints: [
                    _newAccount
                        ? AutofillHints.newPassword
                        : AutofillHints.password,
                  ],
                  validator: _newAccount
                      ? validateNewPassword
                      : validateCurrentPassword,
                ),
                if (_newAccount) ...[
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
                  TermsCheckbox(
                    key: const Key('terms'),
                    value: _terms,
                    onChanged: (v) => setState(() {
                      _terms = v;
                      if (_terms) _error = null;
                    }),
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
                  onPressed: _loading ? null : _submit,
                  child: _loading
                      ? const SizedBox.square(
                          dimension: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(_newAccount ? 'Crear cuenta' : 'Aceptar'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
