import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../organizations/data/organization_repository.dart';
import '../data/models.dart';
import '../data/onboarding_controller.dart';

/// "¡Listo!": se muestra una vez, al completar la guía.
class SetupDoneScreen extends ConsumerWidget {
  const SetupDoneScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final organization = ref.watch(currentOrganizationProvider).value;
    final onboarding = ref.watch(onboardingProvider).value;
    final done =
        onboarding?.steps
            .where((s) => s.status == StepStatus.done && s.summary != null)
            .toList() ??
        const <OnboardingStep>[];

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Icon(
                    Icons.celebration_outlined,
                    size: 64,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '¡Todo listo!',
                    style: theme.textTheme.headlineSmall,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${organization?.name ?? 'Tu club'} ya tiene lo básico para '
                    'empezar. Todo lo que configuraste se puede cambiar cuando quieras.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  for (final step in done)
                    ListTile(
                      leading: Icon(
                        Icons.check_circle,
                        color: theme.colorScheme.primary,
                      ),
                      title: Text(step.title),
                      subtitle: Text(step.summary!),
                    ),
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: () => context.go('/inicio'),
                    child: const Text('Ir al inicio'),
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
