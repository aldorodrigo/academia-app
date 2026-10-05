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
/// grupos, cobrar en efectivo y su caja; la comisión, los comprobantes, el
/// efectivo en poder de quienes cobran, las solicitudes de inscripción y los
/// informes; la familia, su estado de cuenta y sus reservas; el profesor de
/// clases particulares, su agenda y sus alumnos. Con las palabras de la
/// organización ("Mis niveles", "Cargar jugador").
List<QuickAction> quickActionsFor(
  OrganizationDetails? organization, {
  required bool hasStudents,
}) {
  if (organization == null) return const [];
  final family = organization.hasRole('tutor') || hasStudents;
  // Quien cobra directo a la Caja no tiene caja propia: "Mi caja" solo si le
  // quedó plata de antes (o un depósito por confirmar).
  final hasCashBox =
      !organization.collectsToOrgCash || organization.cashBoxBalance != 0;

  return [
    if (organization.can('take_attendance'))
      QuickAction(
        'Mis ${organization.word('group').pluralLower}',
        Icons.groups_outlined,
        '/grupos',
      ),
    if (organization.can('collect_payments')) ...[
      const QuickAction('Cobrar', Icons.payments_outlined, '/cobrar'),
      if (hasCashBox)
        const QuickAction(
          'Mi caja',
          Icons.account_balance_wallet_outlined,
          '/mi-caja',
        ),
    ],
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
    if (organization.can('review_payment_reports'))
      const QuickAction('Efectivo', Icons.savings_outlined, '/efectivo'),
    if (organization.can('create_students'))
      QuickAction(
        'Cargar ${organization.word('student').lower}',
        Icons.person_add_alt_1_outlined,
        '/alumnos/nuevo',
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
