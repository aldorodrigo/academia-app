# CLAUDE.md

Guía para Claude Code al trabajar en este repositorio.

## Proyecto

App (Android, iOS y web) del SaaS para academias, clubes y escuelas de formación.
Usuarios: padres/tutores, técnicos/instructores y miembros de la comisión.
Piloto: **Club Jakare**. Nombre del producto: pendiente (nombre en clave: `academia`).

El backend (Laravel 13 + Filament) vive en el repo `academia-api`; su `business-logic.md`
es el documento maestro de negocio.

## Idioma

**Solo español.** Los textos se escriben directamente en español en los widgets; no hay
archivos de traducción ni `intl`/ARB propios. `flutter_localizations` se usa solo para que
los widgets de Flutter (calendarios, diálogos) muestren sus textos en español
(`Locale('es')`, único locale soportado). Tono: voseo rioplatense/paraguayo ("Ingresá", "Elegí").

## Stack

Flutter 3.47 · Dart 3.13 · Riverpod 3 · go_router · dio · flutter_secure_storage.
Push (firebase_messaging) se agrega en el Sprint 5.

## Comandos

```bash
flutter pub get
flutter run --dart-define=API_BASE_URL=http://10.0.2.2/api/v1   # emulador Android + Sail
flutter run -d chrome --dart-define=API_BASE_URL=http://localhost/api/v1
flutter analyze
flutter test
dart format lib test
```

## Arquitectura

```
lib/
  core/        config (Env), api (dio + interceptor), storage (token y organización)
  features/    una carpeta por funcionalidad: data/ (repositorios, modelos) y presentation/ (pantallas)
  router.dart  rutas y redirecciones según la sesión
  app.dart     MaterialApp (tema, locale es)
```

- **Autenticación:** token Sanctum (`POST /api/v1/auth/token`) guardado en almacenamiento seguro.
- **Organización activa:** se guarda el slug y el interceptor envía `X-Organization` en cada petición.
- **Sesión:** `SessionController` (AsyncNotifier). `null` = sin sesión.
- **Navegación:** `sessionRedirect()` decide: `/ingresar` → `/organizaciones` → `/inicio`.
  `/invitacion` y `/invitacion/:token` son públicas (link o QR de invitación, con o sin sesión).
- **Mis hijos:** el inicio lista los alumnos a cargo (`GET /students`); la ficha es `/hijos/:id`.
  La ficha médica solo se muestra si la API la manda (`permissions.view_medical`).
- **Fecha de hoy:** `todayProvider` (`core/utils/clock.dart`), reemplazable en los tests.
- **Organización activa:** `currentOrganizationProvider` (`GET /organization`) da vocabulario
  (`term('group')`), módulos (`hasFeature`) y perfiles del usuario con mandato (`roles`).
- **Contrato de API:** `academia-api/docs/API_V1.md`. La app se construye primero contra el
  contrato (fakes en tests, ver `fakeDio` en `test/fakes.dart`) y después se implementa la API.
- Dinero: montos enteros en guaraníes, formateados como `₲ 150.000`.

## Convenciones

- Estado con Riverpod; sin lógica de negocio en los widgets.
- Todo repositorio recibe `Dio` y `SessionStorage` por constructor (testeable con fakes, ver `test/fakes.dart`).
- Tests para redirecciones, repositorios y validaciones de formularios.
