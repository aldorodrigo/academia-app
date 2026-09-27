import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/api_client.dart';
import '../../../core/utils/clock.dart';
import '../../../core/utils/format.dart';
import '../../organizations/data/models.dart';
import '../../organizations/data/organization_repository.dart';
import '../data/models.dart';
import '../data/students_repository.dart';
import 'enrollment_status_chip.dart';
import 'students_list.dart';

/// Ficha del alumno: datos, inscripciones con horarios, tutores y ficha médica.
class StudentScreen extends ConsumerWidget {
  const StudentScreen({super.key, required this.id});

  final int id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final student = ref.watch(studentProvider(id));

    return Scaffold(
      appBar: AppBar(
        title: Text(student.value?.firstName ?? 'Ficha'),
        leading: BackButton(onPressed: () => context.go('/inicio')),
      ),
      body: student.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(apiErrorMessage(error), textAlign: TextAlign.center),
          ),
        ),
        data: (student) => RefreshIndicator(
          onRefresh: () => ref.refresh(studentProvider(id).future),
          child: _StudentDetails(student),
        ),
      ),
    );
  }
}

class _StudentDetails extends ConsumerWidget {
  const _StudentDetails(this.student);

  final Student student;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final today = ref.watch(todayProvider);
    final organization = ref.watch(currentOrganizationProvider).value;
    final age = student.age(today);
    final birthDate = student.birthDate;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            StudentAvatar(student, radius: 32),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(student.fullName, style: theme.textTheme.titleLarge),
                  if (age != null) Text('$age años'),
                ],
              ),
            ),
          ],
        ),
        const _SectionTitle('Datos'),
        if (birthDate != null)
          _Field('Fecha de nacimiento', formatDate(birthDate)),
        if (student.document != null) _Field('Documento', student.document!),
        if (student.shirtSize != null) _Field('Talle', student.shirtSize!),
        if (student.position != null) _Field('Posición', student.position!),
        _SectionTitle(
          student.enrollments.length == 1 ? 'Inscripción' : 'Inscripciones',
        ),
        if (student.enrollments.isEmpty)
          const Text('No tiene inscripciones en la temporada actual.'),
        for (final enrollment in student.enrollments)
          _EnrollmentCard(enrollment, organization),
        if (student.guardians.isNotEmpty) ...[
          const _SectionTitle('Tutores'),
          for (final guardian in student.guardians)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.person_outline),
              title: Text(
                guardian.isMe ? '${guardian.name} (vos)' : guardian.name,
              ),
              subtitle: guardian.relationship == null
                  ? null
                  : Text(guardian.relationship!),
            ),
        ],
        if (student.canViewMedical) ...[
          const _SectionTitle('Ficha médica'),
          if (student.medical == null)
            const Text('Todavía no se cargó la ficha médica.')
          else
            _MedicalCard(student.medical!, today),
        ],
      ],
    );
  }
}

class _EnrollmentCard extends StatelessWidget {
  const _EnrollmentCard(this.enrollment, this.organization);

  final Enrollment enrollment;
  final OrganizationDetails? organization;

  String _term(String key, String fallback) =>
      organization?.term(key) ?? fallback;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final group = enrollment.group;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${_term('group', 'Grupo')}: ${group.name}',
                    style: theme.textTheme.titleMedium,
                  ),
                ),
                EnrollmentStatusChip(enrollment.status),
              ],
            ),
            Text(
              '${_term('program', 'Disciplina')}: ${group.program.name} · '
              'Temporada ${enrollment.season}',
            ),
            if (group.schedules.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text('Horarios', style: theme.textTheme.labelLarge),
              for (final schedule in group.schedules)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Row(
                    children: [
                      const Icon(Icons.schedule, size: 18),
                      const SizedBox(width: 8),
                      Expanded(child: Text(schedule.description)),
                    ],
                  ),
                ),
            ],
            if (group.instructors.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                '${_term('instructor', 'Técnico')}: '
                '${group.instructors.join(', ')}',
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _MedicalCard extends StatelessWidget {
  const _MedicalCard(this.medical, this.today);

  final MedicalRecord medical;
  final DateTime today;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final contact = [
      medical.emergencyContactName,
      medical.emergencyContactPhone,
    ].whereType<String>().join(' · ');
    final fitUntil = medical.fitUntil;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (medical.bloodType != null)
              _Field('Grupo sanguíneo', medical.bloodType!),
            if (medical.allergies != null)
              _Field('Alergias', medical.allergies!),
            if (medical.conditions != null)
              _Field('Condiciones', medical.conditions!),
            if (medical.medications != null)
              _Field('Medicación', medical.medications!),
            if (contact.isNotEmpty) _Field('Contacto de emergencia', contact),
            if (fitUntil == null)
              const _Field('Apto médico', 'Sin cargar')
            else if (medical.isFitExpired(today))
              Text(
                'El apto médico venció el ${formatDate(fitUntil)}.',
                style: TextStyle(color: scheme.error),
              )
            else
              _Field('Apto médico', 'Vigente hasta ${formatDate(fitUntil)}'),
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 24, bottom: 8),
    child: Text(text, style: Theme.of(context).textTheme.titleMedium),
  );
}

class _Field extends StatelessWidget {
  const _Field(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.labelMedium),
        Text(value),
      ],
    ),
  );
}
