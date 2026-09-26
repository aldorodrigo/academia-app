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

  test('formatea fechas como dd/mm/aaaa', () {
    expect(formatDate(DateTime(2027, 3, 5)), '05/03/2027');
  });
}
