import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../organizations/data/organization_repository.dart';
import '../data/enrollment_repository.dart';

/// Tarjeta del inicio para quien aprueba: solicitudes de inscripción en revisión.
class EnrollmentRequestsCard extends ConsumerWidget {
  const EnrollmentRequestsCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final allowed =
        ref
            .watch(currentOrganizationProvider)
            .value
            ?.can('manage_enrollment_requests') ??
        false;
    if (!allowed) return const SizedBox.shrink();

    final requests = ref.watch(enrollmentReviewProvider(false));
    final pending = requests.value;

    return Card(
      child: ListTile(
        leading: Badge(
          isLabelVisible: pending?.isNotEmpty ?? false,
          label: Text('${pending?.length ?? 0}'),
          child: const Icon(Icons.how_to_reg_outlined),
        ),
        title: const Text('Solicitudes de inscripción'),
        subtitle: requests.isLoading
            ? const LinearProgressIndicator()
            : pending == null
            ? null
            : Text(
                pending.isEmpty
                    ? 'No hay solicitudes para revisar'
                    : pending.length == 1
                    ? '1 para revisar'
                    : '${pending.length} para revisar',
              ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => context.go('/solicitudes'),
      ),
    );
  }
}
