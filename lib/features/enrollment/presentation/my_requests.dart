import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/api_client.dart';
import '../../students/data/students_repository.dart';
import '../data/enrollment_repository.dart';
import '../data/models.dart';

/// Las solicitudes propias (por confirmar o no aprobadas), arriba de "Mis hijos".
class MyEnrollmentRequests extends ConsumerWidget {
  const MyEnrollmentRequests({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final requests = ref.watch(myEnrollmentRequestsProvider).value ?? const [];
    return Column(
      children: [for (final request in requests) _RequestCard(request)],
    );
  }
}

class _RequestCard extends ConsumerWidget {
  const _RequestCard(this.request);

  final EnrollmentRequest request;

  Future<void> _cancel(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancelar la solicitud'),
        content: Text(
          '${request.child.firstName} sale de la lista de ${request.group.name} '
          'y el club ya no ve el pedido.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Volver'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Cancelar la solicitud'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(enrollmentRepositoryProvider).cancel(request.id);
      ref
        ..invalidate(myEnrollmentRequestsProvider)
        ..invalidate(studentsProvider);
      messenger.showSnackBar(
        const SnackBar(content: Text('Solicitud cancelada.')),
      );
    } catch (error) {
      messenger.showSnackBar(SnackBar(content: Text(apiErrorMessage(error))));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final rejected = request.status == EnrollmentRequestStatus.rejected;

    return Card(
      child: ListTile(
        leading: Icon(
          rejected ? Icons.info_outline : Icons.hourglass_top_outlined,
          color: rejected ? theme.colorScheme.error : null,
        ),
        title: Text(request.child.fullName),
        subtitle: Text(
          rejected
              ? 'No aprobada: ${request.rejectionReason ?? ''}'
              : 'Por confirmar · ${request.placeLabel}. Ya puede ir a clases.',
        ),
        trailing: request.isPending
            ? TextButton(
                onPressed: () => _cancel(context, ref),
                child: const Text('Cancelar'),
              )
            : null,
      ),
    );
  }
}

/// "Inscribir a otro hijo" (o "a mi hijo" si todavía no tiene).
class EnrollChildButton extends ConsumerWidget {
  const EnrollChildButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final students = ref.watch(studentsProvider).value ?? const [];
    final hasChildren = students.any((s) => !s.isSelf);

    return Align(
      alignment: Alignment.centerLeft,
      child: TextButton.icon(
        icon: const Icon(Icons.person_add_alt_outlined),
        label: Text(
          hasChildren ? 'Inscribir a otro hijo' : 'Inscribir a mi hijo',
        ),
        onPressed: () => context.go('/hijos/inscribir'),
      ),
    );
  }
}
