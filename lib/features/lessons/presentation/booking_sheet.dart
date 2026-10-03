import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/utils/clock.dart';
import '../../../core/utils/format.dart';
import '../data/booking_controller.dart';
import '../data/models.dart';

/// Días después de la clase en que el profesor todavía puede marcarla (como en la API).
const markableDays = 3;

/// El profesor puede marcar Vino / No vino desde el día de la clase hasta 3 días después.
bool canMark(Booking booking, DateTime today) {
  if (booking.status.isCancelled) return false;
  final diff = today.difference(booking.date).inDays;
  return diff >= 0 && diff <= markableDays;
}

/// Ficha rápida de una reserva para el profesor: Vino / No vino, Cobrar y Cancelar.
Future<void> showBookingSheet(BuildContext context, Booking booking) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => BookingSheet(booking: booking),
    );

class BookingSheet extends ConsumerStatefulWidget {
  const BookingSheet({super.key, required this.booking});

  final Booking booking;

  @override
  ConsumerState<BookingSheet> createState() => _BookingSheetState();
}

class _BookingSheetState extends ConsumerState<BookingSheet> {
  late Booking _booking = widget.booking;
  bool _busy = false;
  String? _message;
  String? _error;

  Future<void> _run(Future<void> Function() action) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
    } catch (error) {
      _error = apiErrorMessage(error);
    }
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _mark(bool attended) => _run(() async {
    final marked = await ref
        .read(teacherLessonActionsProvider)
        .mark(_booking, attended: attended);
    _booking = marked;
    _message = markedMessage(marked);
  });

  Future<void> _collect() async {
    final result = await showCollectSheet(
      context,
      student: _booking.student,
      amount: _booking.amountDue,
      bookingId: _booking.id,
    );
    if (result == null || !mounted) return;
    setState(() {
      if (result.booking != null) _booking = result.booking!;
      _message = result.message;
    });
  }

  Future<void> _cancel() async {
    final reason = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('¿Cancelar la clase?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Le avisamos a ${_booking.student.firstName}.'),
            const SizedBox(height: 8),
            TextField(
              controller: reason,
              decoration: const InputDecoration(labelText: 'Motivo (opcional)'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Volver'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Cancelar clase'),
          ),
        ],
      ),
    );
    final text = reason.text;
    reason.dispose();
    if (confirmed != true || !mounted) return;
    await _run(() async {
      _booking = await ref
          .read(teacherLessonActionsProvider)
          .cancel(_booking, reason: text);
      _message = 'Clase cancelada. Le avisamos al alumno.';
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final today = ref.watch(todayProvider);
    final now = ref.watch(nowProvider);
    final booking = _booking;
    final markable = canMark(booking, today);
    final started = !now.isBefore(booking.startsAtDateTime);
    final due = booking.amountDue;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(booking.student.fullName, style: theme.textTheme.titleLarge),
            Text(booking.describe(today)),
            Text(booking.paymentSummary, style: theme.textTheme.bodySmall),
            if (booking.status.isCancelled)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(booking.status.label),
              ),
            const SizedBox(height: 16),
            if (markable)
              Row(
                children: [
                  Expanded(
                    child: _BigButton(
                      label: 'Vino',
                      icon: Icons.check_circle_outline,
                      selected: booking.status == BookingStatus.attended,
                      onPressed: _busy ? null : () => _mark(true),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _BigButton(
                      label: 'No vino',
                      icon: Icons.cancel_outlined,
                      selected: booking.status == BookingStatus.absent,
                      onPressed: _busy ? null : () => _mark(false),
                    ),
                  ),
                ],
              )
            else if (booking.status == BookingStatus.confirmed)
              Text(
                'Vas a poder marcar si vino el día de la clase.',
                style: theme.textTheme.bodySmall,
              ),
            if (_message != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(_message!, style: theme.textTheme.bodyLarge),
              ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                  _error!,
                  style: TextStyle(color: theme.colorScheme.error),
                ),
              ),
            if (due > 0 &&
                (booking.status == BookingStatus.confirmed ||
                    booking.status == BookingStatus.attended)) ...[
              const SizedBox(height: 12),
              FilledButton.tonalIcon(
                icon: const Icon(Icons.payments_outlined),
                label: Text('Cobrar ${formatMoney(due)}'),
                onPressed: _busy ? null : _collect,
              ),
            ],
            if (booking.status == BookingStatus.confirmed && !started)
              TextButton(
                onPressed: _busy ? null : _cancel,
                child: const Text('Cancelar clase'),
              ),
          ],
        ),
      ),
    );
  }
}

class _BigButton extends StatelessWidget {
  const _BigButton({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final style = ButtonStyle(
      minimumSize: const WidgetStatePropertyAll(Size.fromHeight(64)),
      textStyle: WidgetStatePropertyAll(
        Theme.of(context).textTheme.titleMedium,
      ),
    );
    return selected
        ? FilledButton.icon(
            style: style,
            icon: Icon(icon),
            label: Text(label),
            onPressed: onPressed,
          )
        : OutlinedButton.icon(
            style: style,
            icon: Icon(icon),
            label: Text(label),
            onPressed: onPressed,
          );
  }
}

/// Hoja para cobrar: monto (editable) y forma de pago. Devuelve el resultado o null.
Future<PaymentResult?> showCollectSheet(
  BuildContext context, {
  required LessonStudent student,
  required int amount,
  int? bookingId,
  int? classPackId,
}) => showModalBottomSheet<PaymentResult>(
  context: context,
  isScrollControlled: true,
  showDragHandle: true,
  builder: (_) => CollectSheet(
    student: student,
    amount: amount,
    bookingId: bookingId,
    classPackId: classPackId,
  ),
);

/// "35.000" o "35000" → 35000 (null si no es un monto válido).
int? parseAmount(String text) {
  final digits = text.replaceAll(RegExp(r'[.\s₲]'), '');
  final value = int.tryParse(digits);
  return value == null || value <= 0 ? null : value;
}

class CollectSheet extends ConsumerStatefulWidget {
  const CollectSheet({
    super.key,
    required this.student,
    required this.amount,
    this.bookingId,
    this.classPackId,
  });

  final LessonStudent student;
  final int amount;
  final int? bookingId;
  final int? classPackId;

  @override
  ConsumerState<CollectSheet> createState() => _CollectSheetState();
}

class _CollectSheetState extends ConsumerState<CollectSheet> {
  late final _amount = TextEditingController(
    text: widget.amount > 0 ? widget.amount.toString() : '',
  );
  PaymentMethod _method = PaymentMethod.cash;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final amount = parseAmount(_amount.text);
    if (amount == null) {
      setState(() => _error = 'Poné un monto mayor a 0.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final result = await ref
          .read(teacherLessonActionsProvider)
          .collect(
            studentId: widget.student.id,
            amount: amount,
            method: _method,
            bookingId: widget.bookingId,
            classPackId: widget.classPackId,
          );
      if (mounted) Navigator.of(context).pop(result);
    } catch (error) {
      setState(() {
        _saving = false;
        _error = apiErrorMessage(error);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(
        24,
        0,
        24,
        24 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Cobrar a ${widget.student.firstName}',
            style: theme.textTheme.titleLarge,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _amount,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: const InputDecoration(
              labelText: 'Monto',
              prefixText: '₲ ',
            ),
          ),
          const SizedBox(height: 16),
          SegmentedButton<PaymentMethod>(
            segments: [
              for (final method in PaymentMethod.values)
                ButtonSegment(value: method, label: Text(method.label)),
            ],
            selected: {_method},
            onSelectionChanged: (s) => setState(() => _method = s.first),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                _error!,
                style: TextStyle(color: theme.colorScheme.error),
              ),
            ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _saving ? null : _save,
            child: Text(_saving ? 'Cobrando…' : 'Registrar cobro'),
          ),
        ],
      ),
    );
  }
}
