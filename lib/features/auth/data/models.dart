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
    required this.email,
    required this.organizations,
    this.organizationSlug,
  });

  final String name;
  final String email;
  final List<Organization> organizations;
  final String? organizationSlug;

  Organization? get organization {
    for (final organization in organizations) {
      if (organization.slug == organizationSlug) return organization;
    }
    return null;
  }

  Session copyWith({String? organizationSlug}) => Session(
    name: name,
    email: email,
    organizations: organizations,
    organizationSlug: organizationSlug ?? this.organizationSlug,
  );
}
