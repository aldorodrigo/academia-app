import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../data/onboarding_controller.dart';

/// Tarjeta del inicio para el administrador mientras falte configurar algo.
class SetupCard extends ConsumerWidget {
  const SetupCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final onboarding = ref.watch(onboardingProvider).value;
    if (onboarding == null || onboarding.completed) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    final next = onboarding.nextStep;

    return Card(
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
                    'Configurá tu club',
                    style: theme.textTheme.titleMedium,
                  ),
                ),
                Text('${onboarding.done} de ${onboarding.total}'),
              ],
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: onboarding.total == 0
                  ? 0
                  : onboarding.done / onboarding.total,
              borderRadius: BorderRadius.circular(4),
            ),
            if (next != null) ...[
              const SizedBox(height: 8),
              Text('Sigue: ${next.title}'),
            ],
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton(
                onPressed: () => context.go('/configurar'),
                child: const Text('Seguir'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
