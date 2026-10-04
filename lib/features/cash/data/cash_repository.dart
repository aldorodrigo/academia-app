import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/storage/session_storage.dart';
import '../../../core/utils/format.dart';
import '../../auth/data/session_controller.dart';
import 'models.dart';

/// Cobro en efectivo desde la app (permiso `collect_payments`), la caja de quien
/// cobra y la confirmación de sus depósitos (permiso `review_payment_reports`).
class CashRepository {
  CashRepository(this._dio, this._storage);

  final Dio _dio;
  final SessionStorage _storage;

  /// Alumnos que puede cobrar quien usa la app.
  Future<List<CollectableStudent>> students({String? search}) async {
    if (await _storage.readOrganization() == null) return const [];

    final response = await _dio.get<Map<String, dynamic>>(
      '/collections/students',
      queryParameters: {
        if (search != null && search.trim().isNotEmpty) 'search': search.trim(),
      },
    );
    return (response.data!['data'] as List)
        .map((s) => CollectableStudent.fromJson(s as Map<String, dynamic>))
        .toList();
  }

  /// Familia y cuotas pendientes de un alumno, para cobrarle.
  Future<CollectionTarget> target(int studentId) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/collections/students/$studentId',
    );
    return CollectionTarget.fromJson(
      response.data!['data'] as Map<String, dynamic>,
    );
  }

  /// Registra el cobro en efectivo; entra en la caja de quien cobra.
  Future<CollectionResult> collect(CollectionDraft draft) async {
    final notes = draft.notes?.trim();
    final response = await _dio.post<Map<String, dynamic>>(
      '/collections',
      data: {
        'student_id': draft.studentId,
        'amount': draft.amount,
        'charge_ids': draft.chargeIds,
        'guardian_id': ?draft.guardianId,
        if (notes != null && notes.isNotEmpty) 'notes': notes,
        'request_id': draft.requestId,
      },
    );
    return CollectionResult.fromJson(
      response.data!['data'] as Map<String, dynamic>,
    );
  }

  /// "Mi caja": saldo, movimientos y depósitos.
  Future<CashBox> cashBox() async {
    if (await _storage.readOrganization() == null) return CashBox.empty;

    final response = await _dio.get<Map<String, dynamic>>('/me/cash-box');
    return CashBox.fromJson(response.data!['data'] as Map<String, dynamic>);
  }

  /// Informa un depósito; queda por confirmar.
  Future<CashDeposit> deposit(DepositDraft draft) async {
    final reference = draft.reference?.trim();
    final notes = draft.notes?.trim();
    final response = await _dio.post<Map<String, dynamic>>(
      '/me/cash-box/deposits',
      data: {
        'amount': draft.amount,
        'money_account_id': draft.moneyAccountId,
        'deposited_on': apiDate(draft.depositedOn),
        if (reference != null && reference.isNotEmpty) 'reference': reference,
        if (notes != null && notes.isNotEmpty) 'notes': notes,
      },
    );
    return CashDeposit.fromJson(response.data!['data'] as Map<String, dynamic>);
  }

  /// Retira un depósito propio que todavía no se confirmó.
  Future<void> withdrawDeposit(int id) =>
      _dio.delete<void>('/me/cash-box/deposits/$id');

  /// Para quien valida: cajas de los técnicos y depósitos por confirmar.
  Future<CashOverview> overview() async {
    if (await _storage.readOrganization() == null) return const CashOverview();

    final response = await _dio.get<Map<String, dynamic>>('/cash-boxes');
    return CashOverview.fromJson(
      response.data!['data'] as Map<String, dynamic>,
    );
  }

  Future<CashDeposit> confirmDeposit(int id) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/cash-deposits/$id/confirm',
    );
    return CashDeposit.fromJson(response.data!['data'] as Map<String, dynamic>);
  }

  Future<CashDeposit> rejectDeposit(int id, String reason) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/cash-deposits/$id/reject',
      data: {'reason': reason.trim()},
    );
    return CashDeposit.fromJson(response.data!['data'] as Map<String, dynamic>);
  }
}

final cashRepositoryProvider = Provider<CashRepository>(
  (ref) => CashRepository(
    ref.watch(apiClientProvider),
    ref.watch(sessionStorageProvider),
  ),
);

/// Espera la organización elegida y vuelve a pedir si cambia.
Future<bool> _hasOrganization(Ref ref) async =>
    await ref.watch(
      sessionControllerProvider.selectAsync((s) => s?.organizationSlug),
    ) !=
    null;

final collectableStudentsProvider =
    FutureProvider.autoDispose<List<CollectableStudent>>((ref) async {
      if (!await _hasOrganization(ref)) return const [];
      return ref.watch(cashRepositoryProvider).students();
    });

/// Sin reintentos: un 404 (alumno fuera de su alcance) no se arregla reintentando.
final collectionTargetProvider = FutureProvider.autoDispose
    .family<CollectionTarget, int>(
      (ref, id) => ref.watch(cashRepositoryProvider).target(id),
      retry: (_, _) => null,
    );

final cashBoxProvider = FutureProvider.autoDispose<CashBox>((ref) async {
  if (!await _hasOrganization(ref)) return CashBox.empty;
  return ref.watch(cashRepositoryProvider).cashBox();
});

final cashOverviewProvider = FutureProvider.autoDispose<CashOverview>((
  ref,
) async {
  if (!await _hasOrganization(ref)) return const CashOverview();
  return ref.watch(cashRepositoryProvider).overview();
});
