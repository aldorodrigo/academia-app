import '../../../core/utils/format.dart';
import '../../../core/vocabulary/vocabulary.dart';

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

/// Qué es una organización según su tipo (sin la API a mano, ej. "Tu club" antes de crearla).
String typeNounFor(String? type) => switch (type) {
  'academy' => 'academia',
  'school' => 'escuela',
  'parents_association' => 'comisión',
  _ => 'club',
};

/// Configuración de la organización activa (`GET /organization`).
class OrganizationDetails {
  const OrganizationDetails({
    required this.slug,
    required this.name,
    required this.terminology,
    required this.features,
    required this.roles,
    this.permissions = const [],
    this.collectsToOrgCash = false,
    this.vocabulary = const {},
    this.terminologyFeminine = const {},
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
      collectsToOrgCash: membership?['collects_to_org_cash'] as bool? ?? false,
      vocabulary: {
        for (final entry in (json['vocabulary'] as Map? ?? const {}).entries)
          entry.key as String: Word.fromJson(
            Map<String, dynamic>.from(entry.value as Map),
          ),
      },
      terminologyFeminine: Map<String, String>.from(
        json['terminology_feminine'] as Map? ?? const {},
      ),
    );
  }

  static const defaultTerminology = {
    'program': 'Disciplina',
    'group': 'Categoría',
    'student': 'Jugador',
    'instructor': 'Técnico',
    'guardian': 'Tutor',
    'space': 'Cancha',
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

  /// Lo que cobra en efectivo entra directo a la Caja del club (sin caja
  /// personal ni depósito). Lo decide quien administra los miembros.
  final bool collectsToOrgCash;

  /// Cada palabra con plural, género, artículo y formas de persona (lo decide la API), más `organization`.
  final Map<String, Word> vocabulary;

  /// Formas femeninas que ajustó la organización (`{"instructor": "Entrenadora"}`); vacía = la de la regla.
  final Map<String, String> terminologyFeminine;

  /// Etiqueta configurable de la organización (ej. term('group') → "Categoría").
  String term(String key) => terminology[key] ?? defaultTerminology[key] ?? key;

  /// La palabra para concordar: word('group').the() → "la categoría", word('instructor').forPerson(Gender.female)
  /// → "Técnica". La que manda la API; si no vino, con las reglas locales.
  Word word(String key) {
    final word = vocabulary[key];
    if (key == 'organization') return word ?? Word.of(_typeNoun);
    if (word != null && word.word == term(key)) return word;
    return Word.of(term(key), feminineForm: terminologyFeminine[key]);
  }

  /// Qué es la organización ("club", "academia", "escuela", "comisión"): org.the() → "la academia",
  /// org.of() → "del club".
  Word get org => word('organization');

  /// Qué es, en minúscula: "club", "academia", "escuela", "comisión".
  String get typeNoun => org.word;

  /// "el club", "la academia".
  String get typeWithArticle => org.the();

  String get _typeNoun => typeNounFor(type);

  bool hasFeature(String feature) => features.contains(feature);

  bool hasRole(String name) => roles.any((r) => r.name == name);

  bool can(String permission) => permissions.contains(permission);
}
