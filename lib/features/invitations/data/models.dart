import '../../../core/utils/format.dart';
import '../../auth/data/models.dart';

class Invitation {
  const Invitation({
    required this.token,
    required this.organization,
    this.email,
    this.phone,
    this.name,
    required this.roleLabels,
    required this.userExists,
    this.expiresAt,
  });

  factory Invitation.fromJson(String token, Map<String, dynamic> json) =>
      Invitation(
        token: token,
        organization: Organization.fromJson(
          json['organization'] as Map<String, dynamic>,
        ),
        email: json['email'] as String?,
        phone: json['phone'] as String?,
        name: json['name'] as String?,
        roleLabels: ((json['roles'] as List?) ?? const [])
            .map((r) => (r as Map<String, dynamic>)['label'] as String)
            .toList(),
        userExists: json['user_exists'] as bool? ?? false,
        expiresAt: json['expires_at'] is String
            ? DateTime.parse(json['expires_at'] as String).toLocal()
            : null,
      );

  final String token;
  final Organization organization;

  /// La invitación va a un correo o a un celular (formato internacional).
  final String? email;
  final String? phone;

  /// El nombre que cargó quien invitó (para completar "Nombre y apellido").
  final String? name;
  final List<String> roleLabels;

  /// El celular (formateado) o el correo al que llegó.
  String get contact => phone != null ? formatPhone(phone!) : email ?? '';

  /// Ya hay una cuenta con ese celular o correo: solo se pide la contraseña.
  final bool userExists;
  final DateTime? expiresAt;
}

/// Extrae el código de un link de invitación (`…/invitacion/{código}`)
/// o lo devuelve tal cual si se pegó solo el código.
String? parseInvitationToken(String input) {
  final text = input.trim();
  if (text.isEmpty) return null;

  final segments = Uri.tryParse(text)?.pathSegments ?? const <String>[];
  final index = segments.indexOf('invitacion');
  final candidate = index != -1 && index + 1 < segments.length
      ? segments[index + 1]
      : text;

  return RegExp(r'^[A-Za-z0-9_-]+$').hasMatch(candidate) ? candidate : null;
}
