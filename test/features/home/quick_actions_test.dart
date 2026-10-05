import 'package:academia_app/features/home/data/quick_actions.dart';
import 'package:academia_app/features/organizations/data/models.dart';
import 'package:flutter_test/flutter_test.dart';

OrganizationDetails _organization({
  List<String> roles = const [],
  List<String> permissions = const [],
  List<String> features = const [],
  Map<String, String> terminology = const {
    'group': 'Grupo',
    'student': 'Alumno',
  },
  bool collectsToOrgCash = false,
  int cashBoxBalance = 0,
}) => OrganizationDetails(
  slug: 'jakare',
  name: 'Club Jakare',
  terminology: terminology,
  features: features,
  roles: [for (final r in roles) OrganizationRole(name: r, label: r)],
  permissions: permissions,
  collectsToOrgCash: collectsToOrgCash,
  cashBoxBalance: cashBoxBalance,
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

    // Tesorero: valida comprobantes y ve informes.
    expect(
      _labels(
        _organization(
          roles: ['tesorero'],
          permissions: ['view_reports', 'review_payment_reports'],
        ),
      ),
      ['Comprobantes', 'Efectivo', 'Informes'],
    );

    // Técnico que cobra en efectivo.
    expect(
      _labels(
        _organization(
          roles: ['instructor'],
          permissions: ['take_attendance', 'collect_payments'],
        ),
      ),
      ['Mis grupos', 'Cobrar', 'Mi caja'],
    );

    // Secretario: aprueba las solicitudes de inscripción de las familias.
    expect(
      _labels(
        _organization(
          roles: ['secretario'],
          permissions: ['manage_enrollment_requests', 'create_students'],
        ),
      ),
      ['Cargar alumno', 'Solicitudes'],
    );
  });

  test('los botones usan las palabras de la organización', () {
    const permissions = ['take_attendance', 'create_students'];
    expect(
      _labels(
        _organization(
          permissions: permissions,
          terminology: {'group': 'Nivel', 'student': 'Jugador'},
        ),
      ),
      ['Mis niveles', 'Cargar jugador'],
    );
    // Sin terminología propia: las de siempre (Categoría, Jugador).
    expect(_labels(_organization(permissions: permissions, terminology: {})), [
      'Mis categorías',
      'Cargar jugador',
    ]);
  });

  group('"Mi caja" de quien cobra directo a la Caja', () {
    List<String> labels({required bool direct, int balance = 0}) => _labels(
      _organization(
        permissions: ['collect_payments'],
        collectsToOrgCash: direct,
        cashBoxBalance: balance,
      ),
    );

    test('sin plata en su caja, no aparece', () {
      expect(labels(direct: true), ['Cobrar']);
    });

    test('si le quedó plata (o un depósito por confirmar), sí', () {
      expect(labels(direct: true, balance: 150000), ['Cobrar', 'Mi caja']);
    });

    test('quien no cobra directo la ve siempre', () {
      expect(labels(direct: false), ['Cobrar', 'Mi caja']);
    });

    test('lee el saldo de la caja en la membresía', () {
      final organization = OrganizationDetails.fromJson({
        'slug': 'jakare',
        'name': 'Club Jakare',
        'membership': {'collects_to_org_cash': true, 'cash_box_balance': 50000},
      });
      expect(organization.collectsToOrgCash, isTrue);
      expect(organization.cashBoxBalance, 50000);
      expect(
        OrganizationDetails.fromJson({'slug': 'jakare', 'name': 'Club Jakare'})
            .cashBoxBalance,
        0,
      );
    });
  });
}
