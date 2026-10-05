import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../data/enrollment_repository.dart';
import 'enrollment_requests_screen.dart';

/// Confirmar con un toque desde la planilla (categoría pedida y lo del plan).
/// Si la categoría está completa, pregunta antes de inscribir igual.
Future<bool> confirmEnrollment(
  BuildContext context,
  WidgetRef ref,
  int requestId,
  String name,
) async {
  final messenger = ScaffoldMessenger.of(context);
  final repository = ref.read(enrollmentRepositoryProvider);
  try {
    await repository.approve(requestId);
  } on DioException catch (error) {
    final errors = error.response?.data is Map
        ? (error.response!.data as Map)['errors']
        : null;
    if (errors is! Map || !errors.containsKey('over_capacity')) {
      messenger.showSnackBar(SnackBar(content: Text(apiErrorMessage(error))));
      return false;
    }
    if (!context.mounted) return false;
    final force = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Está completa'),
        content: Text(apiErrorMessage(error)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Volver'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Inscribir igual'),
          ),
        ],
      ),
    );
    if (force != true) return false;
    try {
      await repository.approve(requestId, overCapacity: true);
    } catch (error) {
      messenger.showSnackBar(SnackBar(content: Text(apiErrorMessage(error))));
      return false;
    }
  }
  ref.invalidate(enrollmentReviewProvider);
  messenger.showSnackBar(
    SnackBar(content: Text('Inscripción de $name confirmada.')),
  );
  return true;
}

/// Rechazar con motivo: el chico sale de la lista y la familia recibe el aviso.
Future<bool> rejectEnrollment(
  BuildContext context,
  WidgetRef ref,
  int requestId,
  String name,
) async {
  final messenger = ScaffoldMessenger.of(context);
  final reason = await showDialog<String>(
    context: context,
    builder: (_) => const RejectRequestDialog(),
  );
  if (reason == null) return false;
  try {
    await ref.read(enrollmentRepositoryProvider).reject(requestId, reason);
  } catch (error) {
    messenger.showSnackBar(SnackBar(content: Text(apiErrorMessage(error))));
    return false;
  }
  ref.invalidate(enrollmentReviewProvider);
  messenger.showSnackBar(
    SnackBar(
      content: Text('$name salió de la lista. Le avisamos a la familia.'),
    ),
  );
  return true;
}
