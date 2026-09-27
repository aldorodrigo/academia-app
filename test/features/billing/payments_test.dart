import 'package:academia_app/core/api/api_client.dart';
import 'package:academia_app/core/storage/session_storage.dart';
import 'package:academia_app/core/utils/launcher.dart';
import 'package:academia_app/features/billing/data/models.dart';
import 'package:academia_app/features/billing/presentation/account_summary_card.dart';
import 'package:academia_app/features/billing/presentation/balance_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../fakes.dart';
import 'account_json.dart';

Map<String, Object?> _paidAccount() => {
  ...accountJson(balance: 60000, overdue: 0),
  'credit': 90000,
  'charges': [
    {...chargeJson(), 'paid_amount': 20000, 'pending_amount': 40000},
    {
      ...chargeJson(
        id: 400,
        studentId: 12,
        firstName: 'Mateo',
        status: 'pagado',
        description: 'Cuota agosto 2026',
        adjustments: const [],
        total: 150000,
      ),
      'paid_amount': 150000,
      'pending_amount': 0,
    },
  ],
  'payments': [
    paymentJson(),
    paymentJson(id: 80, voided: true, creditGenerated: 0),
  ],
};

Widget _app(Widget home, {List<Uri>? opened}) => ProviderScope(
  overrides: [
    sessionStorageProvider.overrideWithValue(
      InMemorySessionStorage()
        ..token = 't'
        ..organization = 'jakare',
    ),
    apiClientProvider.overrideWithValue(
      fakeDio({
        'GET /me': (_) => {
          'data': {
            'name': 'Ana',
            'email': 'ana@test.com',
            'organizations': [
              {'slug': 'jakare', 'name': 'Club Jakare'},
            ],
          },
        },
        'GET /account': (_) => {'data': _paidAccount()},
      }),
    ),
    urlLauncherProvider.overrideWithValue((uri) async {
      opened?.add(uri);
      return true;
    }),
  ],
  child: MaterialApp(home: home),
);

void main() {
  test('lee pagos, saldo a favor y lo pagado de cada cargo', () {
    final account = Account.fromJson(_paidAccount());

    expect(account.credit, 90000);
    expect(account.payments.first.receiptNumber, '000123');
    expect(account.payments.first.allocations, hasLength(2));
    expect(account.payments.last.voided, isTrue);
    expect(account.charges.first.isPartiallyPaid, isTrue);
    expect(account.charges.first.pendingAmount, 40000);
    expect(account.unpaid.map((c) => c.id), [501]);
  });

  test('sin los campos nuevos sigue funcionando (API del Sprint 3)', () {
    final account = Account.fromJson(accountJson());

    expect(account.credit, 0);
    expect(account.payments, isEmpty);
    expect(account.charges.first.paidAmount, 0);
    expect(account.charges.first.pendingAmount, 60000);
  });

  testWidgets('cargo pagado en parte y saldo a favor', (tester) async {
    await tester.pumpWidget(_app(const BalanceScreen()));
    await tester.pumpAndSettle();

    expect(find.text('Saldo a favor ₲ 90.000'), findsOneWidget);
    expect(find.text('Sofía · Pagado ₲ 20.000 de ₲ 60.000'), findsOneWidget);
    expect(find.text('₲ 40.000'), findsOneWidget);

    await tester.tap(find.text('Cuota septiembre 2026'));
    await tester.pumpAndSettle();
    expect(find.text('Falta pagar'), findsOneWidget);
  });

  testWidgets('pagos con recibo', (tester) async {
    final opened = <Uri>[];
    await tester.pumpWidget(_app(const BalanceScreen(), opened: opened));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Pagos'));
    await tester.pumpAndSettle();

    expect(find.text('Recibo N° 000123'), findsNWidgets(2));
    expect(find.text('20/09/2026 · Transferencia'), findsOneWidget);
    expect(find.text('20/09/2026 · Transferencia · Anulado'), findsOneWidget);
    expect(find.text('Mateo · Cuota agosto 2026'), findsNWidgets(2));
    expect(find.text('Saldo a favor'), findsOneWidget);

    await tester.tap(find.text('Ver recibo').first);
    expect(
      opened.single.toString(),
      'https://api.test/recibos/90?signature=abc',
    );
  });

  testWidgets('el inicio muestra el saldo a favor', (tester) async {
    await tester.pumpWidget(_app(const Scaffold(body: AccountSummaryCard())));
    await tester.pumpAndSettle();

    expect(find.text('Total a pagar ₲ 60.000'), findsOneWidget);
    expect(find.text('Saldo a favor ₲ 90.000'), findsOneWidget);
  });
}
