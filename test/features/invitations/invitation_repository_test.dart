import 'package:academia_app/features/invitations/data/invitation_repository.dart';
import 'package:academia_app/features/invitations/data/models.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../fakes.dart';

const invitationJson = {
  'data': {
    'organization': {'slug': 'jakare', 'name': 'Club Jakare'},
    'email': 'ana@test.com',
    'roles': [
      {'name': 'tutor', 'label': 'Tutor'},
    ],
    'user_exists': false,
    'expires_at': '2026-10-10T03:00:00Z',
  },
};

void main() {
  test('una invitación por celular muestra el número', () {
    final invitation = Invitation.fromJson('abc', {
      'organization': {'slug': 'jakare', 'name': 'Club Jakare'},
      'email': null,
      'phone': '+595981123456',
      'roles': const [],
      'user_exists': true,
    });
    expect(invitation.email, isNull);
    expect(invitation.name, isNull);
    expect(invitation.contact, '0981 123 456');
    expect(invitation.userExists, isTrue);
  });

  group('parseInvitationToken', () {
    test('acepta el link completo o solo el código', () {
      expect(
        parseInvitationToken('https://app.test/invitacion/Ab12_x-9'),
        'Ab12_x-9',
      );
      expect(parseInvitationToken('  Ab12x9  '), 'Ab12x9');
    });

    test('rechaza textos que no son un código', () {
      expect(parseInvitationToken(''), isNull);
      expect(parseInvitationToken('hola mundo'), isNull);
      expect(parseInvitationToken('https://app.test/invitacion/'), isNull);
    });
  });

  test('lee la invitación', () async {
    final repository = InvitationRepository(
      fakeDio({'GET /invitations/abc': (_) => invitationJson}),
      InMemorySessionStorage(),
    );

    final invitation = await repository.fetch('abc');

    expect(invitation.token, 'abc');
    expect(invitation.organization.name, 'Club Jakare');
    expect(invitation.roleLabels, ['Tutor']);
    expect(invitation.userExists, isFalse);
    expect(invitation.expiresAt, isNotNull);
  });

  test('al aceptar guarda el token y la organización', () async {
    final storage = InMemorySessionStorage();
    final requests = <RequestOptions>[];
    final repository = InvitationRepository(
      fakeDio({
        'POST /invitations/abc/accept': (_) => {
          'token': 'nuevo-token',
          'organization': 'jakare',
        },
      }, requests: requests),
      storage,
    );

    await repository.accept(
      'abc',
      name: 'Ana',
      password: 'secreta12',
      passwordConfirmation: 'secreta12',
      acceptedTerms: true,
    );

    expect(storage.token, 'nuevo-token');
    expect(storage.organization, 'jakare');
    expect(requests.single.data, {
      'name': 'Ana',
      'password': 'secreta12',
      'password_confirmation': 'secreta12',
      'device_name': 'app',
      'terms': true,
    });
  });

  test('con cuenta existente no manda nombre ni confirmación', () async {
    final requests = <RequestOptions>[];
    final repository = InvitationRepository(
      fakeDio({
        'POST /invitations/abc/accept': (_) => {
          'token': 't',
          'organization': 'jakare',
        },
      }, requests: requests),
      InMemorySessionStorage(),
    );

    await repository.accept('abc', password: 'actual');

    expect(requests.single.data, {'password': 'actual', 'device_name': 'app'});
  });
}
