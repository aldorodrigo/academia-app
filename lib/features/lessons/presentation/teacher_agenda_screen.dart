import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/api_client.dart';
import '../../../core/utils/clock.dart';
import '../../../core/utils/format.dart';
import '../data/lessons_repository.dart';
import '../data/models.dart';
import 'today_lessons_card.dart';

/// Agenda del profesor por semana: las reservas de cada día.
class TeacherAgendaScreen extends ConsumerStatefulWidget {
  const TeacherAgendaScreen({super.key});

  @override
  ConsumerState<TeacherAgendaScreen> createState() =>
      _TeacherAgendaScreenState();
}

class _TeacherAgendaScreenState extends ConsumerState<TeacherAgendaScreen> {
  /// Semanas desde la actual (0 = desde hoy hasta dentro de 6 días).
  int _week = 0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final today = ref.watch(todayProvider);
    final from = DateTime(today.year, today.month, today.day + 7 * _week);
    final to = DateTime(from.year, from.month, from.day + 6);
    final bookings = ref.watch(teacherBookingsProvider((from: from, to: to)));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Agenda'),
        leading: BackButton(
          onPressed: () =>
              context.canPop() ? context.pop() : context.go('/inicio'),
        ),
        actions: [
          IconButton(
            tooltip: 'Ajustes de clases particulares',
            icon: const Icon(Icons.tune),
            onPressed: () => context.push('/particulares/ajustes'),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              children: [
                IconButton(
                  tooltip: 'Semana anterior',
                  icon: const Icon(Icons.chevron_left),
                  onPressed: () => setState(() => _week--),
                ),
                Expanded(
                  child: Text(
                    '${formatShortDay(from, today)} al ${formatShortDay(to, today)}',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleSmall,
                  ),
                ),
                IconButton(
                  tooltip: 'Semana siguiente',
                  icon: const Icon(Icons.chevron_right),
                  onPressed: () => setState(() => _week++),
                ),
              ],
            ),
          ),
          Expanded(
            child: bookings.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => Center(child: Text(apiErrorMessage(error))),
              data: (bookings) => bookings.isEmpty
                  ? const Center(child: Text('No hay reservas esta semana.'))
                  : _Days(bookings, today: today),
            ),
          ),
        ],
      ),
    );
  }
}

class _Days extends StatelessWidget {
  const _Days(this.bookings, {required this.today});

  final List<Booking> bookings;
  final DateTime today;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final byDay = <DateTime, List<Booking>>{};
    for (final booking in bookings) {
      byDay.putIfAbsent(booking.date, () => []).add(booking);
    }
    final days = byDay.keys.toList()..sort();

    return ListView(
      padding: const EdgeInsets.only(left: 16, bottom: 16),
      children: [
        for (final day in days) ...[
          Padding(
            padding: const EdgeInsets.only(top: 16, bottom: 4),
            child: Text(
              formatShortDay(day, today),
              style: theme.textTheme.titleMedium,
            ),
          ),
          for (final booking in byDay[day]!) BookingRow(booking),
        ],
      ],
    );
  }
}
