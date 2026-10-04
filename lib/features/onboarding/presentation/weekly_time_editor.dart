import 'package:flutter/material.dart';

import '../../../core/utils/format.dart';
import '../data/models.dart';

/// Horas para elegir, cada 15 minutos de 6:00 a 23:45.
final _times = [for (var m = 6 * 60; m < 24 * 60; m += 15) timeOf(m)];

List<String> _options(String current) =>
    _times.contains(current) ? _times : ([..._times, current]..sort());

/// Días (L M M J V S D) y horario de entrenamiento.
class WeeklyTimeEditor extends StatelessWidget {
  const WeeklyTimeEditor({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final WeeklyTime value;
  final ValueChanged<WeeklyTime> onChanged;

  @override
  Widget build(BuildContext context) {
    final error = value.isEmpty ? null : value.validate();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 6,
          runSpacing: 4,
          children: [
            for (var day = 1; day <= 7; day++)
              FilterChip(
                label: Text(weekdayShort(day)),
                tooltip: weekdayLong(day),
                selected: value.weekdays.contains(day),
                onSelected: (selected) => onChanged(
                  value.copyWith(
                    weekdays: selected
                        ? {...value.weekdays, day}
                        : ({...value.weekdays}..remove(day)),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<String>(
                key: const Key('time-from'),
                initialValue: value.startsAt,
                decoration: const InputDecoration(labelText: 'Desde'),
                items: [
                  for (final t in _options(value.startsAt))
                    DropdownMenuItem(value: t, child: Text(t)),
                ],
                onChanged: (v) {
                  if (v == null) return;
                  // Mantiene la duración al mover el inicio.
                  final length =
                      (minutesOf(value.endsAt) ?? 0) -
                      (minutesOf(value.startsAt) ?? 0);
                  final end = (minutesOf(v) ?? 0) + (length > 0 ? length : 90);
                  onChanged(
                    value.copyWith(
                      startsAt: v,
                      endsAt: end < 24 * 60 ? timeOf(end) : value.endsAt,
                    ),
                  );
                },
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: DropdownButtonFormField<String>(
                key: ValueKey('time-to-${value.startsAt}-${value.endsAt}'),
                initialValue: value.endsAt,
                decoration: InputDecoration(
                  labelText: 'Hasta',
                  errorText: error == null || value.weekdays.isEmpty
                      ? null
                      : 'Después de "desde"',
                ),
                items: [
                  for (final t in _options(value.endsAt))
                    DropdownMenuItem(value: t, child: Text(t)),
                ],
                onChanged: (v) =>
                    v == null ? null : onChanged(value.copyWith(endsAt: v)),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Diálogo para cambiar el horario de una categoría.
class WeeklyTimeDialog extends StatefulWidget {
  const WeeklyTimeDialog({
    super.key,
    required this.title,
    required this.initial,
    this.allowSameAsAll = false,
  });

  final String title;
  final WeeklyTime initial;

  /// Ofrece "Usar el horario de todas" (devuelve null en `sameAsAll`).
  final bool allowSameAsAll;

  @override
  State<WeeklyTimeDialog> createState() => _WeeklyTimeDialogState();
}

/// Resultado del diálogo: un horario propio o el de todas.
class WeeklyTimeChoice {
  const WeeklyTimeChoice(this.time);

  /// null = el de todas.
  final WeeklyTime? time;
}

class _WeeklyTimeDialogState extends State<WeeklyTimeDialog> {
  late WeeklyTime _value = widget.initial;

  @override
  Widget build(BuildContext context) {
    final error = _value.validate();
    return AlertDialog(
      title: Text(widget.title),
      content: SizedBox(
        width: 400,
        child: WeeklyTimeEditor(
          value: _value,
          onChanged: (v) => setState(() => _value = v),
        ),
      ),
      actions: [
        if (widget.allowSameAsAll)
          TextButton(
            onPressed: () =>
                Navigator.pop(context, const WeeklyTimeChoice(null)),
            child: const Text('Igual que todas'),
          ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: error == null
              ? () => Navigator.pop(context, WeeklyTimeChoice(_value))
              : null,
          child: const Text('Listo'),
        ),
      ],
    );
  }
}
