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

  test('las invitaciones se abren con o sin sesión', () {
    expect(sessionRedirect(const AsyncLoading(), '/invitacion/abc'), isNull);
    expect(sessionRedirect(const AsyncData(null), '/invitacion'), isNull);
    expect(
      sessionRedirect(AsyncData(_session(slug: 'jakare')), '/invitacion/abc'),
      isNull,
    );
  });

  test('mi cuenta requiere sesión', () {
    expect(sessionRedirect(const AsyncData(null), '/cuenta'), '/ingresar');
    expect(
      sessionRedirect(AsyncData(_session(slug: 'jakare')), '/cuenta'),
      isNull,
    );
  });

  test('la ficha de un hijo requiere sesión y organización', () {
    expect(sessionRedirect(const AsyncData(null), '/hijos/5'), '/ingresar');
    expect(
      sessionRedirect(AsyncData(_session()), '/hijos/5'),
      '/organizaciones',
    );
    expect(
      sessionRedirect(AsyncData(_session(slug: 'jakare')), '/hijos/5'),
      isNull,
    );
  });

  test('el estado de cuenta requiere sesión', () {
    expect(
      sessionRedirect(const AsyncData(null), '/estado-de-cuenta'),
      '/ingresar',
    );
    expect(
      sessionRedirect(AsyncData(_session(slug: 'jakare')), '/estado-de-cuenta'),
      isNull,
    );
  });
}
