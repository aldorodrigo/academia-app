import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/api_client.dart';
import '../../organizations/data/organization_repository.dart';
import '../data/models.dart';
import '../data/onboarding_controller.dart';
import 'step_scaffold.dart';

const _stepIcons = {
  'programs': Icons.sports_outlined,
  'groups': Icons.groups_2_outlined,
  'season': Icons.event_note_outlined,
  'instructors': Icons.badge_outlined,
};

/// "Configurá tu club": la lista de pasos con su estado. Se abre sola mientras
/// esté incompleta y no se haya cerrado.
class SetupScreen extends ConsumerWidget {
  const SetupScreen({super.key});

  Future<void> _dismiss(BuildContext context, WidgetRef ref) async {
    final onboarding = ref.read(onboardingProvider).value;
    if (onboarding != null && !onboarding.completed && !onboarding.dismissed) {
      final error = await ref.read(onboardingProvider.notifier).dismiss();
      if (!context.mounted) return;
      if (error != null) {
        showMessage(context, error);
        return;
      }
      showMessage(context, 'La retomás desde el inicio cuando quieras.');
    }
    if (context.mounted) context.go('/inicio');
  }

  void _open(BuildContext context, Onboarding onboarding, OnboardingStep step) {
    // Un paso bloqueado lleva al que falta antes.
    final target = step.status == StepStatus.locked
        ? onboarding.step(step.blockedBy) ?? step
        : step;
    context.go(stepRoutes[target.key]!);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final async = ref.watch(onboardingProvider);
    final organization = ref.watch(currentOrganizationProvider).value;
    final onboarding = async.value;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Configurá tu club'),
        leading: IconButton(
          tooltip: 'Cerrar',
          icon: const Icon(Icons.close),
          onPressed: () => _dismiss(context, ref),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: async.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => Center(child: Text(apiErrorMessage(error))),
              data: (onboarding) => onboarding == null
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: Text(
                          'Solo los administradores configuran el club.',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    )
                  : ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        Text(
                          organization?.name ?? '',
                          style: theme.textTheme.headlineSmall,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          onboarding.completed
                              ? 'Ya está todo listo. Podés volver a cualquier paso.'
                              : 'Te llevamos paso a paso. Se guarda solo: podés '
                                    'dejarlo y seguir después.',
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: LinearProgressIndicator(
                                value: onboarding.total == 0
                                    ? 0
                                    : onboarding.done / onboarding.total,
                                minHeight: 8,
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              '${onboarding.done} de ${onboarding.total}',
                              style: theme.textTheme.labelLarge,
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        for (final step in onboarding.steps)
                          _StepTile(
                            step: step,
                            blocker: onboarding.step(step.blockedBy),
                            isNext: step.key == onboarding.next,
                            onTap: () => _open(context, onboarding, step),
                          ),
                      ],
                    ),
            ),
          ),
        ),
      ),
      bottomNavigationBar: onboarding == null
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    FilledButton(
                      key: const Key('setup-next'),
                      onPressed: () => onboarding.nextStep == null
                          ? context.go('/inicio')
                          : context.go(stepRoutes[onboarding.next]!),
                      child: Text(
                        onboarding.nextStep == null
                            ? 'Ir al inicio'
                            : onboarding.done == 0
                            ? 'Empezar'
                            : 'Seguir: ${onboarding.nextStep!.title}',
                      ),
                    ),
                    if (!onboarding.completed)
                      TextButton(
                        onPressed: () => _dismiss(context, ref),
                        child: const Text('Seguir después'),
                      ),
                  ],
                ),
              ),
            ),
    );
  }
}

class _StepTile extends StatelessWidget {
  const _StepTile({
    required this.step,
    required this.blocker,
    required this.isNext,
    required this.onTap,
  });

  final OnboardingStep step;
  final OnboardingStep? blocker;
  final bool isNext;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (icon, color) = switch (step.status) {
      StepStatus.done => (Icons.check_circle, theme.colorScheme.primary),
      StepStatus.skipped => (Icons.remove_circle_outline, theme.disabledColor),
      StepStatus.locked => (Icons.lock_outline, theme.disabledColor),
      StepStatus.pending => (
        _stepIcons[step.key] ?? Icons.circle_outlined,
        theme.colorScheme.onSurfaceVariant,
      ),
    };
    final subtitle = switch (step.status) {
      StepStatus.done => step.summary ?? step.description,
      StepStatus.skipped => 'Lo dejaste para después',
      StepStatus.locked => 'Primero: ${blocker?.title ?? 'el paso anterior'}',
      StepStatus.pending => step.description,
    };

    return Card(
      elevation: isNext ? 2 : 0,
      shape: isNext
          ? RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: theme.colorScheme.primary),
            )
          : null,
      child: ListTile(
        leading: Icon(icon, color: color, size: 28),
        title: Text(step.title),
        subtitle: Text(subtitle),
        trailing: step.status == StepStatus.pending && step.minutes != null
            ? Text('${step.minutes} min', style: theme.textTheme.bodySmall)
            : const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}
