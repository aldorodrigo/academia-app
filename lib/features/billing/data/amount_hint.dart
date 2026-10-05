import '../../../core/utils/format.dart';

/// Qué pasa con el monto frente a lo que falta de las cuotas elegidas: pago
/// parcial o lo que sobra (saldo a favor). `null` si coincide o no hay monto.
/// Lo usan "Cobrar" y "Informar transferencia".
String? amountHint(
  int? amount,
  int selected, {
  required String noneSelected,
  String surplus = 'quedan a favor',
}) {
  if (amount == null || amount <= 0) return null;
  if (selected == 0) return noneSelected;
  if (amount < selected) {
    return 'Pago parcial: faltan ${formatMoney(selected - amount)} para '
        'saldar lo elegido.';
  }
  if (amount > selected) {
    return 'Sobran ${formatMoney(amount - selected)}: $surplus.';
  }
  return null;
}

/// Monto prellenado: lo sigue mientras quien completa el formulario no lo
/// cambie a mano. Escribir el mismo monto sugerido o borrarlo vuelve a dejarlo
/// automático (y así un eco del campo en la web no lo congela).
bool amountEditedByHand(String text, int suggested) {
  final value = int.tryParse(text.trim());
  return value != null && value != suggested;
}
