import 'package:academia_app/features/home/data/quick_actions.dart';
import 'package:academia_app/features/organizations/data/models.dart';
import 'package:flutter_test/flutter_test.dart';

OrganizationDetails _organization({
  List<String> roles = const [],
  List<String> permissions = const [],
  List<String> features = const [],
}) => OrganizationDetails(
  slug: 'jakare',
  name: 'Club Jakare',
  terminology: const {},
  features: features,
  roles: [for (final r in roles) OrganizationRole(name: r, label: r)],
  permissions: permissions,
);

List<String> _labels(
  OrganizationDetails? organization, {
  bool hasStudents = false,
}) => quickActionsFor(
  organization,
  hasStudents: hasStudents,
).map((a) => a.label).toList();

void main() {
  test('cada uno ve los botones de lo suyo', () {
    expect(_labels(null), isEmpty);
    expect(_labels(_organization()), isEmpty);

    // Técnico.
    expect(
      _labels(
        _organization(roles: ['instructor'], permissions: ['take_attendance']),
      ),
      ['Mis grupos'],
    );

    // Tutor con clases particulares.
    expect(
      _labels(_organization(roles: ['tutor'], features: ['private_lessons'])),
      ['Estado de cuenta', 'Mis reservas'],
    );
    // Alumno adulto (sin rol de tutor, con inscripciones propias).
    expect(_labels(_organization(), hasStudents: true), ['Estado de cuenta']);

    // Profesor de particulares y comisión.
    expect(
      _labels(_organization(permissions: ['teach_lessons', 'view_reports'])),
      ['Agenda', 'Alumnos particulares', 'Informes'],
    );
  });
}
