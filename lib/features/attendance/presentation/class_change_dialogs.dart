import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/utils/clock.dart';
import '../../../core/utils/format.dart';
import '../data/attendance_repository.dart';
import '../data/models.dart';

/// Lo que se eligió al suspender una clase.
class SuspendChoice {
  const SuspendChoice({
    required this.reason,
    this.reschedule = false,
    this.waiveCharge = false,
  });

  final String reason;

  /// Se recupera otro día u horario (si no, se cancela).
  final bool reschedule;

  /// "No cobrar esta clase" (solo al cancelar, en temporadas por día de entrenamiento).
  final bool waiveCharge;
}

/// Motivo y qué pasa con la clase: se cancela o se reprograma.
class SuspendDialog extends StatefulWidget {
  const SuspendDialog({super.key, required this.canWaiveCharge});

  final bool canWaiveCharge;

  @override
  State<SuspendDialog> createState() => _SuspendDialogState();
}

class _SuspendDialogState extends State<SuspendDialog> {
  static const _reasons = ['Lluvia', 'Cancha ocupada', 'Otro'];

  String _reason = _reasons.first;
  bool _reschedule = false;
  bool _waiveCharge = true;
  final _other = TextEditingController();

  @override
  void dispose() {
    _other.dispose();
    super.dispose();
  }

  String? get _value {
    if (_reason != 'Otro') return _reason;
    final other = _other.text.trim();
    return other.isEmpty ? null : other;
  }

  @override
  Widget build(BuildContext context) {
    final value = _value;
    return AlertDialog(
      title: const Text('Suspender clase'),
      scrollable: true,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            children: [
              for (final reason in _reasons)
                ChoiceChip(
                  label: Text(reason),
                  selected: _reason == reason,
                  onSelected: (_) => setState(() => _reason = reason),
                ),
            ],
          ),
          if (_reason == 'Otro') ...[
            const SizedBox(height: 12),
            TextField(
              controller: _other,
              autofocus: true,
              decoration: const InputDecoration(labelText: 'Motivo'),
              onChanged: (_) => setState(() {}),
            ),
          ],
          const SizedBox(height: 12),
          RadioGroup<bool>(
            groupValue: _reschedule,
            onChanged: (value) => setState(() => _reschedule = value!),
            child: const Column(
              children: [
                RadioListTile<bool>(
                  contentPadding: EdgeInsets.zero,
                  value: false,
                  title: Text('Cancelar la clase'),
                  subtitle: Text('No se recupera.'),
                ),
                RadioListTile<bool>(
                  contentPadding: EdgeInsets.zero,
                  value: true,
                  title: Text('Reprogramar'),
                  subtitle: Text('Se recupera otro día u horario.'),
                ),
              ],
            ),
          ),
          if (widget.canWaiveCharge && !_reschedule)
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: _waiveCharge,
              onChanged: (value) => setState(() => _waiveCharge = value!),
              title: const Text('No cobrar esta clase'),
              subtitle: const Text('Se descuenta de la cuota por día.'),
            ),
          const SizedBox(height: 8),
          const Text('Se avisa a los tutores del grupo.'),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Volver'),
        ),
        FilledButton(
          onPressed: value == null
              ? null
              : () => Navigator.pop(
                  context,
                  SuspendChoice(
                    reason: value,
                    reschedule: _reschedule,
                    waiveCharge:
                        widget.canWaiveCharge && !_reschedule && _waiveCharge,
                  ),
                ),
          child: Text(_reschedule ? 'Elegir día y hora' : 'Suspender'),
        ),
      ],
    );
  }
}

/// "09:00" ↔ TimeOfDay.
String formatTime(TimeOfDay time) =>
    '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';

TimeOfDay parseTime(String value) {
  final parts = value.split(':');
  return TimeOfDay(
    hour: int.tryParse(parts.first) ?? 0,
    minute: parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0,
  );
}

int _minutes(TimeOfDay time) => time.hour * 60 + time.minute;

/// Error del nuevo día y horario, o null si se puede reprogramar.
String? validateReschedule({
  required DateTime date,
  required TimeOfDay startsAt,
  required TimeOfDay endsAt,
  required DateTime now,
}) {
  if (_minutes(endsAt) <= _minutes(startsAt)) {
    return 'La hora de fin tiene que ser después del inicio.';
  }
  final start = DateTime(
    date.year,
    date.month,
    date.day,
    startsAt.hour,
    startsAt.minute,
  );
  if (!start.isAfter(now)) return 'Elegí un día y hora que todavía no pasó.';
  return null;
}

/// Nuevo día, horario y cancha de la clase.
class RescheduleSheet extends ConsumerStatefulWidget {
  const RescheduleSheet({super.key, required this.session, this.reason});

  final ClassSession session;
  final String? reason;

  @override
  ConsumerState<RescheduleSheet> createState() => _RescheduleSheetState();
}

class _RescheduleSheetState extends ConsumerState<RescheduleSheet> {
  late DateTime _date;
  late TimeOfDay _startsAt;
  late TimeOfDay _endsAt;
  int? _venueId;
  bool _venueTouched = false;

  @override
  void initState() {
    super.initState();
    final today = ref.read(todayProvider);
    final session = widget.session;
    // Por defecto: mismo horario, al día siguiente de la clase (o de hoy si ya pasó).
    final base = session.date.isBefore(today) ? today : session.date;
    _date = DateTime(base.year, base.month, base.day + 1);
    _startsAt = parseTime(session.startsAt);
    _endsAt = session.endsAt.isEmpty
        ? TimeOfDay(hour: (_startsAt.hour + 1) % 24, minute: _startsAt.minute)
        : parseTime(session.endsAt);
  }

  Future<void> _pickDate() async {
    final today = ref.read(todayProvider);
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: today,
      lastDate: today.add(const Duration(days: 120)),
      helpText: 'Nuevo día',
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _pickTime({required bool start}) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: start ? _startsAt : _endsAt,
      helpText: start ? 'Empieza' : 'Termina',
    );
    if (picked == null) return;
    setState(() {
      if (start) {
        // Mantiene la duración al mover el inicio.
        final duration = _minutes(_endsAt) - _minutes(_startsAt);
        _startsAt = picked;
        final end = (_minutes(picked) + duration).clamp(0, 23 * 60 + 59);
        _endsAt = TimeOfDay(hour: end ~/ 60, minute: end % 60);
      } else {
        _endsAt = picked;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final today = ref.watch(todayProvider);
    final now = ref.watch(nowProvider);
    final venues = ref.watch(venuesProvider);
    final error = validateReschedule(
      date: _date,
      startsAt: _startsAt,
      endsAt: _endsAt,
      now: now,
    );

    final venueList = venues.value ?? const <Venue>[];
    if (!_venueTouched && _venueId == null) {
      for (final venue in venueList) {
        if (venue.name == widget.session.venue) _venueId = venue.id;
      }
    }

    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        0,
        16,
        16 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Reprogramar clase', style: theme.textTheme.titleMedium),
          Text(
            '${widget.session.group.name} · era '
            '${formatShortDay(widget.session.date, today).toLowerCase()} '
            '${widget.session.startsAt}',
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: 8),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.event),
            title: const Text('Día'),
            trailing: Text(formatShortDay(_date, today)),
            onTap: _pickDate,
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.schedule),
            title: const Text('Empieza'),
            trailing: Text(formatTime(_startsAt)),
            onTap: () => _pickTime(start: true),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.schedule_outlined),
            title: const Text('Termina'),
            trailing: Text(formatTime(_endsAt)),
            onTap: () => _pickTime(start: false),
          ),
          if (venues.hasError)
            Text(apiErrorMessage(venues.error!))
          else if (venueList.isNotEmpty)
            DropdownButtonFormField<int?>(
              initialValue: _venueId,
              decoration: const InputDecoration(labelText: 'Cancha'),
              items: [
                for (final venue in venueList)
                  DropdownMenuItem(value: venue.id, child: Text(venue.name)),
              ],
              onChanged: (value) => setState(() {
                _venueTouched = true;
                _venueId = value;
              }),
            ),
          if (error != null) ...[
            const SizedBox(height: 8),
            Text(error, style: TextStyle(color: theme.colorScheme.error)),
          ],
          const SizedBox(height: 16),
          const Text('Se avisa a los tutores del grupo.'),
          const SizedBox(height: 8),
          FilledButton(
            onPressed: error != null
                ? null
                : () => Navigator.pop(
                    context,
                    RescheduleRequest(
                      date: _date,
                      startsAt: formatTime(_startsAt),
                      endsAt: formatTime(_endsAt),
                      venueId: _venueId,
                      reason: widget.reason,
                    ),
                  ),
            child: const Text('Reprogramar'),
          ),
        ],
      ),
    );
  }
}
