import '../../../core/utils/format.dart';

/// Rol vigente del usuario en la organización (tutor, cargo de comisión…).
class OrganizationRole {
  const OrganizationRole({
    required this.name,
    required this.label,
    this.startsOn,
    this.endsOn,
  });

  factory OrganizationRole.fromJson(Map<String, dynamic> json) =>
      OrganizationRole(
        name: json['name'] as String,
        label: json['label'] as String,
        startsOn: _date(json['starts_on']),
        endsOn: _date(json['ends_on']),
      );

  final String name;
  final String label;
  final DateTime? startsOn;
  final DateTime? endsOn;

  /// "Tesorero · hasta 31/12/2027" para los cargos con mandato.
  String get description =>
      endsOn == null ? label : '$label · hasta ${formatDate(endsOn!)}';

  static DateTime? _date(Object? value) =>
      value is String ? DateTime.parse(value) : null;
}

/// Configuración de la organización activa (`GET /organization`).
class OrganizationDetails {
  const OrganizationDetails({
    required this.slug,
    required this.name,
    required this.terminology,
    required this.features,
    required this.roles,
    this.permissions = const [],
    this.type,
    this.currency = 'PYG',
    this.timezone = 'America/Asuncion',
  });

  factory OrganizationDetails.fromJson(Map<String, dynamic> json) {
    final membership = json['membership'] as Map<String, dynamic>?;
    return OrganizationDetails(
      slug: json['slug'] as String,
      name: json['name'] as String,
      type: json['type'] as String?,
      currency: json['currency'] as String? ?? 'PYG',
      timezone: json['timezone'] as String? ?? 'America/Asuncion',
      terminology: Map<String, String>.from(
        json['terminology'] as Map? ?? const {},
      ),
      features: List<String>.from(json['features'] as List? ?? const []),
      roles: ((membership?['roles'] as List?) ?? const [])
          .map((r) => OrganizationRole.fromJson(r as Map<String, dynamic>))
          .toList(),
      permissions: List<String>.from(
        membership?['permissions'] as List? ?? const [],
      ),
    );
  }

  static const defaultTerminology = {
    'program': 'Disciplina',
    'group': 'Categoría',
    'student': 'Jugador',
    'instructor': 'Técnico',
    'guardian': 'Tutor',
  };

  final String slug;
  final String name;
  final String? type;
  final String currency;
  final String timezone;
  final Map<String, String> terminology;
  final List<String> features;
  final List<OrganizationRole> roles;

  /// Permisos del usuario para la app (ej. `view_reports`).
  final List<String> permissions;

  /// Etiqueta configurable de la organización (ej. term('group') → "Categoría").
  String term(String key) => terminology[key] ?? defaultTerminology[key] ?? key;

  bool hasFeature(String feature) => features.contains(feature);

  bool hasRole(String name) => roles.any((r) => r.name == name);

  bool can(String permission) => permissions.contains(permission);
}
