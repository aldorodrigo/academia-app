import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/storage/session_storage.dart';
import '../../../core/utils/format.dart';
import '../../auth/data/session_controller.dart';
import '../../billing/data/receipt_notice.dart';
import 'models.dart';
import 'report_form.dart';

/// Comprobantes de transferencia: el tutor los informa y quien valida
/// (permiso `review_payment_reports`) los aprueba o rechaza.
class PaymentReportsRepository {
  PaymentReportsRepository(this._dio, this._storage);

  final Dio _dio;
  final SessionStorage _storage;

  /// Informa una transferencia con su comprobante (multipart).
  Future<PaymentReport> report(PaymentReportDraft draft) async {
    final form = FormData.fromMap({
      'amount': draft.amount,
      'paid_on': apiDate(draft.paidOn),
      'charge_ids': draft.chargeIds,
      'money_account_id': ?draft.moneyAccountId,
      if (draft.reference?.trim().isNotEmpty ?? false)
        'reference': draft.reference!.trim(),
      'proof': MultipartFile.fromBytes(
        draft.proof.bytes,
        filename: draft.proof.name,
      ),
    }, ListFormat.multiCompatible);

    final response = await _dio.post<Map<String, dynamic>>(
      '/payment-reports',
      data: form,
    );
    return PaymentReport.fromJson(
      response.data!['data'] as Map<String, dynamic>,
    );
  }

  /// Retira un comprobante propio que todavía está en revisión.
  Future<void> withdraw(int id) => _dio.delete<void>('/payment-reports/$id');

  /// Para quien valida: los que esperan revisión, o los últimos con [all].
  Future<List<PaymentReport>> list({bool all = false}) async {
    if (await _storage.readOrganization() == null) return const [];

    final response = await _dio.get<Map<String, dynamic>>(
      '/payment-reports',
      queryParameters: {'status': all ? 'todos' : 'pendiente'},
    );
    return (response.data!['data'] as List)
        .map((r) => PaymentReport.fromJson(r as Map<String, dynamic>))
        .toList();
  }

  /// Registra el pago con su recibo. Lo que no se manda toma el valor del comprobante.
  /// Aprueba y registra el pago. Si lo había registrado alguien del club,
  /// `notice` dice a quién le llega el recibo (WhatsApp para quien no tiene la
  /// app).
  Future<({PaymentReport report, ReceiptNotice? notice})> approve(
    int id, {
    int? moneyAccountId,
    DateTime? receivedOn,
    int? amount,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/payment-reports/$id/approve',
      data: {
        'money_account_id': ?moneyAccountId,
        if (receivedOn != null) 'received_on': apiDate(receivedOn),
        'amount': ?amount,
      },
    );
    return (
      report: PaymentReport.fromJson(
        response.data!['data'] as Map<String, dynamic>,
      ),
      notice: ReceiptNotice.fromJson(response.data!['notice']),
    );
  }

  Future<PaymentReport> reject(int id, String reason) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/payment-reports/$id/reject',
      data: {'reason': reason.trim()},
    );
    return PaymentReport.fromJson(
      response.data!['data'] as Map<String, dynamic>,
    );
  }
}

final paymentReportsRepositoryProvider = Provider<PaymentReportsRepository>(
  (ref) => PaymentReportsRepository(
    ref.watch(apiClientProvider),
    ref.watch(sessionStorageProvider),
  ),
);

/// Comprobantes para quien valida: `false` = en revisión, `true` = los últimos.
/// Se vuelve a pedir cada vez que cambia la organización elegida.
final paymentReportsProvider = FutureProvider.autoDispose
    .family<List<PaymentReport>, bool>((ref, all) async {
      final slug = await ref.watch(
        sessionControllerProvider.selectAsync((s) => s?.organizationSlug),
      );
      if (slug == null) return const [];
      return ref.watch(paymentReportsRepositoryProvider).list(all: all);
    });
