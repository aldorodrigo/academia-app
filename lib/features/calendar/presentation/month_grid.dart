import 'package:flutter/material.dart';

import '../../../core/utils/format.dart';
import '../data/models.dart';
import 'calendar_style.dart';

const _weekdayInitials = ['L', 'M', 'M', 'J', 'V', 'S', 'D'];

/// Mes en 6 semanas (lunes primero) con las marcas de cada día.
class MonthGrid extends StatelessWidget {
  const MonthGrid({
    required this.month,
    required this.selected,
    required this.today,
    required this.onSelect,
    super.key,
    this.data,
    this.types = const {...CalendarType.values},
    this.large = false,
  });

  final DateTime month;
  final DateTime selected;
  final DateTime today;
  final ValueChanged<DateTime> onSelect;
  final CalendarRange? data;
  final Set<CalendarType> types;

  /// Pantalla ancha: celdas altas con los títulos del día.
  final bool large;

  @override
  Widget build(BuildContext context) {
    final from = gridRange(month).from;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const WeekdayHeader(),
        for (var week = 0; week < 6; week++)
          Row(
            children: [
              for (var weekday = 0; weekday < 7; weekday++)
                Expanded(
                  child: DayCell(
                    day: DateTime(
                      from.year,
                      from.month,
                      from.day + week * 7 + weekday,
                    ),
                    month: month,
                    selected: selected,
                    today: today,
                    data: data,
                    types: types,
                    large: large,
                    onSelect: onSelect,
                  ),
                ),
            ],
          ),
      ],
    );
  }
}

/// La semana del día elegido (la grilla plegada).
class WeekStrip extends StatelessWidget {
  const WeekStrip({
    required this.selected,
    required this.today,
    required this.onSelect,
    super.key,
    this.data,
    this.types = const {...CalendarType.values},
  });

  final DateTime selected;
  final DateTime today;
  final ValueChanged<DateTime> onSelect;
  final CalendarRange? data;
  final Set<CalendarType> types;

  @override
  Widget build(BuildContext context) {
    final monday = weekStart(selected);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const WeekdayHeader(),
        Row(
          children: [
            for (var i = 0; i < 7; i++)
              Expanded(
                child: DayCell(
                  day: DateTime(monday.year, monday.month, monday.day + i),
                  month: selected,
                  selected: selected,
                  today: today,
                  data: data,
                  types: types,
                  onSelect: onSelect,
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class WeekdayHeader extends StatelessWidget {
  const WeekdayHeader({super.key});

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.labelSmall
        ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant);
    // Los lectores de pantalla leen el día completo en cada celda.
    return ExcludeSemantics(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            for (final initial in _weekdayInitials)
              Expanded(
                child: Text(initial, textAlign: TextAlign.center, style: style),
              ),
          ],
        ),
      ),
    );
  }
}

/// Un día de la grilla: número, marcas y fondo si no hay clases.
class DayCell extends StatelessWidget {
  const DayCell({
    required this.day,
    required this.month,
    required this.selected,
    required this.today,
    required this.onSelect,
    super.key,
    this.data,
    this.types = const {...CalendarType.values},
    this.large = false,
  });

  final DateTime day;

  /// Mes que se muestra (los días de otros meses van apagados).
  final DateTime month;
  final DateTime selected;
  final DateTime today;
  final ValueChanged<DateTime> onSelect;
  final CalendarRange? data;
  final Set<CalendarType> types;
  final bool large;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isSelected = _same(day, selected);
    final isToday = _same(day, today);
    final inMonth = day.month == month.month;
    final markers = data?.markersOn(day, types: types) ?? const [];
    final dayOff = data?.daysOffOn(day, types: types).isNotEmpty ?? false;
    final entries = large
        ? data?.entriesOn(day, types: types) ?? const <CalendarEntry>[]
        : const <CalendarEntry>[];

    final number = Container(
      width: 34,
      height: 34,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isSelected ? scheme.primaryContainer : null,
        border: isToday && !isSelected
            ? Border.all(color: scheme.primary, width: 1.5)
            : null,
      ),
      child: FittedBox(
        child: Text(
          '${day.day}',
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: isToday || isSelected ? FontWeight.w700 : null,
            color: isSelected
                ? scheme.onPrimaryContainer
                : inMonth
                ? scheme.onSurface
                : scheme.onSurfaceVariant.withValues(alpha: 0.6),
          ),
        ),
      ),
    );

    return Semantics(
      button: true,
      selected: isSelected,
      label: dayLabel(day, today, data, types),
      excludeSemantics: true,
      child: InkWell(
        onTap: () => onSelect(day),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          height: large ? 104 : 54,
          margin: const EdgeInsets.all(1),
          decoration: BoxDecoration(
            color: dayOff ? scheme.surfaceContainerHighest : null,
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.only(top: 2),
          child: Column(
            crossAxisAlignment: large
                ? CrossAxisAlignment.start
                : CrossAxisAlignment.center,
            children: [
              Row(
                mainAxisAlignment: large
                    ? MainAxisAlignment.spaceBetween
                    : MainAxisAlignment.center,
                children: [
                  number,
                  if (dayOff && large)
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: Icon(
                        Icons.event_busy,
                        size: 16,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
              if (large)
                for (final entry in entries.take(2))
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: Text(
                      _shortTitle(entry),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: _isOff(entry)
                          ? theme.textTheme.labelSmall?.copyWith(
                              decoration: TextDecoration.lineThrough,
                              color: scheme.onSurfaceVariant,
                            )
                          : theme.textTheme.labelSmall,
                    ),
                  ),
              if (large && entries.length > 2)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: Text(
                    '+${entries.length - 2} más',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
              if (!large) ...[
                const SizedBox(height: 3),
                _Markers(markers: markers, dayOff: dayOff),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// Suspendida, reprogramada o cancelada: se ve tachada.
  static bool _isOff(CalendarEntry entry) => switch (entry) {
    ClassEntry(:final item) => item.session.isOff,
    BookingEntry(:final item) => item.booking.status.isCancelled,
    EventEntry(:final event) => event.cancelled,
  };

  static String _shortTitle(CalendarEntry entry) => switch (entry) {
    ClassEntry(:final item) =>
      '${item.session.startsAt} ${item.session.group.name}',
    BookingEntry(:final item) => '${item.booking.startsAt} Particular',
    EventEntry(:final event) => event.title,
  };
}

class _Markers extends StatelessWidget {
  const _Markers({required this.markers, required this.dayOff});

  final List<CalendarMarker> markers;
  final bool dayOff;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (dayOff && markers.isEmpty) {
      return Icon(Icons.event_busy, size: 10, color: scheme.onSurfaceVariant);
    }
    return SizedBox(
      height: 10,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (final marker in markers.take(3))
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 1.5),
              child: CalendarMarkerDot(marker),
            ),
          if (markers.length > 3)
            Text(
              '+',
              style: TextStyle(fontSize: 9, color: scheme.onSurfaceVariant),
            ),
        ],
      ),
    );
  }
}

/// Lo que lee el lector de pantalla en cada día:
/// "martes 7 de octubre, hoy, 2 clases, 1 evento, sin clases".
String dayLabel(
  DateTime day,
  DateTime today,
  CalendarRange? data,
  Set<CalendarType> types,
) {
  final parts = <String>[
    '${weekdayLong(day.weekday)} ${day.day} de ${monthName(day.month)}',
    if (_same(day, today)) 'hoy',
  ];
  if (data != null) {
    final entries = data.entriesOn(day, types: types);
    final classes = entries.whereType<ClassEntry>();
    final off = classes.where((e) => e.item.session.isOff).length;
    final scheduled = classes.length - off;
    final bookings = entries.whereType<BookingEntry>().length;
    final events = entries.whereType<EventEntry>().length;
    if (scheduled > 0) parts.add(_count(scheduled, 'clase', 'clases'));
    if (off > 0) {
      parts.add(_count(off, 'clase suspendida', 'clases suspendidas'));
    }
    if (bookings > 0) {
      parts.add(_count(bookings, 'clase particular', 'clases particulares'));
    }
    if (events > 0) parts.add(_count(events, 'evento', 'eventos'));
    if (data.daysOffOn(day, types: types).isNotEmpty) parts.add('sin clases');
  }
  return parts.join(', ');
}

String _count(int n, String one, String many) => n == 1 ? '1 $one' : '$n $many';

bool _same(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;
