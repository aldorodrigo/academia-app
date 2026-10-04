import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/api_client.dart';
import '../../../core/utils/clock.dart';
import '../data/models.dart';
import '../data/students_repository.dart';
import 'enrollment_status_chip.dart';

/// Tarjetas de los alumnos a cargo del usuario; cada una abre su ficha.
class StudentsList extends ConsumerWidget {
  const StudentsList({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final students = ref.watch(studentsProvider);

    return students.when(
      loading: () => const LinearProgressIndicator(),
      error: (error, _) => Text(apiErrorMessage(error)),
      data: (students) {
        if (students.isEmpty) {
          return const Text(
            'Todavía no hay hijos cargados. Si falta alguno, avisá al club.',
          );
        }
        return Column(
          children: [for (final student in students) StudentCard(student)],
        );
      },
    );
  }
}

class StudentCard extends ConsumerWidget {
  const StudentCard(this.student, {super.key});

  final Student student;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final today = ref.watch(todayProvider);
    final age = student.age(today);
    final current = student.currentEnrollments(today);
    final details = [
      if (age != null) '$age años',
      if (student.enrollments.isNotEmpty) student.groupsDescription(today),
    ].join(' · ');

    return Card(
      child: ListTile(
        leading: StudentAvatar(student),
        title: Text(student.fullName),
        subtitle: details.isEmpty ? null : Text(details),
        trailing: current.isEmpty
            ? null
            : EnrollmentStatusChip(current.first.status),
        onTap: () => context.go('/hijos/${student.id}'),
      ),
    );
  }
}

class StudentAvatar extends StatelessWidget {
  const StudentAvatar(this.student, {super.key, this.radius});

  final Student student;
  final double? radius;

  @override
  Widget build(BuildContext context) {
    final photo = student.photoUrl;
    return CircleAvatar(
      radius: radius,
      foregroundImage: photo == null ? null : NetworkImage(photo),
      child: Text(student.initials),
    );
  }
}
