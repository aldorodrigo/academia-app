import 'package:flutter/material.dart';

import '../data/models.dart';

/// Ícono de cada categoría de evento (siempre junto a un texto).
IconData eventIcon(CalendarEvent event) =>
    categoryIcon(event.kind, event.category);

IconData categoryIcon(EventKind kind, String? category) => switch (category) {
  'feriado' => Icons.flag_outlined,
  'vacaciones' => Icons.beach_access_outlined,
  'lluvia' => Icons.umbrella_outlined,
  _ when kind == EventKind.dayOff => Icons.event_busy,
  'torneo' => Icons.emoji_events_outlined,
  'amistoso' => Icons.sports_outlined,
  'festival' => Icons.celebration_outlined,
  'reunion' => Icons.forum_outlined,
  _ => Icons.event_outlined,
};

/// Marca de un día en la grilla: forma y color distintos por tipo.
class CalendarMarkerDot extends StatelessWidget {
  const CalendarMarkerDot(this.marker, {super.key, this.size = 6});

  final CalendarMarker marker;
  final double size;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (color, shape, filled) = switch (marker) {
      CalendarMarker.classScheduled => (scheme.primary, BoxShape.circle, true),
      CalendarMarker.classOff => (scheme.primary, BoxShape.circle, false),
      CalendarMarker.booking => (
        scheme.onSurfaceVariant,
        BoxShape.rectangle,
        true,
      ),
      CalendarMarker.event => (scheme.tertiary, BoxShape.rectangle, true),
    };
    final dot = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: shape,
        color: filled ? color : null,
        border: filled ? null : Border.all(color: color, width: 1.5),
      ),
    );
    // El evento es un rombo: un cuadrado girado.
    return marker == CalendarMarker.event
        ? Transform.rotate(angle: 0.785398, child: dot)
        : dot;
  }
}

/// Qué significa cada marca (leyenda plegable debajo de la grilla).
String markerLabel(CalendarMarker marker) => switch (marker) {
  CalendarMarker.classScheduled => 'Clase',
  CalendarMarker.classOff => 'Clase suspendida',
  CalendarMarker.booking => 'Clase particular',
  CalendarMarker.event => 'Evento',
};

/// Chip chico con ícono y texto (estado de una fila).
class StatusChip extends StatelessWidget {
  const StatusChip({
    required this.label,
    required this.icon,
    super.key,
    this.color,
  });

  final String label;
  final IconData icon;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = this.color ?? scheme.onSurfaceVariant;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            label,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelMedium
                ?.copyWith(color: color),
          ),
        ),
      ],
    );
  }
}
