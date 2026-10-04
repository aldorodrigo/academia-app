import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/api_client.dart';
import '../../../core/utils/clock.dart';
import '../../../core/utils/format.dart';
import '../data/booking_controller.dart';
import '../data/lessons_repository.dart';
import '../data/models.dart';

/// Reservas de clases particulares del alumno adulto o de los hijos del tutor.
class BookingsScreen extends ConsumerWidget {
  const BookingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bookings = ref.watch(bookingsProvider(null));

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Mis reservas'),
          leading: BackButton(
            onPressed: () =>
                context.canPop() ? context.pop() : context.go('/inicio'),
          ),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Próximas'),
              Tab(text: 'Pasadas'),
            ],
          ),
        ),
        body: bookings.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => Center(child: Text(apiErrorMessage(error))),
          data: (bookings) {
            final names = {
              for (final b in [...bookings.upcoming, ...bookings.past])
                b.student.id,
            };
            return TabBarView(
              children: [
                _BookingList(
                  bookings.upcoming,
                  empty: 'No tenés clases reservadas.',
                  showStudent: names.length > 1,
                ),
                _BookingList(
                  bookings.past,
                  empty: 'Todavía no tuviste clases.',
                  showStudent: names.length > 1,
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _BookingList extends StatelessWidget {
  const _BookingList(
    this.bookings, {
    required this.empty,
    required this.showStudent,
  });

  final List<Booking> bookings;
  final String empty;
  final bool showStudent;

  @override
  Widget build(BuildContext context) {
    if (bookings.isEmpty) return Center(child: Text(empty));
    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: bookings.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (_, i) =>
          _BookingTile(bookings[i], showStudent: showStudent),
    );
  }
}

class _BookingTile extends ConsumerWidget {
  const _BookingTile(this.booking, {required this.showStudent});

  final Booking booking;
  final bool showStudent;

  Future<bool> _cancel(
    BuildContext context,
    WidgetRef ref, {
    required String question,
    required String detail,
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(question),
        content: Text(detail),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Volver'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Sí, cancelar'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return false;
    try {
      await ref.read(studentLessonActionsProvider).cancel(booking);
      return true;
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(apiErrorMessage(error))));
      }
      return false;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final today = ref.watch(todayProvider);
    final subtitle = [
      'Con ${booking.teacher.name}',
      if (showStudent) booking.student.firstName,
      if (booking.status == BookingStatus.confirmed)
        booking.usesPack
            ? 'Con el paquete'
            : 'Suelta ${formatMoney(booking.price ?? 0)}'
      else
        booking.status.label,
    ].join(' · ');

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(booking.describe(today), style: theme.textTheme.titleSmall),
          Text(subtitle, style: theme.textTheme.bodySmall),
          if (booking.canCancel)
            Wrap(
              spacing: 8,
              children: [
                TextButton(
                  onPressed: () async {
                    final done = await _cancel(
                      context,
                      ref,
                      question: '¿Cambiar el día u horario?',
                      detail: 'Se cancela esta reserva (sin costo) y elegís otro horario.',
                    );
                    if (done && context.mounted) {
                      context.push(
                        '/particulares/${booking.teacher.id}/reservar?alumno=${booking.student.id}',
                      );
                    }
                  },
                  child: const Text('Cambiar'),
                ),
                TextButton(
                  onPressed: () async {
                    final done = await _cancel(
                      context,
                      ref,
                      question: '¿Cancelar la clase?',
                      detail:
                          'Cancelar no tiene costo. Le avisamos al profesor.',
                    );
                    if (done && context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Clase cancelada.')),
                      );
                    }
                  },
                  child: const Text('Cancelar'),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
