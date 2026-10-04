import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../organizations/data/models.dart';
import '../../organizations/data/organization_repository.dart';
import '../../students/data/students_repository.dart';

/// Botón del inicio a una función principal.
class QuickAction {
  const QuickAction(this.label, this.icon, this.route);

  final String label;
  final IconData icon;
  final String route;
}

/// Los botones según lo que hace cada uno en la organización: el técnico, sus
/// grupos; la comisión, los comprobantes, las solicitudes de inscripción y los
/// informes; la familia, su estado de cuenta y sus reservas; el profesor de
/// clases particulares, su agenda y sus alumnos.
List<QuickAction> quickActionsFor(
  OrganizationDetails? organization, {
  required bool hasStudents,
}) {
  if (organization == null) return const [];
  final family = organization.hasRole('tutor') || hasStudents;

  return [
    if (organization.can('take_attendance'))
      const QuickAction('Mis grupos', Icons.groups_outlined, '/grupos'),
    if (family)
      const QuickAction(
        'Estado de cuenta',
        Icons.receipt_long_outlined,
        '/estado-de-cuenta',
      ),
    if (family && organization.hasFeature('private_lessons'))
      const QuickAction(
        'Mis reservas',
        Icons.event_available_outlined,
        '/reservas',
      ),
    if (organization.can('teach_lessons')) ...const [
      QuickAction(
        'Agenda',
        Icons.calendar_month_outlined,
        '/particulares/agenda',
      ),
      QuickAction(
        'Alumnos particulares',
        Icons.school_outlined,
        '/particulares/alumnos',
      ),
    ],
    if (organization.can('review_payment_reports'))
      const QuickAction(
        'Comprobantes',
        Icons.fact_check_outlined,
        '/comprobantes',
      ),
    if (organization.can('manage_enrollment_requests'))
      const QuickAction(
        'Solicitudes',
        Icons.how_to_reg_outlined,
        '/solicitudes',
      ),
    if (organization.can('view_reports'))
      const QuickAction('Informes', Icons.bar_chart_outlined, '/informes'),
  ];
}

final quickActionsProvider = Provider<List<QuickAction>>((ref) {
  final organization = ref.watch(currentOrganizationProvider).value;
  final students = ref.watch(studentsProvider).value ?? const [];
  return quickActionsFor(organization, hasStudents: students.isNotEmpty);
});
