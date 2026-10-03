import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import 'lessons_repository.dart';
import 'models.dart';

/// Lo que eligió el alumno o tutor en "Reservar clase".
class BookingForm {
  const BookingForm({
    this.studentId,
    this.date,
    this.time,
    this.submitting = false,
    this.error,
  });

  final int? studentId;
  final DateTime? date;

  /// "16:00".
  final String? time;
  final bool submitting;
  final String? error;

  bool get isComplete => studentId != null && date != null && time != null;

  BookingForm copyWith({
    int? studentId,
    DateTime? Function()? date,
    String? Function()? time,
    bool? submitting,
    String? Function()? error,
  }) => BookingForm(
    studentId: studentId ?? this.studentId,
    date: date == null ? this.date : date(),
    time: time == null ? this.time : time(),
    submitting: submitting ?? this.submitting,
    error: error == null ? this.error : error(),
  );
}

/// Profesor y alumno con el que arranca el formulario.
typedef BookingKey = ({int teacherId, int? studentId});

/// Formulario de reserva con un profesor.
class BookingController extends Notifier<BookingForm> {
  BookingController(this.key);

  final BookingKey key;

  int get teacherId => key.teacherId;

  @override
  BookingForm build() => BookingForm(studentId: key.studentId);

  void selectStudent(int id) =>
      state = state.copyWith(studentId: id, error: () => null);

  /// Al cambiar de día se borra la hora elegida.
  void selectDate(DateTime date) => state = state.copyWith(
    date: () => date,
    time: () => null,
    error: () => null,
  );

  void selectTime(String time) =>
      state = state.copyWith(time: () => time, error: () => null);

  /// Reserva; null si falló (el error queda en el estado). Si otro ganó el
  /// horario, se vuelven a pedir las horas libres.
  Future<Booking?> submit() async {
    final form = state;
    if (!form.isComplete || form.submitting) return null;
    state = form.copyWith(submitting: true, error: () => null);
    try {
      final booking = await ref
          .read(lessonsRepositoryProvider)
          .book(
            teacherId: teacherId,
            studentId: form.studentId!,
            date: form.date!,
            startsAt: form.time!,
          );
      ref.invalidate(lessonTeachersProvider);
      ref.invalidate(bookingsProvider);
      ref.invalidate(lessonSlotsProvider(teacherId));
      state = form.copyWith(submitting: false);
      return booking;
    } catch (error) {
      final taken = _slotTaken(error);
      if (taken) ref.invalidate(lessonSlotsProvider(teacherId));
      state = form.copyWith(
        submitting: false,
        time: taken ? () => null : null,
        error: () => apiErrorMessage(error),
      );
      return null;
    }
  }
}

/// La API rechazó la hora (otro la reservó o ya no está libre).
bool _slotTaken(Object error) {
  if (error is! DioException) return false;
  final status = error.response?.statusCode;
  if (status == 409) return true;
  final data = error.response?.data;
  return status == 422 &&
      data is Map &&
      data['errors'] is Map &&
      (data['errors'] as Map).containsKey('starts_at');
}

final bookingControllerProvider = NotifierProvider.autoDispose
    .family<BookingController, BookingForm, BookingKey>(BookingController.new);

/// Acciones del alumno o tutor fuera del formulario (cancelar, comprar paquete).
class StudentLessonActions {
  StudentLessonActions(this._ref);

  final Ref _ref;

  LessonsRepository get _repository => _ref.read(lessonsRepositoryProvider);

  Future<Booking> cancel(Booking booking) async {
    final cancelled = await _repository.cancel(booking.id);
    _refresh(booking.teacher.id);
    return cancelled;
  }

  Future<ClassPack> buyPack(
    Teacher teacher,
    LessonOffer offer, {
    required int studentId,
  }) async {
    final pack = await _repository.buyPack(offer.id!, studentId: studentId);
    _refresh(teacher.id);
    return pack;
  }

  void _refresh(int teacherId) {
    _ref.invalidate(lessonTeachersProvider);
    _ref.invalidate(bookingsProvider);
    _ref.invalidate(lessonSlotsProvider(teacherId));
  }
}

final studentLessonActionsProvider = Provider<StudentLessonActions>(
  StudentLessonActions.new,
);

/// Mensaje al comprar un paquete.
String packPurchasedMessage(ClassPack pack) => pack.isActive
    ? 'Listo: tenés ${pack.classes} clases para reservar (lo pagaste con tu saldo a favor).'
    : 'Paquete pedido. Pagáselo al profesor o en la secretaría y se activan tus clases.';

/// Acciones del profesor: marcar, cobrar, cancelar, vender y extender paquetes.
class TeacherLessonActions {
  TeacherLessonActions(this._ref);

  final Ref _ref;

  TeacherLessonsRepository get _repository =>
      _ref.read(teacherLessonsRepositoryProvider);

  Future<Booking> mark(Booking booking, {required bool attended}) async {
    final marked = await _repository.mark(booking.id, attended: attended);
    _refresh();
    return marked;
  }

  Future<Booking> cancel(Booking booking, {String? reason}) async {
    final cancelled = await _repository.cancel(
      booking.id,
      reason: reason == null || reason.trim().isEmpty ? null : reason.trim(),
    );
    _refresh();
    return cancelled;
  }

  Future<PaymentResult> collect({
    required int studentId,
    required int amount,
    required PaymentMethod method,
    int? bookingId,
    int? classPackId,
  }) async {
    final result = await _repository.collect(
      studentId: studentId,
      amount: amount,
      method: method,
      bookingId: bookingId,
      classPackId: classPackId,
    );
    _refresh();
    return result;
  }

  Future<ClassPack> sellPack(int studentId, LessonOffer offer) async {
    final pack = await _repository.sellPack(studentId, offer.id!);
    _refresh();
    return pack;
  }

  Future<ClassPack> extend(ClassPack pack, DateTime expiresOn) async {
    final extended = await _repository.extend(pack.id, expiresOn);
    _refresh();
    return extended;
  }

  void _refresh() {
    _ref.invalidate(teacherBookingsProvider);
    _ref.invalidate(teacherStudentsProvider);
  }
}

final teacherLessonActionsProvider = Provider<TeacherLessonActions>(
  TeacherLessonActions.new,
);

/// Mensaje después de marcar una reserva.
String markedMessage(Booking booking) {
  if (booking.status == BookingStatus.absent) {
    return booking.usesPack
        ? 'Marcado: no vino. No se descontó la clase.'
        : 'Marcado: no vino. No se cobra.';
  }
  if (booking.usesPack) {
    final pack = booking.pack;
    if (pack == null) return 'Se descontó 1 clase del paquete.';
    if (pack.remaining == 0) {
      return 'Se descontó la última clase del paquete. Ofrecele uno nuevo.';
    }
    return 'Se descontó 1 clase. Le ${pack.remaining == 1 ? 'queda 1' : 'quedan ${pack.remaining}'} de ${pack.classes}.';
  }
  return booking.amountDue > 0
      ? 'Marcado: vino.'
      : 'Marcado: vino. Ya estaba pagada.';
}

/// Fecha nueva al extender un paquete: desde su vencimiento (o desde hoy si ya venció).
DateTime extendedExpiry(ClassPack pack, int days, DateTime today) {
  final base = pack.expiresOn == null || pack.expiresOn!.isBefore(today)
      ? today
      : pack.expiresOn!;
  return DateTime(base.year, base.month, base.day + days);
}

/// Ajustes del profesor mientras los edita; se guardan con [save].
class LessonProfileController extends AsyncNotifier<LessonProfile> {
  TeacherLessonsRepository get _repository =>
      ref.read(teacherLessonsRepositoryProvider);

  @override
  Future<LessonProfile> build() => _repository.profile();

  LessonProfile? get _profile => state.value;

  void edit(LessonProfile Function(LessonProfile) change) {
    final profile = _profile;
    if (profile == null) return;
    state = AsyncData(change(profile));
  }

  void addPack(LessonOffer offer) =>
      edit((p) => p.copyWith(packs: [...p.packs, offer]));

  void replacePack(int index, LessonOffer offer) =>
      edit((p) => p.copyWith(packs: [...p.packs]..[index] = offer));

  void removePack(int index) =>
      edit((p) => p.copyWith(packs: [...p.packs]..removeAt(index)));

  void addRange(AvailabilityRange range) =>
      edit((p) => p.copyWith(availability: [...p.availability, range]));

  void replaceRange(AvailabilityRange old, AvailabilityRange range) => edit(
    (p) => p.copyWith(
      availability: [
        for (final r in p.availability) identical(r, old) ? range : r,
      ],
    ),
  );

  void removeRange(AvailabilityRange range) => edit(
    (p) => p.copyWith(
      availability: [
        for (final r in p.availability)
          if (!identical(r, range)) r,
      ],
    ),
  );

  /// Copia las franjas de un día a todos los demás.
  void copyToAllDays(int weekday) => edit((p) {
    final source = p.rangesOf(weekday);
    return p.copyWith(
      availability: [
        for (var day = 1; day <= 7; day++)
          for (final r in source) r.copyWith(weekday: day),
      ],
    );
  });

  /// Valida y guarda; devuelve el error o null si se guardó.
  Future<String?> save() async {
    final profile = _profile;
    if (profile == null) return null;
    final error = profile.validate();
    if (error != null) return error;
    try {
      state = AsyncData(await _repository.saveProfile(profile));
      return null;
    } catch (error) {
      return apiErrorMessage(error);
    }
  }
}

final lessonProfileProvider =
    AsyncNotifierProvider.autoDispose<LessonProfileController, LessonProfile>(
      LessonProfileController.new,
      retry: (_, _) => null,
    );
