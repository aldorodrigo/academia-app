import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../organizations/data/organization_repository.dart';
import '../data/onboarding_controller.dart';
import 'setup_steps.dart';
import 'step_scaffold.dart';

/// La guía "Configurá tu club" (o academia, escuela…) dentro del inicio del administrador: la lista de
/// pasos mientras esté incompleta; "Seguir después" la achica a una barra y
/// "Seguir" la vuelve a abrir. Completa, desaparece.
class SetupCard extends ConsumerWidget {
  const SetupCard({super.key});

  Future<void> _setDismissed(
    BuildContext context,
    WidgetRef ref, {
    required bool dismissed,
  }) async {
    final controller = ref.read(onboardingProvider.notifier);
    final error = await (dismissed
        ? controller.dismiss()
        : controller.reopen());
    if (!context.mounted) return;
    if (error != null) {
      showMessage(context, error);
    } else if (dismissed) {
      showMessage(context, 'La retomás desde acá cuando quieras.');
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final onboarding = ref.watch(onboardingProvider).value;
    if (onboarding == null || onboarding.completed) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    final next = onboarding.nextStep;
    final noun =
        ref.watch(currentOrganizationProvider).value?.typeNoun ?? 'club';
    final progress = Row(
      children: [
        Expanded(
          child: LinearProgressIndicator(
            value: onboarding.total == 0
                ? 0
                : onboarding.done / onboarding.total,
            minHeight: 6,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(width: 12),
        Text(
          '${onboarding.done} de ${onboarding.total}',
          style: theme.textTheme.labelLarge,
        ),
      ],
    );

    if (onboarding.dismissed) {
      return Card(
        key: const Key('setup-compact'),
        color: theme.colorScheme.primaryContainer,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Icon(Icons.rocket_launch_outlined),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Configurá tu $noun',
                      style: theme.textTheme.titleMedium,
                    ),
                  ),
                  FilledButton(
                    onPressed: () =>
                        _setDismissed(context, ref, dismissed: false),
                    child: const Text('Seguir'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              progress,
              if (next != null) ...[
                const SizedBox(height: 8),
                Text('Sigue: ${next.title}'),
              ],
            ],
          ),
        ),
      );
    }

    return Card(
      key: const Key('setup-guide'),
      color: theme.colorScheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 16, 12, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.rocket_launch_outlined),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Configurá tu $noun',
                          style: theme.textTheme.titleMedium,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Te llevamos paso a paso. Se guarda solo: podés dejarlo y '
                    'seguir después.',
                  ),
                  const SizedBox(height: 12),
                  progress,
                  const SizedBox(height: 12),
                ],
              ),
            ),
            for (final step in onboarding.steps)
              SetupStepTile(
                step: step,
                blocker: onboarding.step(step.blockedBy),
                isNext: step.key == onboarding.next,
                onTap: () => openStep(context, onboarding, step),
              ),
            const SizedBox(height: 8),
            if (next != null)
              FilledButton(
                key: const Key('setup-next'),
                onPressed: () => openStep(context, onboarding, next),
                child: Text(
                  onboarding.done == 0 ? 'Empezar' : 'Seguir: ${next.title}',
                ),
              ),
            TextButton(
              onPressed: () => _setDismissed(context, ref, dismissed: true),
              child: const Text('Seguir después'),
            ),
          ],
        ),
      ),
    );
  }
}
