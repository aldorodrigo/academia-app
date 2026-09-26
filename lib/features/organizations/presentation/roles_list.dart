import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/organization_repository.dart';

/// Perfiles del usuario en la organización activa (ej. Tutor y Tesorero).
class RolesList extends ConsumerWidget {
  const RolesList({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final organization = ref.watch(currentOrganizationProvider);

    return organization.when(
      loading: () => const LinearProgressIndicator(),
      error: (_, _) => const Text('No se pudieron cargar tus perfiles.'),
      data: (organization) {
        final roles = organization?.roles ?? const [];
        if (roles.isEmpty) {
          return const Text('Todavía no tenés perfiles asignados.');
        }
        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final role in roles) Chip(label: Text(role.description)),
          ],
        );
      },
    );
  }
}
