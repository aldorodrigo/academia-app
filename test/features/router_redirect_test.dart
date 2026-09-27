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

  test('asistencia y grupos requieren sesión y organización', () {
    for (final path in ['/clases/81', '/grupos', '/grupos/3']) {
      expect(sessionRedirect(const AsyncData(null), path), '/ingresar');
      expect(sessionRedirect(AsyncData(_session()), path), '/organizaciones');
      expect(
        sessionRedirect(AsyncData(_session(slug: 'jakare')), path),
        isNull,
      );
    }
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

  test('un link directo sobrevive a la carga de la sesión', () {
    expect(
      sessionRedirect(const AsyncLoading(), '/estado-de-cuenta'),
      '/?from=%2Festado-de-cuenta',
    );
    expect(
      sessionRedirect(
        AsyncData(_session(slug: 'jakare')),
        '/',
        from: '/estado-de-cuenta',
      ),
      '/estado-de-cuenta',
    );
    expect(
      sessionRedirect(
        AsyncData(_session(slug: 'jakare')),
        '/',
        from: '/hijos/5',
      ),
      '/hijos/5',
    );
  });

  test('from solo acepta rutas internas', () {
    final session = AsyncData(_session(slug: 'jakare'));
    expect(sessionRedirect(session, '/', from: '//evil.com'), '/inicio');
    expect(sessionRedirect(session, '/', from: 'https://evil.com'), '/inicio');
    expect(sessionRedirect(session, '/', from: '/ingresar'), '/inicio');
  });

  test('los informes requieren sesión', () {
    expect(sessionRedirect(const AsyncData(null), '/informes'), '/ingresar');
  });
}
