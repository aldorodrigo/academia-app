import '../../../core/utils/format.dart';

class Organization {
  const Organization({required this.slug, required this.name, this.type});

  factory Organization.fromJson(Map<String, dynamic> json) => Organization(
    slug: json['slug'] as String,
    name: json['name'] as String,
    type: json['type'] as String?,
  );

  final String slug;
  final String name;
  final String? type;
}

class Session {
  const Session({
    required this.name,
    required this.organizations,
    this.phone,
    this.email,
    this.organizationSlug,
    this.verified = true,
  });

  final String name;

  /// Celular en formato internacional (`+595981123456`), si la cuenta lo tiene.
  final String? phone;
  final String? email;
  final List<Organization> organizations;
  final String? organizationSlug;

  /// Cuenta recién creada que todavía no ingresó el código.
  final bool verified;

  /// Cómo se identifica la cuenta: el celular (formateado) o el correo.
  String get contact => phone != null ? formatPhone(phone!) : email ?? '';

  Organization? get organization {
    for (final organization in organizations) {
      if (organization.slug == organizationSlug) return organization;
    }
    return null;
  }

  Session copyWith({String? organizationSlug}) => Session(
    name: name,
    phone: phone,
    email: email,
    organizations: organizations,
    organizationSlug: organizationSlug ?? this.organizationSlug,
    verified: verified,
  );
}
