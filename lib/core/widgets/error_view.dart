import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../api/api_client.dart';

/// Lo que se muestra cuando una pantalla no pudo cargar: con un 403, "No tenés
/// permiso para ver esto" y "Volver al inicio" (ej. una pantalla de la comisión
/// abierta por link); con otro error, el mensaje, "Reintentar" (si se pasa
/// [onRetry]) y "Volver al inicio".
///
/// ```dart
/// error: (error, _) => ErrorView(
///   error,
///   onRetry: () => ref.invalidate(cashOverviewProvider),
/// ),
/// ```
class ErrorView extends StatelessWidget {
  const ErrorView(this.error, {super.key, this.onRetry});

  final Object error;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final forbidden = isForbidden(error);
    void home() => context.go('/inicio');

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              forbidden ? Icons.lock_outline : Icons.error_outline,
              size: 48,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 12),
            Text(
              forbidden
                  ? 'No tenés permiso para ver esto'
                  : apiErrorMessage(error),
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            if (forbidden)
              FilledButton(
                onPressed: home,
                child: const Text('Volver al inicio'),
              )
            else ...[
              if (onRetry != null)
                FilledButton(
                  onPressed: onRetry,
                  child: const Text('Reintentar'),
                ),
              TextButton(
                onPressed: home,
                child: const Text('Volver al inicio'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
