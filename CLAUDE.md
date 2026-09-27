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
Push con firebase_messaging (Android/iOS; en la web no hay push). Se configura con
`--dart-define=FIREBASE_API_KEY=… FIREBASE_APP_ID=… FIREBASE_MESSAGING_SENDER_ID=… FIREBASE_PROJECT_ID=…`;
sin esos valores la app funciona igual, sin notificaciones.

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
- **Temporadas:** puede haber varias vigentes a la vez (por disciplina, y colonias); la API manda las inscripciones
  vigentes o próximas con las fechas de la temporada. Las próximas se marcan "Empieza el …".
- **Mis hijos:** el inicio lista los alumnos a cargo (`GET /students`); la ficha es `/hijos/:id`.
  La ficha médica solo se muestra si la API la manda (`permissions.view_medical`).
- **Estado de cuenta:** tarjeta en el inicio y `/estado-de-cuenta` (`GET /account`, consolidado de la
  familia); en la ficha del hijo, `GET /students/{id}/account`. Montos con `formatMoney` (`core/utils/format.dart`).
  "A pagar ahora" (`due_now`) separado de "Próximas cuotas" (`upcoming`, cuotas creadas por adelantado,
  `Charge.isUpcoming`); cada cuota trae su temporada y, en el cobro por día, cantidad × monto.
  Pagos, saldo a favor y recibos (PDF por link firmado, se abre con `urlLauncherProvider`, reemplazable en tests).
- **Informes** (comisión): `/informes` (balance del mes, saldos por familia, morosos; PDF/Excel por link firmado)
  y tarjeta en el inicio, solo si `currentOrganizationProvider` trae el permiso `view_reports` (`can()`).
- **Fecha de hoy:** `todayProvider` y `nowProvider` (con hora) en `core/utils/clock.dart`, reemplazables en los tests.
- **Asistencia** (técnico, permiso `take_attendance`): tarjeta "Hoy" en el inicio con las clases de sus grupos,
  `/clases/:id` para tomarla (todos arrancan presentes, los que el tutor avisó "No va" justificados; un toque alterna
  presente/ausente; guardado único con reintento; suspender clase), `/grupos` y `/grupos/:id` (mes y % por alumno).
  La planilla vive en `AttendanceSheetController`.
- **Próxima clase** (tutor): `GET /agenda` en el inicio con "¿Lo llevás?" (hasta que empieza) y, la primera vez,
  "¿Querés que te avise los días de clase?"; en la ficha, asistencia del mes e interruptor del aviso.
  Acciones en `GuardianActions`. Activar el aviso pide permiso de push (`pushServiceProvider`, reemplazable en tests).
- **Organización activa:** `currentOrganizationProvider` (`GET /organization`) da vocabulario
  (`term('group')`), módulos (`hasFeature`) y perfiles del usuario con mandato (`roles`).
- **Contrato de API:** `academia-api/docs/API_V1.md`. La app se construye primero contra el
  contrato (fakes en tests, ver `fakeDio` en `test/fakes.dart`) y después se implementa la API.
- Dinero: montos enteros en guaraníes, formateados como `₲ 150.000`.

## Convenciones

- Estado con Riverpod; sin lógica de negocio en los widgets.
- Todo repositorio recibe `Dio` y `SessionStorage` por constructor (testeable con fakes, ver `test/fakes.dart`).
- Tests para redirecciones, repositorios y validaciones de formularios.
