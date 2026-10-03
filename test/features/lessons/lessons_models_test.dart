import 'package:academia_app/features/lessons/data/booking_controller.dart';
import 'package:academia_app/features/lessons/data/models.dart';
import 'package:flutter_test/flutter_test.dart';

import 'lesson_json.dart';

void main() {
  final today = DateTime(2026, 9, 28);
  final teacher = Teacher.fromJson(teacherJson());

  group('paquete', () {
    test('muestra el rango de validez y el aviso de vencimiento', () {
      final pack = ClassPack.fromJson(packJson());
      expect(pack.remaining, 3);
      expect(pack.available, 2);
      expect(pack.validity, 'válido del 20/9 al 18/11');
      expect(pack.expiryWarning(today), isNull);

      final soon = ClassPack.fromJson(packJson(expiresOn: '2026-10-01'));
      expect(soon.expiryWarning(today), 'Vence en 3 días');
      expect(
        ClassPack.fromJson(packJson(expiresOn: '2026-09-28'))
            .expiryWarning(today),
        'Vence hoy',
      );
    });

    test('pendiente de pago o sin vencimiento', () {
      final pending = ClassPack.fromJson(
        packJson(status: 'pendiente_pago', activatedOn: null, expiresOn: null),
      );
      expect(pending.validity, 'vale 60 días desde que lo pagás');
      final forever = ClassPack.fromJson(packJson(expiresOn: null));
      expect(forever.validity, 'sin vencimiento');
      expect(forever.expiryWarning(today), isNull);
    });

    test('texto de la tarjeta según el estado', () {
      expect(
        describePack(ClassPack.fromJson(packJson()), teacher, today),
        'Paquete: te quedan 3 de 4 · válido del 20/9 al 18/11',
      );
      expect(
        describePack(
          ClassPack.fromJson(
            packJson(
              status: 'vencido',
              used: 3,
              reserved: 0,
              expiresOn: '2026-09-20',
            ),
          ),
          teacher,
          today,
        ),
        'Tu paquete venció el 20/9 (no usaste 1 clase).',
      );
      expect(describePack(null, teacher, today), 'Clase suelta ₲ 35.000');
    });
  });

  group('al reservar', () {
    test('usa el paquete si tiene clases libres y la fecha entra', () {
      final pack = ClassPack.fromJson(packJson());
      final preview = previewBooking(teacher, pack, DateTime(2026, 10, 5));
      expect(preview.usesPack, isTrue);
      expect(
        preview.message,
        'Se descuenta 1 clase del paquete (te quedaría 1).',
      );
    });

    test('después del vencimiento se cobra suelta', () {
      final pack = ClassPack.fromJson(packJson());
      final preview = previewBooking(teacher, pack, DateTime(2026, 11, 19));
      expect(preview.usesPack, isFalse);
      expect(
        preview.message,
        'Tu paquete vence el 18/11; esta clase se cobra suelta. '
        'Se cobra ₲ 35.000 el día de la clase.',
      );
    });

    test('sin clases libres (todas reservadas) se cobra suelta', () {
      final pack = ClassPack.fromJson(packJson(used: 2, reserved: 2));
      expect(
        previewBooking(teacher, pack, DateTime(2026, 10, 5)).usesPack,
        isFalse,
      );
      expect(
        previewBooking(teacher, null, DateTime(2026, 10, 5)).message,
        'Se cobra ₲ 35.000 el día de la clase.',
      );
    });
  });

  group('reserva', () {
    test('lo que falta cobrar de la suelta descuenta el saldo a favor', () {
      final booking = Booking.fromJson(
        bookingJson(payment: 'suelta', credit: 10000),
      );
      expect(booking.amountDue, 25000);
      expect(booking.paymentSummary, 'Suelta · debe ₲ 25.000');

      final prepaid = Booking.fromJson(
        bookingJson(payment: 'suelta', credit: 50000),
      );
      expect(prepaid.amountDue, 0);
      expect(prepaid.paymentSummary, 'Suelta · pagada por adelantado');

      final charged = Booking.fromJson(
        bookingJson(
          payment: 'suelta',
          status: 'asistio',
          charge: {'id': 301, 'amount': 35000, 'pending': 35000},
        ),
      );
      expect(charged.amountDue, 35000);

      final absent = Booking.fromJson(
        bookingJson(payment: 'suelta', status: 'ausente'),
      );
      expect(absent.amountDue, 0);
    });

    test('mensaje al marcar', () {
      expect(
        markedMessage(
          Booking.fromJson(
            bookingJson(
              status: 'asistio',
              pack: packJson(used: 3, reserved: 0),
            ),
          ),
        ),
        'Se descontó 1 clase. Le queda 1 de 4.',
      );
      expect(
        markedMessage(
          Booking.fromJson(
            bookingJson(
              status: 'asistio',
              pack: packJson(used: 4, reserved: 0),
            ),
          ),
        ),
        'Se descontó la última clase del paquete. Ofrecele uno nuevo.',
      );
      expect(
        markedMessage(Booking.fromJson(bookingJson(status: 'ausente'))),
        'Marcado: no vino. No se descontó la clase.',
      );
    });
  });

  group('ajustes del profesor', () {
    test('franjas que se superponen o terminan antes de empezar', () {
      expect(
        validateAvailability(const [
          AvailabilityRange(weekday: 1, startsAt: '15:00', endsAt: '18:00'),
          AvailabilityRange(weekday: 1, startsAt: '17:00', endsAt: '19:00'),
        ]),
        'El lunes hay franjas que se superponen.',
      );
      expect(
        validateAvailability(const [
          AvailabilityRange(weekday: 3, startsAt: '18:00', endsAt: '15:00'),
        ]),
        'El miércoles, una franja termina antes de empezar.',
      );
      expect(
        validateAvailability(const [
          AvailabilityRange(weekday: 1, startsAt: '08:00', endsAt: '10:00'),
          AvailabilityRange(weekday: 1, startsAt: '10:00', endsAt: '12:00'),
        ]),
        isNull,
      );
    });

    test('precios y validez de los paquetes', () {
      const base = LessonProfile(
        enabled: true,
        singlePrice: 35000,
        availability: [
          AvailabilityRange(weekday: 1, startsAt: '15:00', endsAt: '18:00'),
        ],
      );
      expect(base.validate(), isNull);
      expect(
        base.copyWith(singlePrice: 0).validate(),
        'Poné el precio de la clase suelta.',
      );
      expect(
        base
            .copyWith(
              packs: const [
                LessonOffer(classes: 4, price: 100000, validDays: 400),
              ],
            )
            .validate(),
        'La validez de un paquete va de 1 a 365 días.',
      );
      expect(
        base.copyWith(availability: const []).validate(),
        'Cargá al menos una franja de disponibilidad.',
      );
    });

    test('vista previa de las horas que ven los alumnos', () {
      const profile = LessonProfile(
        durationMinutes: 60,
        availability: [
          AvailabilityRange(weekday: 1, startsAt: '15:00', endsAt: '17:30'),
          AvailabilityRange(weekday: 3, startsAt: '18:00', endsAt: '19:00'),
        ],
      );
      expect(profile.preview(), 'lun 15:00, 16:00 · mié 18:00');
    });

    test('paquete: precio por clase, ahorro y validez', () {
      const offer = LessonOffer(classes: 4, price: 100000, validDays: 60);
      expect(offer.unitPrice, 25000);
      expect(offer.savings(35000), 40000);
      expect(
        offer.describe(35000),
        '₲ 25.000 c/u, ahorrás ₲ 40.000 · vale 60 días desde que lo pagás',
      );
      expect(
        const LessonOffer(classes: 4, price: 100000).describe(35000),
        '₲ 25.000 c/u, ahorrás ₲ 40.000 · sin vencimiento',
      );
    });

    test('extender desde el vencimiento o desde hoy si ya venció', () {
      final active = ClassPack.fromJson(packJson(expiresOn: '2026-10-01'));
      expect(extendedExpiry(active, 7, today), DateTime(2026, 10, 8));
      final expired = ClassPack.fromJson(
        packJson(status: 'vencido', expiresOn: '2026-09-20'),
      );
      expect(extendedExpiry(expired, 15, today), DateTime(2026, 10, 13));
    });
  });
}
