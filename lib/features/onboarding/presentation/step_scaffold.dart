import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../data/onboarding_controller.dart';

/// Pantalla de un paso de la guía: "Paso 2 de 4", la pregunta, para qué sirve,
/// el contenido y el botón para seguir (y "Lo hago después" si se puede omitir).
class StepScaffold extends ConsumerWidget {
  const StepScaffold({
    super.key,
    required this.stepKey,
    required this.title,
    required this.description,
    required this.children,
    required this.primaryLabel,
    required this.onPrimary,
    this.loading = false,
    this.secondaryLabel,
    this.onSecondary,
  });

  final String stepKey;
  final String title;
  final String description;
  final List<Widget> children;
  final String primaryLabel;

  /// null = deshabilitado.
  final VoidCallback? onPrimary;
  final bool loading;
  final String? secondaryLabel;
  final VoidCallback? onSecondary;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final onboarding = ref.watch(onboardingProvider).value;
    final number = onboarding?.numberOf(stepKey) ?? 0;
    final total = onboarding?.steps.length ?? 0;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          number > 0 ? 'Paso $number de $total' : 'Configurá tu club',
        ),
        leading: IconButton(
          tooltip: 'Volver al inicio',
          icon: const Icon(Icons.close),
          onPressed: () => context.go('/inicio'),
        ),
        bottom: total == 0
            ? null
            : PreferredSize(
                preferredSize: const Size.fromHeight(4),
                child: LinearProgressIndicator(
                  value: onboarding!.total == 0
                      ? 0
                      : onboarding.done / onboarding.total,
                ),
              ),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              children: [
                Text(title, style: theme.textTheme.headlineSmall),
                const SizedBox(height: 4),
                Text(description, style: theme.textTheme.bodyMedium),
                const SizedBox(height: 8),
                ...children,
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              FilledButton(
                key: const Key('step-primary'),
                onPressed: loading ? null : onPrimary,
                child: loading
                    ? const SizedBox.square(
                        dimension: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(primaryLabel),
              ),
              if (secondaryLabel != null)
                TextButton(
                  onPressed: loading ? null : onSecondary,
                  child: Text(secondaryLabel!),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Título de una sección dentro de un paso.
class StepSection extends StatelessWidget {
  const StepSection(this.title, {super.key, this.help});

  final String title;
  final String? help;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 24, bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: theme.textTheme.titleMedium),
          if (help != null) Text(help!, style: theme.textTheme.bodySmall),
        ],
      ),
    );
  }
}

void showMessage(BuildContext context, String message) =>
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));

/// Recuerda si la guía ya estaba completa al entrar al paso (para mostrar
/// "¡Listo!" solo cuando este paso la completa, aunque se complete antes de
/// tocar "Seguir", por ejemplo al activar "Yo también doy clases").
mixin StepEntry<T extends ConsumerStatefulWidget> on ConsumerState<T> {
  late final bool wasCompleted =
      ref.read(onboardingProvider).value?.completed ?? false;

  @override
  void initState() {
    super.initState();
    wasCompleted;
  }

  /// Guarda el paso y sigue: al siguiente pendiente, o a "¡Listo!" si con este
  /// se completó la guía. Devuelve false si hubo un error (ya mostrado).
  Future<bool> finishStep(Future<String?> Function() save) async {
    final error = await save();
    if (!mounted) return false;
    if (error != null) {
      showMessage(context, error);
      return false;
    }
    final after = await ref.read(onboardingProvider.notifier).reload();
    if (mounted) context.go(nextRoute(after, wasCompleted: wasCompleted));
    return true;
  }

  /// "Lo hago después": marca el paso como omitido y sigue.
  Future<bool> skipStep(String key) =>
      finishStep(() => ref.read(onboardingProvider.notifier).skip(key));
}
