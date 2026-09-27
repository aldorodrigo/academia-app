import 'package:academia_app/core/push/class_notifications.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fakes.dart';

const _going =
    'https://api.test/api/v1/class-responses/81/5?students=12&going=1&signature=a';
const _notGoing =
    'https://api.test/api/v1/class-responses/81/5?students=12&going=0&signature=b';

void main() {
  test('solo los push de clases llevan botones', () {
    expect(ActionablePush.fromData({'type': 'class_suspended'}), isNull);

    final push = ActionablePush.fromData({
      'type': 'class_reminder',
      'title': 'Día de clase',
      'body': 'Hoy Mateo tiene Fútbol a las 17:00. ¿Lo llevás?',
      'route': '/inicio',
      'class_id': '81',
      'going_url': _going,
      'not_going_url': _notGoing,
    })!;
    expect(push.canRespond, isTrue);
    expect(push.notificationId, 81);

    final today = ActionablePush.fromData({
      'type': 'class_today',
      'body': 'Hoy tenés clase con Sub-10',
      'route': '/clases/81',
    })!;
    expect(today.canRespond, isFalse);
    expect(today.route, '/clases/81');
  });

  test('cada botón sabe qué hacer', () {
    final push = ActionablePush(
      type: ActionablePush.reminder,
      title: 't',
      body: 'b',
      route: '/inicio',
      goingUrl: _going,
      notGoingUrl: _notGoing,
    );

    final going = NotificationTap.from('going', push.payload);
    expect((going as RespondTap).url, _going);
    final notGoing = NotificationTap.from('not_going', push.payload);
    expect((notGoing as RespondTap).url, _notGoing);
    final body = NotificationTap.from(null, push.payload);
    expect((body as OpenTap).route, '/inicio');
    expect(NotificationTap.from(null, null), isNull);
  });

  group('responder por el link firmado', () {
    // Con postUri, la ruta es el link completo (con la firma).
    Dio dio(Object? Function(RequestOptions) route) =>
        fakeDio({'POST $_going': route, 'POST $_notGoing': route});

    test('ok: muestra el mensaje de la API', () async {
      expect(
        await respondFromNotification(
          dio(
            (_) => {
              'data': {'message': 'Listo: avisaste que Mateo no va.'},
            },
          ),
          _notGoing,
        ),
        'Listo: avisaste que Mateo no va.',
      );
    });

    test('vencido o alterado', () async {
      expect(
        await respondFromNotification(
          dio((o) => throw apiError(o, 403, {'message': 'Invalid signature.'})),
          _going,
        ),
        'Este aviso venció. Abrí la app para responder.',
      );
    });

    test('la clase ya empezó', () async {
      expect(
        await respondFromNotification(
          dio(
            (o) => throw apiError(o, 422, {'message': 'La clase ya empezó.'}),
          ),
          _going,
        ),
        'La clase ya empezó.',
      );
    });

    test('sin conexión', () async {
      expect(
        await respondFromNotification(
          dio((o) => throw networkError(o)),
          _going,
        ),
        'No se pudo enviar. Abrí la app para responder.',
      );
    });
  });
}
