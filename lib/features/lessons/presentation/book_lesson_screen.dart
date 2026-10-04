import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/api_client.dart';
import '../../../core/utils/clock.dart';
import '../../../core/utils/format.dart';
import '../data/booking_controller.dart';
import '../data/lessons_repository.dart';
import '../data/models.dart';

/// Reservar una clase particular: a quién (si hay varios), día y hora, con el
/// resumen de lo que se cobra siempre a la vista.
class BookLessonScreen extends ConsumerWidget {
  const BookLessonScreen({super.key, required this.teacherId, this.studentId});

  final int teacherId;

  /// Alumno elegido desde la tarjeta del inicio.
  final int? studentId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final teacher = ref.watch(lessonTeacherProvider(teacherId));

    return Scaffold(
      appBar: AppBar(
        title: Text(
          teacher.value == null
              ? 'Reservar clase'
              : 'Reservar con ${teacher.value!.firstName}',
        ),
        leading: BackButton(
          onPressed: () =>
              context.canPop() ? context.pop() : context.go('/inicio'),
        ),
      ),
      body: teacher.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text(apiErrorMessage(error))),
        data: (teacher) {
          if (teacher == null || teacher.students.isEmpty) {
            return const Center(
              child: Text('Este profesor no tiene clases para reservar.'),
            );
          }
          final initial =
              teacher.studentById(studentId ?? -1)?.student.id ??
              (teacher.students.length == 1
                  ? teacher.students.single.student.id
                  : null);
          return _BookingForm(
            teacher: teacher,
            bookingKey: (teacherId: teacher.id, studentId: initial),
          );
        },
      ),
    );
  }
}

class _BookingForm extends ConsumerWidget {
  const _BookingForm({required this.teacher, required this.bookingKey});

  final Teacher teacher;
  final BookingKey bookingKey;

  Future<void> _submit(BuildContext context, WidgetRef ref) async {
    final booking = await ref
        .read(bookingControllerProvider(bookingKey).notifier)
        .submit();
    if (booking == null || !context.mounted) return;
    final today = ref.read(todayProvider);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Reservado: ${formatDay(booking.date, today)} a las ${booking.startsAt}.',
        ),
      ),
    );
    context.canPop() ? context.pop() : context.go('/inicio');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final form = ref.watch(bookingControllerProvider(bookingKey));
    final controller = ref.read(bookingControllerProvider(bookingKey).notifier);
    final slots = ref.watch(lessonSlotsProvider(teacher.id));
    final today = ref.watch(todayProvider);
    final entry = form.studentId == null
        ? null
        : teacher.studentById(form.studentId!);

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (teacher.students.length > 1) ...[
                Text('¿Para quién?', style: theme.textTheme.titleMedium),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    for (final s in teacher.students)
                      ChoiceChip(
                        label: Text(s.student.firstName),
                        selected: form.studentId == s.student.id,
                        onSelected: (_) =>
                            controller.selectStudent(s.student.id),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
              ],
              if (entry != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Text(
                    describePack(entry.pack, teacher, today),
                    style: theme.textTheme.bodyMedium,
                  ),
                ),
              Text('Elegí el día', style: theme.textTheme.titleMedium),
              const SizedBox(height: 8),
              slots.when(
                loading: () => const LinearProgressIndicator(),
                error: (error, _) => Text(apiErrorMessage(error)),
                data: (slots) => slots.days.isEmpty
                    ? const Text(
                        'No hay horarios libres en los próximos días. Probá más adelante.',
                      )
                    : _DaysAndTimes(
                        slots: slots,
                        form: form,
                        controller: controller,
                        today: today,
                      ),
              ),
            ],
          ),
        ),
        _Summary(
          teacher: teacher,
          form: form,
          pack: entry?.pack,
          slots: slots.value,
          onSubmit: () => _submit(context, ref),
        ),
      ],
    );
  }
}

class _DaysAndTimes extends StatelessWidget {
  const _DaysAndTimes({
    required this.slots,
    required this.form,
    required this.controller,
    required this.today,
  });

  final Slots slots;
  final BookingForm form;
  final BookingController controller;
  final DateTime today;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    SlotDay? day;
    for (final d in slots.days) {
      if (d.date == form.date) day = d;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 48,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: slots.days.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (_, i) {
              final d = slots.days[i];
              return ChoiceChip(
                label: Text(formatShortDay(d.date, today)),
                selected: form.date == d.date,
                onSelected: (_) => controller.selectDate(d.date),
              );
            },
          ),
        ),
        const SizedBox(height: 16),
        if (day != null) ...[
          Text('Elegí la hora', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final time in day.times)
                ChoiceChip(
                  label: Text(time),
                  selected: form.time == time,
                  onSelected: (_) => controller.selectTime(time),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Cada clase dura ${slots.durationMinutes} minutos.',
            style: theme.textTheme.bodySmall,
          ),
        ],
      ],
    );
  }
}

/// Resumen fijo abajo: qué se reserva y cómo se paga.
class _Summary extends StatelessWidget {
  const _Summary({
    required this.teacher,
    required this.form,
    required this.pack,
    required this.slots,
    required this.onSubmit,
  });

  final Teacher teacher;
  final BookingForm form;
  final ClassPack? pack;
  final Slots? slots;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final date = form.date;
    final time = form.time;
    final String title;
    String? detail;
    if (form.studentId == null) {
      title = 'Elegí para quién es la clase.';
    } else if (date == null) {
      title = 'Elegí el día.';
    } else if (time == null) {
      title = 'Elegí la hora.';
    } else {
      final end = slots?.endOf(time);
      title =
          '${_capitalized(weekdayLong(date.weekday))} ${date.day}/${date.month} a las $time${end == null ? '' : ' (hasta las $end)'} con ${teacher.firstName}';
      detail = previewBooking(teacher, pack, date).message;
    }

    return Material(
      elevation: 8,
      color: theme.colorScheme.surfaceContainer,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(title, style: theme.textTheme.titleSmall),
              if (detail != null) Text(detail),
              if (form.error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    form.error!,
                    style: TextStyle(color: theme.colorScheme.error),
                  ),
                ),
              const SizedBox(height: 8),
              FilledButton(
                onPressed: form.isComplete && !form.submitting
                    ? onSubmit
                    : null,
                child: Text(form.submitting ? 'Reservando…' : 'Reservar'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _capitalized(String text) =>
    text.isEmpty ? text : '${text[0].toUpperCase()}${text.substring(1)}';
