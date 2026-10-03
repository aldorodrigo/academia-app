/// Validaciones de formularios compartidas entre pantallas.
String? validateEmail(String? value) {
  if (value == null || value.trim().isEmpty) {
    return 'Ingresá tu correo electrónico.';
  }
  if (!value.contains('@')) return 'El correo electrónico no es válido.';
  return null;
}

String? validateName(String? value) =>
    value == null || value.trim().isEmpty ? 'Ingresá tu nombre.' : null;

String? validateCurrentPassword(String? value) =>
    value == null || value.isEmpty ? 'Ingresá tu contraseña.' : null;

const minPasswordLength = 8;

String? validateNewPassword(String? value) {
  if (value == null || value.isEmpty) return 'Elegí una contraseña.';
  if (value.length < minPasswordLength) {
    return 'La contraseña debe tener al menos $minPasswordLength caracteres.';
  }
  return null;
}

String? validatePasswordConfirmation(String? value, String password) =>
    value == password ? null : 'Las contraseñas no coinciden.';

String? validateTerms(bool accepted) =>
    accepted ? null : 'Tenés que aceptar los términos.';

/// Celular: entre 8 y 15 dígitos, con o sin espacios, guiones o `+`. La API
/// lo normaliza y decide si es un celular válido.
String? validatePhone(String? value) {
  final text = value?.trim() ?? '';
  if (text.isEmpty) return 'Ingresá tu número de celular.';
  if (!RegExp(r'^\+?[\d\s\-()]+$').hasMatch(text)) {
    return 'Ingresá un número de celular válido.';
  }
  final digits = text.replaceAll(RegExp(r'\D'), '');
  if (digits.length < 8 || digits.length > 15) {
    return 'Ingresá un número de celular válido.';
  }
  return null;
}

/// Celular o correo (con `@`), para ingresar o recuperar la contraseña.
String? validateLogin(String? value) {
  final text = value?.trim() ?? '';
  if (text.isEmpty) return 'Ingresá tu celular o tu correo.';
  return text.contains('@') ? validateEmail(text) : validatePhone(text);
}

/// Código de verificación (WhatsApp o correo): 6 dígitos.
String? validateCode(String? value) {
  final code = value?.trim() ?? '';
  if (code.isEmpty) return 'Ingresá el código que te mandamos.';
  if (!RegExp(r'^\d{6}$').hasMatch(code)) return 'El código tiene 6 dígitos.';
  return null;
}
