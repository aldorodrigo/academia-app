import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/utils/clock.dart';
import '../../../core/utils/format.dart';
import '../data/calendar_providers.dart';
import '../data/models.dart';
import 'calendar_style.dart';

/// Inicio: los próximos eventos y días sin clase (se oculta si no hay).
class UpcomingEventsCard extends ConsumerWidget {
  const UpcomingEventsCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final events = ref.watch(upcomingEventsProvider).value ?? const [];
    if (events.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final today = ref.watch(todayProvider);
    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
            child: Text('Próximamente', style: theme.textTheme.titleMedium),
          ),
          for (final event in events)
            ListTile(
              leading: Icon(
                eventIcon(event),
                color: theme.colorScheme.tertiary,
              ),
              title: Text(
                event.isDayOff ? 'Sin clases: ${event.title}' : event.title,
              ),
              subtitle: Text(_when(event, today)),
              onTap: () => context.push('/eventos/${event.id}'),
            ),
          Align(
            alignment: Alignment.centerRight,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
              child: TextButton(
                onPressed: () => context.push('/calendario'),
                child: const Text('Ver calendario'),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// "Sáb 11/10 · 08:00 a 18:00", "Hoy · Todo el día" o "Del lun 7/7 al vie 18/7".
  static String _when(CalendarEvent event, DateTime today) {
    if (event.isMultiDay) return event.dateDescription;
    return '${formatShortDay(event.startsOn, today)} · ${event.timeDescription}';
  }
}
