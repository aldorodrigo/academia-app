import 'package:flutter/material.dart';

import '../../../core/utils/format.dart';
import '../data/models.dart';

/// Estado del cargo como etiqueta compacta (entra en el `trailing` del tile).
class ChargeStatusLabel extends StatelessWidget {
  const ChargeStatusLabel(this.status, {super.key});

  final ChargeStatus status;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = switch (status) {
      ChargeStatus.overdue => scheme.error,
      ChargeStatus.pending => scheme.tertiary,
      ChargeStatus.paid => scheme.primary,
      ChargeStatus.voided => scheme.onSurfaceVariant,
    };

    return Text(
      status.label,
      style: Theme.of(context).textTheme.labelMedium?.copyWith(color: color),
    );
  }
}

/// Cargo con su detalle desplegable: monto base, ajustes y monto final.
class ChargeTile extends StatelessWidget {
  const ChargeTile(this.charge, {super.key, this.showStudent = true});

  final Charge charge;

  /// En el consolidado se muestra de qué hijo es; en la ficha del hijo, no.
  final bool showStudent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final subtitle = [
      if (showStudent) charge.studentFirstName,
      charge.isPartiallyPaid
          ? 'Pagado ${formatMoney(charge.paidAmount)} de ${formatMoney(charge.finalAmount)}'
          : 'Vence ${formatDate(charge.dueOn)}',
    ].join(' · ');
    // Lo que falta pagar; si ya está pagado o anulado, el monto del cargo.
    final shownAmount = charge.status.isUnpaid
        ? charge.pendingAmount
        : charge.finalAmount;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        key: PageStorageKey('charge-${charge.id}'),
        title: Text(charge.description),
        subtitle: Text(subtitle),
        trailing: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(formatMoney(shownAmount), style: theme.textTheme.titleSmall),
            ChargeStatusLabel(charge.status),
          ],
        ),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: [
          _Line(charge.concept, charge.baseAmount),
          for (final adjustment in charge.adjustments)
            _Line(adjustment.label, adjustment.amount),
          const Divider(),
          _Line('Total', charge.finalAmount, bold: true),
          if (charge.paidAmount > 0) ...[
            _Line('Pagado', -charge.paidAmount),
            _Line('Falta pagar', charge.pendingAmount, bold: true),
          ],
          _DueLine(charge),
          if (charge.group != null)
            Align(
              alignment: Alignment.centerLeft,
              child: Text(charge.group!, style: theme.textTheme.bodySmall),
            ),
        ],
      ),
    );
  }
}

class _DueLine extends StatelessWidget {
  const _DueLine(this.charge);

  final Charge charge;

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.centerLeft,
    child: Text(
      'Vence ${formatDate(charge.dueOn)}',
      style: Theme.of(context).textTheme.bodySmall,
    ),
  );
}

class _Line extends StatelessWidget {
  const _Line(this.label, this.amount, {this.bold = false});

  final String label;
  final int amount;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    final style = bold
        ? Theme.of(context).textTheme.titleSmall
        : Theme.of(context).textTheme.bodyMedium;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(child: Text(label, style: style)),
          Text(formatMoney(amount), style: style),
        ],
      ),
    );
  }
}
