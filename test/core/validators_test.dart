import 'package:academia_app/core/utils/format.dart';
import 'package:academia_app/core/utils/validators.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('contraseña nueva: obligatoria y de al menos 8 caracteres', () {
    expect(validateNewPassword(''), 'Elegí una contraseña.');
    expect(
      validateNewPassword('1234567'),
      'La contraseña debe tener al menos 8 caracteres.',
    );
    expect(validateNewPassword('12345678'), isNull);
  });

  test('la confirmación tiene que coincidir', () {
    expect(
      validatePasswordConfirmation('otra', 'secreta1'),
      'Las contraseñas no coinciden.',
    );
    expect(validatePasswordConfirmation('secreta1', 'secreta1'), isNull);
  });

  test('nombre y correo', () {
    expect(validateName('  '), 'Ingresá tu nombre.');
    expect(validateName('Ana'), isNull);
    expect(validateEmail('ana'), 'El correo electrónico no es válido.');
    expect(validateEmail('ana@test.com'), isNull);
  });

  test('celular', () {
    expect(validatePhone(''), 'Ingresá tu número de celular.');
    expect(validatePhone('0981 123'), 'Ingresá un número de celular válido.');
    expect(validatePhone('0981abc456'), 'Ingresá un número de celular válido.');
    expect(validatePhone('0981 123 456'), isNull);
    expect(validatePhone('+595 981-123456'), isNull);
  });

  test('celular o correo para ingresar', () {
    expect(validateLogin(' '), 'Ingresá tu celular o tu correo.');
    expect(validateLogin('0981123456'), isNull);
    expect(validateLogin('ana@test.com'), isNull);
    expect(validateLogin('ana@'), isNull);
    expect(validateLogin('ana'), 'Ingresá un número de celular válido.');
  });

  test('formatea celulares de Paraguay', () {
    expect(formatPhone('+595981123456'), '0981 123 456');
    expect(formatPhone('+5491112345678'), '+5491112345678');
  });

  test('formatea fechas como dd/mm/aaaa', () {
    expect(formatDate(DateTime(2027, 3, 5)), '05/03/2027');
  });
}
