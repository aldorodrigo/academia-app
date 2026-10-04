import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../billing/data/models.dart';

/// Archivo del comprobante elegido por el tutor (foto o PDF).
class PickedProof {
  const PickedProof({required this.name, required this.bytes});

  final String name;
  final Uint8List bytes;
}

/// Formatos que acepta la API para el comprobante.
const proofExtensions = ['jpg', 'jpeg', 'png', 'webp', 'heic', 'pdf'];

/// Tamaño máximo del comprobante (5 MB, igual que la API).
const maxProofBytes = 5 * 1024 * 1024;

/// Abre el selector de archivos del sistema. Se reemplaza en los tests.
final proofPickerProvider = Provider<Future<PickedProof?> Function()>(
  (ref) => () async {
    final file = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: proofExtensions,
    );
    if (file == null) return null;
    return PickedProof(name: file.name, bytes: await file.xFile.readAsBytes());
  },
);

/// Lo que el tutor completa para informar una transferencia.
class PaymentReportDraft {
  const PaymentReportDraft({
    required this.amount,
    required this.paidOn,
    required this.proof,
    this.chargeIds = const [],
    this.moneyAccountId,
    this.reference,
  });

  final int amount;
  final DateTime paidOn;
  final PickedProof proof;
  final List<int> chargeIds;
  final int? moneyAccountId;
  final String? reference;
}

String? validateReportAmount(String? value) {
  final amount = int.tryParse(value?.trim() ?? '');
  if (amount == null) return 'Ingresá el monto que transferiste.';
  if (amount <= 0) return 'El monto tiene que ser mayor a cero.';
  return null;
}

String? validateProof(PickedProof? proof) {
  if (proof == null) return 'Adjuntá el comprobante de la transferencia.';
  final extension = proof.name.split('.').last.toLowerCase();
  if (!proof.name.contains('.') || !proofExtensions.contains(extension)) {
    return 'El comprobante tiene que ser una foto o un PDF.';
  }
  if (proof.bytes.length > maxProofBytes) {
    return 'El comprobante pesa más de 5 MB.';
  }
  return null;
}

String? validateRejectionReason(String? value) =>
    value == null || value.trim().isEmpty
    ? 'Contale al tutor por qué no lo aprobás.'
    : null;

/// Cuotas que se pueden informar: impagas y que no estén en otro comprobante
/// en revisión. Primero lo que hay que pagar ahora (de la más vieja a la más
/// nueva), después las próximas.
List<Charge> reportableCharges(Account account) {
  final underReview = account.chargesUnderReview;
  return [
    ...account.dueCharges..sort((a, b) => a.dueOn.compareTo(b.dueOn)),
    ...account.upcomingCharges,
  ].where((c) => !underReview.contains(c.id)).toList();
}

/// Monto sugerido: lo que falta pagar de las cuotas elegidas.
int suggestedAmount(Iterable<Charge> charges) =>
    charges.fold(0, (sum, c) => sum + c.pendingAmount);
