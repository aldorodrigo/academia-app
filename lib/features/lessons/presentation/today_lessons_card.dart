import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/api_client.dart';
import '../../../core/utils/clock.dart';
import '../../organizations/data/organization_repository.dart';
import '../data/lessons_repository.dart';
import '../data/models.dart';
import 'booking_sheet.dart';

/// Tarjeta del inicio para el profesor: las clases particulares de hoy.
class TodayLessonsCard extends ConsumerWidget {
  const TodayLessonsCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final allowed = ref.watch(teachesLessonsProvider);
    if (!allowed) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final today = ref.watch(todayProvider);
    final bookings = ref.watch(
      teacherBookingsProvider((from: today, to: today)),
    );

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.school_outlined),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Clases particulares de hoy',
                    style: theme.textTheme.titleMedium,
                  ),
                ),
              ],
            ),
            bookings.when(
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: LinearProgressIndicator(),
              ),
              error: (error, _) => Text(apiErrorMessage(error)),
              data: (bookings) => bookings.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Text('Hoy no tenés reservas.'),
                    )
                  : Column(children: [for (final b in bookings) BookingRow(b)]),
            ),
            Wrap(
              alignment: WrapAlignment.end,
              children: [
                TextButton(
                  onPressed: () => context.push('/particulares/alumnos'),
                  child: const Text('Mis alumnos'),
                ),
                TextButton(
                  onPressed: () => context.push('/particulares/agenda'),
                  child: const Text('Agenda'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// El usuario da clases particulares (permiso `teach_lessons`).
final teachesLessonsProvider = Provider<bool>(
  (ref) =>
      ref.watch(currentOrganizationProvider).value?.can('teach_lessons') ??
      false,
);

/// Una reserva en la lista del profesor; al tocarla abre la ficha rápida.
class BookingRow extends StatelessWidget {
  const BookingRow(this.booking, {super.key});

  final Booking booking;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (icon, color) = switch (booking.status) {
      BookingStatus.attended => (Icons.check_circle, theme.colorScheme.primary),
      BookingStatus.absent => (Icons.cancel, theme.colorScheme.error),
      _ => (Icons.radio_button_unchecked, theme.colorScheme.outline),
    };
    return ListTile(
      contentPadding: const EdgeInsets.only(right: 8),
      leading: Icon(icon, color: color),
      title: Text('${booking.startsAt} · ${booking.student.fullName}'),
      subtitle: Text(
        booking.isMarked
            ? '${booking.status.label} · ${booking.paymentSummary}'
            : booking.paymentSummary,
      ),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => showBookingSheet(context, booking),
    );
  }
}
