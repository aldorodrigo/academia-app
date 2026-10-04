import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../data/models.dart';

/// Para pegar a mano el link o el código de una invitación.
class InvitationCodeScreen extends StatefulWidget {
  const InvitationCodeScreen({super.key});

  @override
  State<InvitationCodeScreen> createState() => _InvitationCodeScreenState();
}

class _InvitationCodeScreenState extends State<InvitationCodeScreen> {
  final _formKey = GlobalKey<FormState>();
  final _code = TextEditingController();

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    context.go('/invitacion/${parseInvitationToken(_code.text)}');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tengo una invitación'),
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
                    const Text(
                      'Pegá el link que te llegó por WhatsApp o por correo, o el código de '
                      'la invitación. Si tenés un QR, escanealo con la cámara '
                      'del celular.',
                    ),
                    const SizedBox(height: 24),
                    TextFormField(
                      key: const Key('code'),
                      controller: _code,
                      decoration: const InputDecoration(
                        labelText: 'Link o código',
                      ),
                      validator: (value) =>
                          parseInvitationToken(value ?? '') == null
                          ? 'Ingresá un link o código válido.'
                          : null,
                      onFieldSubmitted: (_) => _submit(),
                    ),
                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed: _submit,
                      child: const Text('Continuar'),
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
