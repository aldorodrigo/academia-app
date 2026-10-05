# CLAUDE.md

Guía para Claude Code al trabajar en este repositorio.

## Proyecto

App (Android, iOS y web) del SaaS para academias, clubes y escuelas de formación.
Usuarios: padres/tutores, técnicos/instructores y miembros de la comisión.
Piloto: **Club Jakare**. Producto: **Tuku** (dominio `tukuha.app`; el paquete sigue siendo `academia_app`).

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
cd tool/brand_icons && npm install && node generate.mjs   # íconos y pantalla de inicio desde assets/brand/
```

## Arquitectura

```
lib/
  core/        config (Env), api (dio + interceptor), storage (token y organización)
  features/    una carpeta por funcionalidad: data/ (repositorios, modelos) y presentation/ (pantallas)
  router.dart  rutas y redirecciones según la sesión
  app.dart     MaterialApp (tema claro y oscuro de Tuku, locale es)
```

- **Autenticación:** token Sanctum (`POST /api/v1/auth/token` con `login`: celular o correo) guardado en
  almacenamiento seguro. La cuenta se crea con el celular (código por WhatsApp) o con el correo; `Session` trae
  `phone`, `email`, `verified` y `contact` (celular con `formatPhone` o correo). "Olvidé mi contraseña" en `/recuperar`.
  Los pedidos de código mandan `captcha_token` de `captchaProvider` (`core/captcha/captcha.dart`, Cloudflare
  Turnstile invisible con `--dart-define=TURNSTILE_SITE_KEY=…`; sin clave no se usa; reemplazable en tests).
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
- **Comprobantes de transferencia** (`features/payment_reports/`): el tutor informa un pago desde el estado de cuenta
  ("Informar transferencia", `/estado-de-cuenta/informar-pago`: cuotas, monto, fecha, cuenta y foto o PDF elegido con
  `proofPickerProvider`, reemplazable en tests); queda en revisión hasta que se aprueba. El monto sigue a las cuotas
  elegidas hasta que se edita a mano y avisa si es parcial o sobra (`amountHint`, compartido con Cobrar). Arriba del
  estado de cuenta van solo los comprobantes `open` (en revisión o rechazados con cuotas pendientes; lo decide la
  API). Quien tiene el permiso
  `review_payment_reports` ve `PaymentReportsCard` en el inicio y `/comprobantes` (aprobar o rechazar con motivo).
- **Inscribir a un hijo** (`features/enrollment/`, "entra ya, se confirma después"): desde "Mis hijos" ("Inscribir a
  otro hijo") o "Mi cuenta", `/hijos/inscribir` (datos, documento obligatorio, fecha dd/mm/aaaa; `PlacePicker` con
  disciplina, temporada y la categoría sugerida de `GET enrollment-requests/options`; ficha médica opcional). El chico
  ya va a clases (inscripción pendiente) y el club confirma; si quien pide puede confirmar, queda confirmada. Las
  solicitudes propias arriba de los hijos (`MyEnrollmentRequests`, se pueden cancelar). Quien tiene
  `manage_enrollment_requests` confirma o rechaza en `/solicitudes` (`EnrollmentRequestsCard`) y, el técnico, en la
  planilla ("Nuevo, por confirmar", `confirmEnrollment`/`rejectEnrollment` en `enrollment_actions.dart`). Con
  `create_students`, "Cargar alumno" (`/alumnos/nuevo`, `POST students`) con la invitación del tutor para mandar por
  WhatsApp (`urlLauncherProvider`). Plan: `academia-api/docs/PLAN_INSCRIPCION_TUTOR.md` (5e le suma el link público).
- **Cobro en efectivo y caja del técnico** (`features/cash/`, plan en `academia-api/docs/PLAN_COBRO_EFECTIVO.md`):
  quien tiene `collect_payments` cobra desde `/cobrar` (alumnos de sus grupos, o todos para la comisión) o tocando un
  alumno en `/grupos/:id`; `/cobrar/:id` muestra las cuotas pendientes de la familia (elegidas las de ahora, sin las
  próximas ni las que tienen una transferencia en revisión), el monto prellenado con `settle_amount` (pronto pago lo
  calcula la API) y el recibo. Cada cobro manda un `request_id` (`collectionRequestIdProvider`, reemplazable en tests)
  para que un reintento no lo duplique. En la misma pantalla, "Transferencia" registra la que la familia le mandó por
  WhatsApp (`POST collections/transfers`, captura o PDF con `proofPickerProvider` y `ProofField`): queda aprobada con
  recibo si quien la registra valida comprobantes (`approves_transfers`), si no en revisión; la familia la ve con
  "Registrado por …" (`PaymentReport.registeredBy`, sin "Retirar"). El efectivo entra en su caja personal: `/mi-caja` (saldo en su poder, movimientos y
  "Depositar", que queda por confirmar). Quien valida comprobantes (`review_payment_reports`) ve `/efectivo` (cajas de
  cada uno y depósitos para confirmar o rechazar). Cobrar y depositar requieren conexión.
- **Informes** (comisión): `/informes` (balance del mes, saldos por familia, morosos; PDF/Excel por link firmado)
  y tarjeta en el inicio, solo si `currentOrganizationProvider` trae el permiso `view_reports` (`can()`).
  Saldos y Morosos marcan a los hijos dados de baja (`withdrawn`, `WithdrawalLabel`: "Matías: baja el 03/06/2026");
  Morosos filtra con chips Todos / Siguen / Dados de baja (`WithdrawnFilter`, `delinquentsReportProvider(filtro)`).
- **Bajas y condonación** (`features/withdrawals/`, `academia-api/docs/PLAN_BAJAS.md`): avisos de baja del técnico
  ("Dejó de venir" en `/grupos/:id`) y del tutor ("Avisar que deja el club" en la ficha del hijo, `LeavingMenu`); quien
  tiene `withdraw_students` los ve en `DropoutReportsCard` y `/bajas`, y en `/alumnos/:id` (`ManageStudentScreen`) da la
  baja (`WithdrawForm`: fecha, motivo y aviso a la familia prellenado y editable; dice a quién le llega y por dónde con
  `notice.reach` de la API, `NoticeReach.description`, y a los tutores sin la app ofrece "Mandar por WhatsApp" con el
  mensaje ya escrito, `urlLauncherProvider`) o "Sigue viniendo"; con
  `waive_charges` condona y deshace desde la cuenta del alumno. `WithdrawalsRepository`; estado `ChargeStatus.waived`.
- **Fecha de hoy:** `todayProvider` y `nowProvider` (con hora) en `core/utils/clock.dart`, reemplazables en los tests.
- **Asistencia** (técnico, permiso `take_attendance`): tarjeta "Hoy" en el inicio con las clases de sus grupos,
  `/clases/:id` para tomarla (todos arrancan presentes, los que el tutor avisó "No va" justificados; un toque alterna
  presente/ausente; guardado único con reintento), `/grupos` y `/grupos/:id` (mes y % por alumno).
  La planilla vive en `AttendanceSheetController`. Suspender: "Cancelar la clase" (con "No cobrar esta clase" si
  `can_waive_charge`) o "Reprogramar" (`RescheduleSheet` en `class_change_dialogs.dart`); también "Cambiar día u
  horario" y "Cancelar reprogramación". Las recuperaciones (`isMakeup`) son clases como cualquier otra.
- **Sin conexión** (solo la asistencia del técnico): `AttendanceRepository` guarda en `OfflineStore`
  (`core/storage/offline_store.dart`, shared_preferences; `InMemoryOfflineStore` en tests) la respuesta de
  `GET classes` y el detalle de cada clase; sin red devuelve lo guardado. Guardar sin red encola en
  `AttendanceOutbox` (una entrada por clase) y se envía al volver la señal (`connectivityProvider`), al volver a la app
  o con "Enviar ahora". Suspender y reprogramar requieren conexión. Al cerrar sesión se borra todo.
- **Avisos** (`features/inbox/`, `/avisos`, desde "Mi cuenta" y `InboxCard` en el inicio si hay sin leer): la copia de
  cada push o correo que le llegó a la cuenta en la organización activa (`GET me/notifications`, paginado, más nuevos
  primero; `meta.unread`). Le llega aunque no tenga notificaciones ni correo. Tocar uno lo marca leído
  (`POST me/notifications/{id}/read`) y abre su `route`; "Marcar todos como leídos". `inboxProvider`,
  `unreadNotificationsProvider`.
- **Notificaciones** (`/notificaciones`, desde "Mi cuenta"): hasta 3 avisos por clase para técnico y tutor
  (`GET/PUT me/notification-settings`). Los push `class_reminder` ("Sí, va" / "No va" por link firmado) y
  `class_today` ("Tomar asistencia") se dibujan con `flutter_local_notifications` (`core/push/class_notifications.dart`;
  en Android llegan solo con datos).
- **Próxima clase** (tutor): `GET /agenda` en el inicio con "¿Lo llevás?" (hasta que empieza; si es recuperación,
  "Recupera la clase de…") y, la primera vez,
  "¿Querés que te avise los días de clase?"; en la ficha, asistencia del mes e interruptor del aviso.
  Acciones en `GuardianActions`. Activar el aviso pide permiso de push (`pushServiceProvider`, reemplazable en tests).
- **Clases particulares** (módulo `private_lessons`, `features/lessons/`): el alumno adulto o el tutor ve en el inicio
  `LessonsCard` (una tarjeta por profesor de `GET lessons/teachers` con el paquete, la próxima clase, "Reservar clase"
  y "Comprar paquete"), reserva en `/particulares/:teacherId/reservar?alumno=` (`BookingController`: día, hora y
  resumen con `previewBooking`, lo mismo que decide la API) y ve `/reservas` (cancelar y cambiar). El profesor
  (permiso `teach_lessons`) tiene `TodayLessonsCard` con la ficha rápida (`showBookingSheet`: Vino / No vino, Cobrar,
  Cancelar), `/particulares/agenda`, `/particulares/alumnos` (cobrar, vender y extender paquetes) y
  `/particulares/ajustes` (precio, duración, paquetes con validez y disponibilidad; `LessonProfileController`, entrada
  en "Mi cuenta" también para instructores sin perfil). Acciones en `StudentLessonActions` y `TeacherLessonActions`.
- **Alta autoservicio y "Primeros pasos"** (Sprint 5d, `features/onboarding/`): login → "Crear cuenta" (`/crear-cuenta`
  separa club de familia) → `/registro` (celular o correo) → `/registro/codigo` (código de 6 dígitos por WhatsApp o
  correo; `sessionRedirect` lo fuerza si `verified` es false) → `/registro/club` ("Tu club"; también desde la lista de organizaciones vacía) →
  la guía en el inicio (`SetupCard`: checklist de `GET onboarding`, permiso `configure_organization`; "Seguir después"
  la achica a una barra, completa desaparece; `/configurar` redirige al inicio) y un paso por pantalla
  (`/configurar/disciplinas|categorias|temporada|tecnicos`, `StepScaffold` + `StepEntry`, controllers en
  `step_controllers.dart`) → `/configurar/listo`. No se abre sola. La API decide todo (pasos hechos,
  sugerencias de categorías, fechas y montos de la temporada): la app no calcula. El paso 2 "se guarda solo": cada
  cambio va como borrador a `onboarding/steps/groups/draft` (`draftSaveDelayProvider`, 800 ms; cero en tests) y se
  retoma al volver, también lo que quedó en el panel. Cantidades con `countOf()` y temporadas con `seasonLabel()`.
- **Vocabulario** (`term()`): al guardar el paso 1, si `GET onboarding` trae `terminology_suggestion` (cada deporte
  con lo suyo, la decide la API: fútbol Jugador/Técnico/Categoría/Cancha, natación Nivel/Pileta…) se abre
  `TerminologySuggestionSheet` ("Usar estas palabras", "Dejar como estaba" o "Después"); sin contestar, `SetupCard`
  la recuerda ("Elegí cómo les dicen", `TerminologyReminder`, también con la guía completa). Después se cambia en "Mi cuenta" → "Cómo les dicen" (`/vocabulario`, permiso
  `configure_organization`, `PUT organization/terminology`, `VocabularyController`). Los textos de la guía usan el
  tipo (`typeNoun`: "Configurá tu academia").
- **Botones del inicio:** `QuickActionsBar` con `quickActionsFor()` (`features/home/data/quick_actions.dart`) según
  permisos y roles: Mis grupos, Cobrar, Mi caja, Estado de cuenta, Mis reservas, Agenda, Alumnos particulares,
  Comprobantes, Efectivo, Cargar alumno, Solicitudes, Informes.
- **Organización activa:** `currentOrganizationProvider` (`GET /organization`) da vocabulario
  (`term('group')`), módulos (`hasFeature`) y perfiles del usuario con mandato (`roles`).
- **Contrato de API:** `academia-api/docs/API_V1.md`. La app se construye primero contra el
  contrato (fakes en tests, ver `fakeDio` en `test/fakes.dart`) y después se implementa la API.
- Dinero: montos enteros en guaraníes, formateados como `₲ 150.000`.
- **Marca Tuku:** tema en `core/theme/tuku_theme.dart` (tokens del sistema de diseño: verde, brote, sol, aviso en
  `tertiary`, sin azul ni rojo de marca; claro y oscuro según el sistema) y `TukuLogo`/`TukuSplash` en
  `core/theme/brand.dart`. Tipografías empaquetadas en `assets/fonts/` (Baloo 2 para `display*`/`headline*`,
  Nunito Sans para el resto). Usar colores del `ColorScheme`, nunca `Color(0x…)` sueltos. Los SVG maestros
  (logo, ícono, mascota) están en `assets/brand/`; los PNG de Android, iOS y la web se generan con
  `tool/brand_icons`.

## Convenciones

- Estado con Riverpod; sin lógica de negocio en los widgets.
- Todo repositorio recibe `Dio` y `SessionStorage` por constructor (testeable con fakes, ver `test/fakes.dart`).
- Tests para redirecciones, repositorios y validaciones de formularios.
- Accesibilidad: una fila tocable dentro de una tarjeta con otros textos (ej. `SetupCard`) va en
  `Semantics(container: true, button: true)` para que el lector de pantalla la lea y active como botón propio (test con
  `tester.ensureSemantics()` y `find.semantics`). En la web, el lector no lee el valor de un campo prellenado: repetilo
  en el `helperText` si importa (ej. el monto de "Depositar").
- Un formulario que marcó un error lo vuelve a validar cuando el campo cambia (ej. el monto de "Informar
  transferencia" al tildar cuotas).
- Nada se borra de verdad: lo que la app "borra" (retirar un comprobante o un depósito, cancelar una solicitud) la API
  lo archiva (soft delete) y guarda quién lo hizo; los cargos y pagos se anulan. Ver `academia-api/CLAUDE.md`.
