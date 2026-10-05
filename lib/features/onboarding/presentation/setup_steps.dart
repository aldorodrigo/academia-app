import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../data/models.dart';

const _stepIcons = {
  'programs': Icons.sports_outlined,
  'groups': Icons.groups_2_outlined,
  'season': Icons.event_note_outlined,
  'instructors': Icons.badge_outlined,
};

/// Abre un paso de la guía. Un paso bloqueado lleva al que falta antes.
void openStep(
  BuildContext context,
  Onboarding onboarding,
  OnboardingStep step,
) {
  final target = step.status == StepStatus.locked
      ? onboarding.step(step.blockedBy) ?? step
      : step;
  context.go(stepRoutes[target.key]!);
}

/// Un paso de la guía con su estado.
class SetupStepTile extends StatelessWidget {
  const SetupStepTile({
    super.key,
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
      // Cada paso, un botón propio para el lector de pantalla.
      child: Semantics(
        container: true,
        button: true,
        child: ListTile(
          leading: Icon(icon, color: color, size: 28),
          title: Text(step.title),
          subtitle: Text(subtitle),
          trailing: step.status == StepStatus.pending && step.minutes != null
              ? Text('${step.minutes} min', style: theme.textTheme.bodySmall)
              : const Icon(Icons.chevron_right),
          onTap: onTap,
        ),
      ),
    );
  }
}
