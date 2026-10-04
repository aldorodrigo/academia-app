import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/utils/clock.dart';
import '../../organizations/data/organization_repository.dart';
import '../data/lessons_repository.dart';
import '../data/models.dart';
import 'buy_pack_sheet.dart';

/// Tarjeta del inicio para el alumno adulto o el tutor: una por profesor con
/// clases particulares, con el saldo del paquete, la próxima clase y "Reservar".
class LessonsCard extends ConsumerWidget {
  const LessonsCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final enabled =
        ref
            .watch(currentOrganizationProvider)
            .value
            ?.hasFeature('private_lessons') ??
        false;
    if (!enabled) return const SizedBox.shrink();

    final teachers = ref.watch(lessonTeachersProvider).value ?? const [];
    // Solo los profesores con los que algún alumno a cargo puede reservar.
    final visible = teachers.where((t) => t.students.isNotEmpty).toList();
    if (visible.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [for (final teacher in visible) _TeacherCard(teacher)],
    );
  }
}

class _TeacherCard extends ConsumerWidget {
  const _TeacherCard(this.teacher);

  final Teacher teacher;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final showNames = teacher.students.length > 1;

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.school_outlined),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Clases con ${teacher.name}',
                    style: theme.textTheme.titleMedium,
                  ),
                ),
                TextButton(
                  onPressed: () => context.push('/reservas'),
                  child: const Text('Mis reservas'),
                ),
              ],
            ),
            for (final student in teacher.students)
              _StudentRow(teacher, student, showName: showNames),
          ],
        ),
      ),
    );
  }
}

class _StudentRow extends ConsumerWidget {
  const _StudentRow(this.teacher, this.entry, {required this.showName});

  final Teacher teacher;
  final TeacherStudent entry;
  final bool showName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final today = ref.watch(todayProvider);
    final pack = entry.pack;
    final warning = pack?.expiryWarning(today);
    final next = entry.nextBooking;

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (showName)
            Text(entry.student.firstName, style: theme.textTheme.titleSmall),
          Text(describePack(pack, teacher, today)),
          if (pack != null && pack.isActive) ...[
            const SizedBox(height: 6),
            LinearProgressIndicator(
              value: pack.classes == 0 ? 0 : pack.remaining / pack.classes,
              semanticsLabel: 'Clases que quedan',
            ),
          ],
          if (warning != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Row(
                children: [
                  Icon(
                    Icons.schedule,
                    size: 16,
                    color: theme.colorScheme.error,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '$warning: reservá las clases que te quedan.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.error,
                    ),
                  ),
                ],
              ),
            ),
          if (next != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                'Próxima clase: ${next.describe(today)}',
                style: theme.textTheme.bodySmall,
              ),
            ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.icon(
                icon: const Icon(Icons.event_available_outlined),
                label: const Text('Reservar clase'),
                onPressed: () => context.push(
                  '/particulares/${teacher.id}/reservar?alumno=${entry.student.id}',
                ),
              ),
              if (entry.shouldOfferPack && teacher.packs.isNotEmpty)
                OutlinedButton(
                  onPressed: () => showBuyPackSheet(
                    context,
                    teacher: teacher,
                    student: entry.student,
                  ),
                  child: const Text('Comprar paquete'),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
