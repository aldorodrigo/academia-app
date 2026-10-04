import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/format.dart';
import 'models.dart';

/// Cuotas elegidas al abrir el cobro: las que hay que pagar ahora, salvo las
/// que tienen una transferencia en revisión. Las próximas, sin elegir.
Set<int> initialSelection(CollectionTarget target) => {
  for (final c in target.dueCharges)
    if (!c.underReview) c.id,
};

/// Monto sugerido: lo que salda hoy las cuotas elegidas (con pronto pago).
int suggestedCollectAmount(Iterable<CollectableCharge> charges) =>
    charges.fold(0, (sum, c) => sum + c.settleAmount);

/// Qué pasa con el monto frente a lo elegido: falta (pago parcial) o sobra
/// (saldo a favor). `null` si coincide o no hay monto.
String? collectHint(int? amount, int selected) {
  if (amount == null || amount <= 0) return null;
  if (selected == 0) {
    return 'Se aplica a lo que deba la familia, de lo más viejo a lo más nuevo; '
        'lo que sobre queda a favor.';
  }
  if (amount < selected) {
    return 'Pago parcial: faltan ${formatMoney(selected - amount)} para '
        'saldar lo elegido.';
  }
  if (amount > selected) {
    return 'Sobran ${formatMoney(amount - selected)}: quedan a favor de la familia.';
  }
  return null;
}

String? validateCollectAmount(String? value) {
  final amount = int.tryParse(value?.trim() ?? '');
  if (amount == null) return 'Ingresá el monto que cobraste.';
  if (amount <= 0) return 'El monto tiene que ser mayor a cero.';
  return null;
}

String? validateDepositAmount(String? value, int available) {
  final amount = int.tryParse(value?.trim() ?? '');
  if (amount == null) return 'Ingresá el monto que depositaste.';
  if (amount <= 0) return 'El monto tiene que ser mayor a cero.';
  if (amount > available) {
    return 'Tenés ${formatMoney(available)} para depositar.';
  }
  return null;
}

String? validateDepositAccount(int? accountId) =>
    accountId == null ? 'Elegí dónde lo depositaste.' : null;

String? validateDepositRejection(String? value) =>
    value == null || value.trim().isEmpty
    ? 'Contale por qué no lo confirmás.'
    : null;

/// Identificador de un cobro: si la app lo reintenta (mala señal), la API
/// devuelve el mismo pago en lugar de registrar otro. Se reemplaza en tests.
final collectionRequestIdProvider = Provider<String Function()>((ref) {
  final random = Random.secure();
  return () => List.generate(
    16,
    (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
  ).join();
});
