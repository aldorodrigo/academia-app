import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/utils/format.dart';
import '../data/booking_controller.dart';
import '../data/models.dart';

/// Hoja inferior para comprar un paquete de clases.
Future<void> showBuyPackSheet(
  BuildContext context, {
  required Teacher teacher,
  required LessonStudent student,
}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  showDragHandle: true,
  builder: (_) => BuyPackSheet(teacher: teacher, student: student),
);

class BuyPackSheet extends ConsumerStatefulWidget {
  const BuyPackSheet({super.key, required this.teacher, required this.student});

  final Teacher teacher;
  final LessonStudent student;

  @override
  ConsumerState<BuyPackSheet> createState() => _BuyPackSheetState();
}

class _BuyPackSheetState extends ConsumerState<BuyPackSheet> {
  late LessonOffer _selected = widget.teacher.packs.first;
  bool _buying = false;
  String? _error;

  Future<void> _buy() async {
    setState(() {
      _buying = true;
      _error = null;
    });
    try {
      final pack = await ref
          .read(studentLessonActionsProvider)
          .buyPack(widget.teacher, _selected, studentId: widget.student.id);
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      Navigator.of(context).pop();
      messenger.showSnackBar(
        SnackBar(content: Text(packPurchasedMessage(pack))),
      );
    } catch (error) {
      setState(() {
        _buying = false;
        _error = apiErrorMessage(error);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final teacher = widget.teacher;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Comprar paquete con ${teacher.firstName}',
              style: theme.textTheme.titleLarge,
            ),
            const SizedBox(height: 4),
            Text(
              'Para ${widget.student.firstName}. La clase suelta sale ${formatMoney(teacher.singlePrice)}.',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            RadioGroup<LessonOffer>(
              groupValue: _selected,
              onChanged: (offer) {
                if (offer != null) setState(() => _selected = offer);
              },
              child: Column(
                children: [
                  for (final offer in teacher.packs)
                    RadioListTile<LessonOffer>(
                      value: offer,
                      contentPadding: EdgeInsets.zero,
                      title: Text(offer.title),
                      subtitle: Text(offer.describe(teacher.singlePrice)),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Se paga por adelantado: pagáselo al profesor o en la secretaría. '
              'Las clases se activan cuando se registra el pago.',
              style: theme.textTheme.bodySmall,
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
            ],
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _buying ? null : _buy,
              child: Text(_buying ? 'Pidiendo…' : 'Pedir paquete'),
            ),
          ],
        ),
      ),
    );
  }
}
