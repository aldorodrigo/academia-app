import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/storage/session_storage.dart';
import '../../../core/utils/format.dart';
import '../../auth/data/session_controller.dart';
import 'models.dart';

/// Clases particulares del lado del alumno adulto o del tutor.
class LessonsRepository {
  LessonsRepository(this._dio, this._storage);

  final Dio _dio;
  final SessionStorage _storage;

  Future<List<Teacher>> teachers() async {
    if (await _storage.readOrganization() == null) return const [];
    final response = await _dio.get<Map<String, dynamic>>('/lessons/teachers');
    return _items(response.data!, Teacher.fromJson);
  }

  Future<Slots> slots(int teacherId, {DateTime? from, DateTime? to}) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/lessons/teachers/$teacherId/slots',
      queryParameters: {'from': ?from.map(apiDate), 'to': ?to.map(apiDate)},
    );
    return Slots.fromJson(_data(response.data!));
  }

  Future<Booking> book({
    required int teacherId,
    required int studentId,
    required DateTime date,
    required String startsAt,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/bookings',
      data: {
        'teacher_id': teacherId,
        'student_id': studentId,
        'date': apiDate(date),
        'starts_at': startsAt,
      },
    );
    return Booking.fromJson(_data(response.data!));
  }

  Future<Bookings> bookings({int? studentId}) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/bookings',
      queryParameters: {'student_id': ?studentId},
    );
    return Bookings.fromJson(_data(response.data!));
  }

  Future<Booking> cancel(int id) async {
    final response = await _dio.delete<Map<String, dynamic>>('/bookings/$id');
    return Booking.fromJson(_data(response.data!));
  }

  Future<ClassPack> buyPack(int offerId, {required int studentId}) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/lessons/packs/$offerId/buy',
      data: {'student_id': studentId},
    );
    return ClassPack.fromJson(_data(response.data!));
  }
}

/// Clases particulares del lado del profesor.
class TeacherLessonsRepository {
  TeacherLessonsRepository(this._dio, this._storage);

  final Dio _dio;

  // Mismo contrato que el resto de los repositorios (sesión y organización por el interceptor).
  // ignore: unused_field
  final SessionStorage _storage;

  Future<LessonProfile> profile() async {
    final response = await _dio.get<Map<String, dynamic>>('/me/lesson-profile');
    return LessonProfile.fromJson(_data(response.data!));
  }

  Future<LessonProfile> saveProfile(LessonProfile profile) async {
    final response = await _dio.put<Map<String, dynamic>>(
      '/me/lesson-profile',
      data: profile.toJson(),
    );
    return LessonProfile.fromJson(_data(response.data!));
  }

  Future<List<Booking>> bookings(DateTime from, DateTime to) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/teacher/bookings',
      queryParameters: {'from': apiDate(from), 'to': apiDate(to)},
    );
    return _items(response.data!, Booking.fromJson);
  }

  Future<Booking> mark(int id, {required bool attended}) async {
    final response = await _dio.put<Map<String, dynamic>>(
      '/teacher/bookings/$id/attendance',
      data: {'attended': attended},
    );
    return Booking.fromJson(_data(response.data!));
  }

  Future<Booking> cancel(int id, {String? reason}) async {
    final response = await _dio.delete<Map<String, dynamic>>(
      '/teacher/bookings/$id',
      data: {'reason': ?reason},
    );
    return Booking.fromJson(_data(response.data!));
  }

  Future<PaymentResult> collect({
    required int studentId,
    required int amount,
    required PaymentMethod method,
    int? bookingId,
    int? classPackId,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/teacher/payments',
      data: {
        'student_id': studentId,
        'amount': amount,
        'method': method.value,
        'booking_id': ?bookingId,
        'class_pack_id': ?classPackId,
      },
    );
    return PaymentResult.fromJson(_data(response.data!));
  }

  Future<List<TeacherStudentSummary>> students() async {
    final response = await _dio.get<Map<String, dynamic>>('/teacher/students');
    return _items(response.data!, TeacherStudentSummary.fromJson);
  }

  Future<ClassPack> sellPack(int studentId, int offerId) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/teacher/students/$studentId/packs',
      data: {'lesson_pack_id': offerId},
    );
    return ClassPack.fromJson(_data(response.data!));
  }

  Future<ClassPack> extend(int packId, DateTime expiresOn) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/teacher/packs/$packId/extend',
      data: {'expires_on': apiDate(expiresOn)},
    );
    return ClassPack.fromJson(_data(response.data!));
  }
}

Map<String, dynamic> _data(Map<String, dynamic> body) =>
    body['data'] as Map<String, dynamic>;

List<T> _items<T>(
  Map<String, dynamic> body,
  T Function(Map<String, dynamic>) parse,
) => (body['data'] as List)
    .map((e) => parse(e as Map<String, dynamic>))
    .toList();

final lessonsRepositoryProvider = Provider<LessonsRepository>(
  (ref) => LessonsRepository(
    ref.watch(apiClientProvider),
    ref.watch(sessionStorageProvider),
  ),
);

final teacherLessonsRepositoryProvider = Provider<TeacherLessonsRepository>(
  (ref) => TeacherLessonsRepository(
    ref.watch(apiClientProvider),
    ref.watch(sessionStorageProvider),
  ),
);

/// Profesores con clases particulares; se vuelve a pedir al cambiar de organización.
final lessonTeachersProvider = FutureProvider<List<Teacher>>((ref) async {
  final slug = await ref.watch(
    sessionControllerProvider.selectAsync((s) => s?.organizationSlug),
  );
  if (slug == null) return const [];
  return ref.watch(lessonsRepositoryProvider).teachers();
}, retry: (_, _) => null);

final lessonTeacherProvider = FutureProvider.autoDispose.family<Teacher?, int>((
  ref,
  id,
) async {
  final teachers = await ref.watch(lessonTeachersProvider.future);
  for (final teacher in teachers) {
    if (teacher.id == id) return teacher;
  }
  return null;
}, retry: (_, _) => null);

final lessonSlotsProvider = FutureProvider.autoDispose.family<Slots, int>(
  (ref, teacherId) => ref.watch(lessonsRepositoryProvider).slots(teacherId),
  retry: (_, _) => null,
);

/// Reservas de los alumnos a cargo (null = todos).
final bookingsProvider = FutureProvider.autoDispose.family<Bookings, int?>(
  (ref, studentId) =>
      ref.watch(lessonsRepositoryProvider).bookings(studentId: studentId),
  retry: (_, _) => null,
);

/// Reservas del profesor entre dos días (inclusive).
final teacherBookingsProvider = FutureProvider.autoDispose
    .family<List<Booking>, ({DateTime from, DateTime to})>(
      (ref, range) => ref
          .watch(teacherLessonsRepositoryProvider)
          .bookings(range.from, range.to),
      retry: (_, _) => null,
    );

final teacherStudentsProvider =
    FutureProvider.autoDispose<List<TeacherStudentSummary>>(
      (ref) => ref.watch(teacherLessonsRepositoryProvider).students(),
      retry: (_, _) => null,
    );

extension on DateTime? {
  T? map<T>(T Function(DateTime) f) {
    final value = this;
    return value == null ? null : f(value);
  }
}
