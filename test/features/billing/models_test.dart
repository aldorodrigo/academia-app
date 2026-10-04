import 'package:academia_app/core/utils/format.dart';
import 'package:academia_app/features/billing/data/models.dart';
import 'package:flutter_test/flutter_test.dart';

import 'account_json.dart';

void main() {
  test('formato de guaraníes', () {
    expect(formatMoney(0), '₲ 0');
    expect(formatMoney(500), '₲ 500');
    expect(formatMoney(150000), '₲ 150.000');
    expect(formatMoney(1250000), '₲ 1.250.000');
    expect(formatMoney(-75000), '−₲ 75.000');
  });

  test('formato de período', () {
    expect(formatPeriod('2026-09'), 'Septiembre 2026');
    expect(formatPeriod('2027-01'), 'Enero 2027');
  });

  test('estados de cargo', () {
    expect(ChargeStatus.parse('vencido'), ChargeStatus.overdue);
    expect(ChargeStatus.parse('otro'), ChargeStatus.pending);
    expect(ChargeStatus.overdue.isUnpaid, isTrue);
    expect(ChargeStatus.paid.isUnpaid, isFalse);
    expect(ChargeStatus.voided.isUnpaid, isFalse);
  });

  test('lee el estado de cuenta con ajustes', () {
    final account = Account.fromJson(accountJson());
    final sofia = account.charges.first;

    expect(account.balance, 270000);
    expect(account.students.map((s) => s.fullName), [
      'Mateo Benítez',
      'Sofía Benítez',
    ]);
    expect(sofia.studentFirstName, 'Sofía');
    expect(sofia.dueOn, DateTime(2026, 9, 10));
    expect(sofia.adjustments.map((a) => a.amount), [-75000, -15000]);
    expect(account.charges.last.period, isNull);
    expect(account.unpaid.map((c) => c.id), [501, 400]);
  });

  test('sin los campos del Sprint 4c, todo es "a pagar ahora"', () {
    final account = Account.fromJson(accountJson());

    expect(account.dueNow, account.balance);
    expect(account.upcoming, 0);
    expect(account.students.first.dueNow, 150000);
    expect(account.charges.first.season, isNull);
    expect(account.charges.first.isUpcoming, isFalse);
    expect(account.upcomingCharges, isEmpty);
    expect(account.dueCharges.map((c) => c.id), [501, 400]);
  });

  test('lee temporada, período, cantidad y cuotas próximas', () {
    final account = Account.fromJson({
      ...accountJson(
        charges: [
          chargeJson(),
          upcomingChargeJson(
            id: 701,
            description: 'Semana 11–17 ene',
            dueOn: '2027-01-14',
          ),
          upcomingChargeJson(),
        ],
      ),
      'due_now': 60000,
      'upcoming': 200000,
    });
    final colonia = account.charges.last;

    expect(account.dueNow, 60000);
    expect(account.upcoming, 200000);
    expect(colonia.season, 'Colonia de verano 2027');
    expect(colonia.periodStart, DateTime(2027, 1, 4));
    expect(colonia.periodEnd, DateTime(2027, 1, 10));
    expect(colonia.quantity, 5);
    expect(colonia.unitAmount, 20000);
    expect(colonia.isUpcoming, isTrue);
    expect(account.dueCharges.map((c) => c.id), [501]);
    expect(account.upcomingCharges.map((c) => c.id), [700, 701]);
  });
}
