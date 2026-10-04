import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/storage/session_storage.dart';
import '../../../core/utils/format.dart';
import 'models.dart';

class ReportsRepository {
  ReportsRepository(this._dio, this._storage);

  final Dio _dio;

  // Mismo contrato que el resto de los repositorios (sesión y organización por el interceptor).
  // ignore: unused_field
  final SessionStorage _storage;

  Future<BalanceReport> balance(DateTime month) async {
    final from = DateTime(month.year, month.month);
    final to = DateTime(month.year, month.month + 1, 0);
    final response = await _dio.get<Map<String, dynamic>>(
      '/reports/balance',
      queryParameters: {'from': apiDate(from), 'to': apiDate(to)},
    );
    return BalanceReport.fromJson(
      response.data!['data'] as Map<String, dynamic>,
    );
  }

  Future<BalancesReport> balances() async {
    final response = await _dio.get<Map<String, dynamic>>('/reports/balances');
    return BalancesReport.fromJson(
      response.data!['data'] as Map<String, dynamic>,
    );
  }

  Future<DelinquentsReport> delinquents({int minMonths = 1}) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/reports/delinquents',
      queryParameters: {'min_months': minMonths},
    );
    return DelinquentsReport.fromJson(
      response.data!['data'] as Map<String, dynamic>,
    );
  }
}

final reportsRepositoryProvider = Provider<ReportsRepository>(
  (ref) => ReportsRepository(
    ref.watch(apiClientProvider),
    ref.watch(sessionStorageProvider),
  ),
);

/// Balance de un mes (se pasa cualquier día del mes).
final balanceReportProvider = FutureProvider.autoDispose
    .family<BalanceReport, DateTime>(
      (ref, month) => ref.watch(reportsRepositoryProvider).balance(month),
      retry: (_, _) => null,
    );

final balancesReportProvider = FutureProvider.autoDispose<BalancesReport>(
  (ref) => ref.watch(reportsRepositoryProvider).balances(),
  retry: (_, _) => null,
);

final delinquentsReportProvider = FutureProvider.autoDispose<DelinquentsReport>(
  (ref) => ref.watch(reportsRepositoryProvider).delinquents(),
  retry: (_, _) => null,
);
