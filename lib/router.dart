import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'features/account/presentation/account_screen.dart';
import 'features/attendance/presentation/class_attendance_screen.dart';
import 'features/attendance/presentation/group_screen.dart';
import 'features/attendance/presentation/groups_screen.dart';
import 'features/auth/data/models.dart';
import 'features/billing/presentation/balance_screen.dart';
import 'features/auth/data/session_controller.dart';
import 'features/auth/presentation/create_account_screen.dart';
import 'features/auth/presentation/forgot_password_screen.dart';
import 'features/auth/presentation/login_screen.dart';
import 'features/auth/presentation/register_screen.dart';
import 'features/auth/presentation/verify_account_screen.dart';
import 'features/home/presentation/home_screen.dart';
import 'features/invitations/presentation/invitation_code_screen.dart';
import 'features/invitations/presentation/invitation_screen.dart';
import 'features/lessons/presentation/book_lesson_screen.dart';
import 'features/lessons/presentation/bookings_screen.dart';
import 'features/lessons/presentation/lesson_profile_screen.dart';
import 'features/lessons/presentation/teacher_agenda_screen.dart';
import 'features/lessons/presentation/teacher_students_screen.dart';
import 'features/notifications/presentation/notification_settings_screen.dart';
import 'features/onboarding/presentation/club_form_screen.dart';
import 'features/onboarding/presentation/groups_step_screen.dart';
import 'features/onboarding/presentation/instructors_step_screen.dart';
import 'features/onboarding/presentation/programs_step_screen.dart';
import 'features/onboarding/presentation/season_step_screen.dart';
import 'features/onboarding/presentation/setup_done_screen.dart';
import 'features/onboarding/presentation/setup_screen.dart';
import 'features/organizations/presentation/organization_picker_screen.dart';
import 'features/reports/presentation/reports_screen.dart';
import 'features/students/presentation/student_screen.dart';
import 'features/students/presentation/students_screen.dart';

/// Decide a dónde ir según el estado de la sesión.
///
/// Mientras se restaura la sesión se espera en `/`, recordando la ruta pedida
/// en `from` (link directo o recarga en la web) para volver ahí después.
String? sessionRedirect(
  AsyncValue<Session?> session,
  String location, {
  String? from,
}) {
  // Las invitaciones se abren con o sin sesión (link o QR).
  if (location.startsWith('/invitacion')) return null;

  if (session.isLoading) {
    if (location == '/') return null;
    return Uri(path: '/', queryParameters: {'from': location}).toString();
  }

  final value = session.value;
  if (value == null) return _public.contains(location) ? null : '/ingresar';

  // Cuenta recién creada: primero el código (WhatsApp o correo).
  if (!value.verified) {
    return location == '/registro/codigo' ? null : '/registro/codigo';
  }
  if (location == '/registro/codigo' ||
      location == '/crear-cuenta' ||
      location == '/registro' ||
      location == '/recuperar') {
    if (value.organizations.isEmpty) return '/registro/club';
    return value.organizationSlug == null ? '/organizaciones' : '/inicio';
  }

  if (value.organizationSlug == null) {
    return location == '/organizaciones' || location == '/registro/club'
        ? null
        : '/organizaciones';
  }

  if (location == '/' || location == '/ingresar') {
    return _isInternal(from) ? from : '/inicio';
  }
  return null;
}

/// Rutas sin sesión: ingresar, crear cuenta y recuperar la contraseña.
const _public = {'/ingresar', '/crear-cuenta', '/registro', '/recuperar'};

/// Solo rutas de la app (evita redirigir a otro sitio con `from=//…`).
bool _isInternal(String? path) =>
    path != null &&
    path.startsWith('/') &&
    !path.startsWith('//') &&
    path != '/' &&
    !path.startsWith('/ingresar');

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = ValueNotifier(0);
  ref.listen(sessionControllerProvider, (_, _) => refresh.value++);
  ref.onDispose(refresh.dispose);

  return GoRouter(
    initialLocation: '/',
    refreshListenable: refresh,
    redirect: (context, state) => sessionRedirect(
      ref.read(sessionControllerProvider),
      state.matchedLocation,
      from: state.uri.queryParameters['from'],
    ),
    routes: [
      GoRoute(
        path: '/',
        builder: (_, _) =>
            const Scaffold(body: Center(child: CircularProgressIndicator())),
      ),
      GoRoute(path: '/ingresar', builder: (_, _) => const LoginScreen()),
      GoRoute(
        path: '/recuperar',
        builder: (_, state) =>
            ForgotPasswordScreen(login: state.uri.queryParameters['login']),
      ),
      GoRoute(
        path: '/crear-cuenta',
        builder: (_, _) => const CreateAccountScreen(),
      ),
      GoRoute(
        path: '/registro',
        builder: (_, _) => const RegisterScreen(),
        routes: [
          GoRoute(
            path: 'codigo',
            builder: (_, _) => const VerifyAccountScreen(),
          ),
          GoRoute(path: 'club', builder: (_, _) => const ClubFormScreen()),
        ],
      ),
      GoRoute(
        path: '/configurar',
        builder: (_, _) => const SetupScreen(),
        routes: [
          GoRoute(
            path: 'disciplinas',
            builder: (_, _) => const ProgramsStepScreen(),
          ),
          GoRoute(
            path: 'categorias',
            builder: (_, _) => const GroupsStepScreen(),
          ),
          GoRoute(
            path: 'temporada',
            builder: (_, _) => const SeasonStepScreen(),
          ),
          GoRoute(
            path: 'tecnicos',
            builder: (_, _) => const InstructorsStepScreen(),
          ),
          GoRoute(path: 'listo', builder: (_, _) => const SetupDoneScreen()),
        ],
      ),
      GoRoute(
        path: '/organizaciones',
        builder: (_, _) => const OrganizationPickerScreen(),
      ),
      GoRoute(path: '/inicio', builder: (_, _) => const HomeScreen()),
      GoRoute(path: '/cuenta', builder: (_, _) => const AccountScreen()),
      GoRoute(path: '/informes', builder: (_, _) => const ReportsScreen()),
      GoRoute(
        path: '/estado-de-cuenta',
        builder: (_, _) => const BalanceScreen(),
      ),
      GoRoute(
        path: '/hijos',
        builder: (_, _) => const StudentsScreen(),
        routes: [
          GoRoute(
            path: ':id',
            builder: (_, state) =>
                StudentScreen(id: int.parse(state.pathParameters['id']!)),
          ),
        ],
      ),
      GoRoute(
        path: '/clases/:id',
        builder: (_, state) =>
            ClassAttendanceScreen(id: int.parse(state.pathParameters['id']!)),
      ),
      GoRoute(
        path: '/notificaciones',
        builder: (_, _) => const NotificationSettingsScreen(),
      ),
      GoRoute(
        path: '/grupos',
        builder: (_, _) => const GroupsScreen(),
        routes: [
          GoRoute(
            path: ':id',
            builder: (_, state) =>
                GroupScreen(id: int.parse(state.pathParameters['id']!)),
          ),
        ],
      ),
      GoRoute(path: '/reservas', builder: (_, _) => const BookingsScreen()),
      GoRoute(
        path: '/particulares/agenda',
        builder: (_, _) => const TeacherAgendaScreen(),
      ),
      GoRoute(
        path: '/particulares/alumnos',
        builder: (_, _) => const TeacherStudentsScreen(),
      ),
      GoRoute(
        path: '/particulares/ajustes',
        builder: (_, _) => const LessonProfileScreen(),
      ),
      GoRoute(
        path: '/particulares/:teacherId/reservar',
        builder: (_, state) => BookLessonScreen(
          teacherId: int.parse(state.pathParameters['teacherId']!),
          studentId: int.tryParse(state.uri.queryParameters['alumno'] ?? ''),
        ),
      ),
      GoRoute(
        path: '/invitacion',
        builder: (_, _) => const InvitationCodeScreen(),
        routes: [
          GoRoute(
            path: ':token',
            builder: (_, state) =>
                InvitationScreen(token: state.pathParameters['token']!),
          ),
        ],
      ),
    ],
  );
});
