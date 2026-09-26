import 'package:academia_app/features/organizations/data/organization_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../fakes.dart';

void main() {
  final routes = {
    'GET /organization': (_) => {
      'data': {
        'slug': 'jakare',
        'name': 'Club Jakare',
        'type': 'club',
        'currency': 'PYG',
        'timezone': 'America/Asuncion',
        'terminology': {'group': 'Categoría', 'student': 'Jugador'},
        'features': ['board'],
        'membership': {
          'roles': [
            {'name': 'tutor', 'label': 'Tutor'},
            {
              'name': 'tesorero',
              'label': 'Tesorero',
              'starts_on': '2026-01-01',
              'ends_on': '2027-12-31',
            },
          ],
        },
      },
    },
  };

  test('sin organización elegida no consulta la API', () async {
    final repository = OrganizationRepository(
      fakeDio(const {}),
      InMemorySessionStorage()..token = 't',
    );

    expect(await repository.current(), isNull);
  });

  test('lee vocabulario, módulos y perfiles con mandato', () async {
    final repository = OrganizationRepository(
      fakeDio(routes),
      InMemorySessionStorage()
        ..token = 't'
        ..organization = 'jakare',
    );

    final organization = (await repository.current())!;

    expect(organization.term('group'), 'Categoría');
    expect(organization.term('instructor'), 'Técnico');
    expect(organization.hasFeature('board'), isTrue);
    expect(organization.hasFeature('apparel'), isFalse);
    expect(organization.hasRole('tesorero'), isTrue);
    expect(organization.roles.map((r) => r.description), [
      'Tutor',
      'Tesorero · hasta 31/12/2027',
    ]);
  });
}
