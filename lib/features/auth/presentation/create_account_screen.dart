import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// "Crear cuenta": separa al que registra su club del que se quiere inscribir,
/// para que una familia no termine creando un club por error.
class CreateAccountScreen extends StatelessWidget {
  const CreateAccountScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        leading: BackButton(onPressed: () => context.go('/ingresar')),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    '¿Qué querés hacer?',
                    style: theme.textTheme.headlineSmall,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  _Choice(
                    key: const Key('choice-club'),
                    icon: Icons.stadium_outlined,
                    title: 'Registrar mi club o academia',
                    subtitle:
                        'Lo configurás en unos minutos: disciplinas, categorías, '
                        'cuotas y técnicos.',
                    onTap: () => context.go('/registro'),
                  ),
                  const SizedBox(height: 12),
                  _Choice(
                    key: const Key('choice-family'),
                    icon: Icons.family_restroom_outlined,
                    title: 'Inscribirme o inscribir a mi hijo',
                    subtitle: 'Necesitás el link del club o una invitación.',
                    onTap: () => showDialog<void>(
                      context: context,
                      builder: (dialogContext) => AlertDialog(
                        title: const Text('Pedile el link al club'),
                        content: const Text(
                          'Cada club tiene su link de inscripción: pedíselo por '
                          'WhatsApp y abrilo desde el celular. Si el club te '
                          'mandó una invitación por WhatsApp o por correo, usala para crear tu cuenta.',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(dialogContext),
                            child: const Text('Entendido'),
                          ),
                          FilledButton(
                            onPressed: () {
                              Navigator.pop(dialogContext);
                              context.go('/invitacion');
                            },
                            child: const Text('Tengo una invitación'),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
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
    );
  }
}

class _Choice extends StatelessWidget {
  const _Choice({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(icon, size: 36, color: theme.colorScheme.primary),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: theme.textTheme.titleMedium),
                    const SizedBox(height: 4),
                    Text(subtitle, style: theme.textTheme.bodyMedium),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}
