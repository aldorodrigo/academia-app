import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../data/quick_actions.dart';

/// Botones a las funciones principales de cada uno, arriba del inicio.
class QuickActionsBar extends ConsumerWidget {
  const QuickActionsBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final actions = ref.watch(quickActionsProvider);
    if (actions.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final action in actions)
            ActionChip(
              avatar: Icon(action.icon, size: 18),
              label: Text(action.label),
              onPressed: () => context.push(action.route),
            ),
        ],
      ),
    );
  }
}
