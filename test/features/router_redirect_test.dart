import 'package:academia_app/features/auth/data/models.dart';
import 'package:academia_app/router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const _jakare = Organization(slug: 'jakare', name: 'Club Jakare');

Session _session({String? slug}) => Session(
  name: 'Ana',
  email: 'ana@test.com',
  organizations: const [_jakare],
  organizationSlug: slug,
);

void main() {
  test('sin sesión va a ingresar', () {
    expect(sessionRedirect(const AsyncData(null), '/inicio'), '/ingresar');
  });

  test('con sesión sin organización va a elegir organización', () {
    expect(
      sessionRedirect(AsyncData(_session()), '/inicio'),
      '/organizaciones',
    );
  });

  test('con sesión y organización va al inicio', () {
    expect(
      sessionRedirect(AsyncData(_session(slug: 'jakare')), '/ingresar'),
      '/inicio',
    );
    expect(
      sessionRedirect(AsyncData(_session(slug: 'jakare')), '/inicio'),
      isNull,
    );
  });
}
