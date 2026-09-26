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
