import 'package:academia_app/features/auth/data/models.dart';
import 'package:academia_app/router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const _jakare = Organization(slug: 'jakare', name: 'Club Jakare');

Session _session({
  String? slug,
  bool verified = true,
  List<Organization> organizations = const [_jakare],
}) => Session(
  name: 'Ana',
  email: 'ana@test.com',
  organizations: organizations,
  organizationSlug: slug,
  verified: verified,
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
    for (final path in [
      '/clases/81',
      '/grupos',
      '/grupos/3',
      '/notificaciones',
    ]) {
      expect(sessionRedirect(const AsyncData(null), path), '/ingresar');
      expect(sessionRedirect(AsyncData(_session()), path), '/organizaciones');
      expect(
        sessionRedirect(AsyncData(_session(slug: 'jakare')), path),
        isNull,
      );
    }
  });

  test('calendario y eventos requieren sesión y organización', () {
    for (final path in [
      '/calendario',
      '/calendario/nuevo',
      '/eventos/7',
      '/eventos/7/editar',
    ]) {
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

  test(
    'el link directo conserva sus parámetros (ej. el día del calendario)',
    () {
      final redirect = sessionRedirect(
        const AsyncLoading(),
        '/calendario',
        requested: '/calendario?fecha=2026-10-19',
      );
      expect(redirect, '/?from=%2Fcalendario%3Ffecha%3D2026-10-19');
      expect(
        sessionRedirect(
          AsyncData(_session(slug: 'jakare')),
          '/',
          from: Uri.parse(redirect!).queryParameters['from'],
        ),
        '/calendario?fecha=2026-10-19',
      );
    },
  );

  test('from solo acepta rutas internas', () {
    final session = AsyncData(_session(slug: 'jakare'));
    expect(sessionRedirect(session, '/', from: '//evil.com'), '/inicio');
    expect(sessionRedirect(session, '/', from: 'https://evil.com'), '/inicio');
    expect(sessionRedirect(session, '/', from: '/ingresar'), '/inicio');
  });

  test('los informes requieren sesión', () {
    expect(sessionRedirect(const AsyncData(null), '/informes'), '/ingresar');
  });

  group('crear cuenta y club', () {
    test('crear cuenta y registro se abren sin sesión', () {
      expect(sessionRedirect(const AsyncData(null), '/crear-cuenta'), isNull);
      expect(sessionRedirect(const AsyncData(null), '/registro'), isNull);
      expect(
        sessionRedirect(const AsyncData(null), '/registro/club'),
        '/ingresar',
      );
      expect(
        sessionRedirect(const AsyncData(null), '/registro/codigo'),
        '/ingresar',
      );
    });

    test('recuperar la contraseña se abre sin sesión', () {
      expect(sessionRedirect(const AsyncData(null), '/recuperar'), isNull);
      // Al cambiarla queda la sesión iniciada: sigue como al ingresar.
      expect(
        sessionRedirect(AsyncData(_session(slug: 'jakare')), '/recuperar'),
        '/inicio',
      );
      expect(
        sessionRedirect(
          AsyncData(_session(organizations: const [])),
          '/recuperar',
        ),
        '/registro/club',
      );
    });

    test('sin verificar la cuenta solo se ingresa el código', () {
      final session = AsyncData(
        _session(verified: false, organizations: const []),
      );
      for (final path in [
        '/registro',
        '/inicio',
        '/organizaciones',
        '/registro/club',
      ]) {
        expect(sessionRedirect(session, path), '/registro/codigo');
      }
      expect(sessionRedirect(session, '/registro/codigo'), isNull);
      // Una invitación se puede abrir igual.
      expect(sessionRedirect(session, '/invitacion/abc'), isNull);
    });

    test('verificado y sin organizaciones sigue a "Tu club"', () {
      final session = AsyncData(_session(organizations: const []));
      expect(sessionRedirect(session, '/registro/codigo'), '/registro/club');
      expect(sessionRedirect(session, '/registro'), '/registro/club');
      expect(sessionRedirect(session, '/registro/club'), isNull);
      // Sin organizaciones, el resto lleva a elegir (que ofrece registrar el club).
      expect(sessionRedirect(session, '/inicio'), '/organizaciones');
    });

    test('con organizaciones, el registro lleva al inicio o a elegir', () {
      expect(
        sessionRedirect(AsyncData(_session(slug: 'jakare')), '/registro'),
        '/inicio',
      );
      expect(
        sessionRedirect(AsyncData(_session()), '/crear-cuenta'),
        '/organizaciones',
      );
      expect(
        sessionRedirect(AsyncData(_session(slug: 'jakare')), '/registro/club'),
        isNull,
      );
    });

    test('la guía requiere sesión y organización', () {
      for (final path in ['/configurar', '/configurar/categorias']) {
        expect(sessionRedirect(const AsyncData(null), path), '/ingresar');
        expect(sessionRedirect(AsyncData(_session()), path), '/organizaciones');
        expect(
          sessionRedirect(AsyncData(_session(slug: 'jakare')), path),
          isNull,
        );
      }
    });
  });
}
