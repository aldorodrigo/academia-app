import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../auth/data/session_controller.dart';
import '../../inbox/data/inbox_repository.dart';
import '../../onboarding/data/onboarding_controller.dart';
import '../../organizations/data/organization_repository.dart';
import '../../organizations/presentation/roles_list.dart';
import '../../../core/vocabulary/gender_choice.dart';
import '../../../core/api/api_client.dart';

class AccountScreen extends ConsumerWidget {
  const AccountScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionControllerProvider).value;
    final theme = Theme.of(context);
    final organization = ref.watch(currentOrganizationProvider).value;
    final onboarding = ref.watch(onboardingProvider).value;
    final unread = ref.watch(unreadNotificationsProvider);
    final teaches =
        (organization?.hasFeature('private_lessons') ?? false) &&
        (organization!.can('teach_lessons') ||
            organization.hasRole('instructor'));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mi cuenta'),
        leading: BackButton(onPressed: () => context.go('/inicio')),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ListTile(
            leading: const Icon(Icons.person_outline),
            title: Text(session?.name ?? ''),
            subtitle: Text(
              [
                session?.contact,
                if (session?.phone != null) session?.email,
              ].whereType<String>().join('\n'),
            ),
          ),
          if (session != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: GenderChoice(
                key: const Key('my-gender'),
                title: 'Género (opcional, para nombrarte bien)',
                value: session.gender,
                onChanged: (gender) async {
                  try {
                    await ref
                        .read(sessionControllerProvider.notifier)
                        .setGender(gender);
                    ref.invalidate(currentOrganizationProvider);
                  } catch (error) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(apiErrorMessage(error))),
                      );
                    }
                  }
                },
              ),
            ),
          ListTile(
            leading: const Icon(Icons.groups_outlined),
            title: Text(session?.organization?.name ?? ''),
            subtitle: const Text('Organización activa'),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text('Tus perfiles', style: theme.textTheme.titleMedium),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: RolesList(),
          ),
          const SizedBox(height: 24),
          const Divider(),
          // La guía vive en el inicio; acá se vuelve a abrir si se achicó.
          if (onboarding != null && !onboarding.completed)
            ListTile(
              leading: const Icon(Icons.tune),
              title: Text('Configurar ${organization?.org.the() ?? 'el club'}'),
              subtitle: Text(
                'Guía de primeros pasos · ${onboarding.done} de ${onboarding.total}',
              ),
              onTap: () async {
                if (onboarding.dismissed) {
                  await ref.read(onboardingProvider.notifier).reopen();
                }
                if (context.mounted) context.go('/inicio');
              },
            ),
          if (organization?.can('configure_organization') ?? false)
            ListTile(
              leading: const Icon(Icons.translate_outlined),
              title: const Text('Cómo les dicen'),
              subtitle: Text(
                '${organization!.term('group')}, '
                '${organization.term('instructor').toLowerCase()}, '
                '${organization.term('space').toLowerCase()}…',
              ),
              onTap: () => context.push('/vocabulario'),
            ),
          // También para quien no es tutor (ej. el técnico o el admin con hijos).
          ListTile(
            leading: const Icon(Icons.person_add_alt_outlined),
            title: const Text('Inscribir a un hijo'),
            subtitle: Text(
              '${organization?.org.theUpper() ?? 'El club'} revisa la '
              'solicitud',
            ),
            onTap: () => context.go('/hijos/inscribir'),
          ),
          ListTile(
            key: const Key('account-inbox'),
            leading: Badge(
              isLabelVisible: unread > 0,
              label: Text('$unread'),
              child: const Icon(Icons.inbox_outlined),
            ),
            title: const Text('Avisos'),
            subtitle: Text(
              unread == 0
                  ? 'Lo que te mandó ${organization?.org.the() ?? 'el club'}'
                  : unread == 1
                  ? '1 sin leer'
                  : '$unread sin leer',
            ),
            onTap: () => context.push('/avisos'),
          ),
          ListTile(
            leading: const Icon(Icons.notifications_outlined),
            title: const Text('Notificaciones'),
            subtitle: const Text('Avisos de los días de clase'),
            onTap: () => context.push('/notificaciones'),
          ),
          if (teaches)
            ListTile(
              leading: const Icon(Icons.school_outlined),
              title: const Text('Clases particulares'),
              subtitle: const Text('Precios, paquetes y disponibilidad'),
              onTap: () => context.push('/particulares/ajustes'),
            ),
          if ((session?.organizations.length ?? 0) > 1)
            ListTile(
              leading: const Icon(Icons.swap_horiz),
              title: const Text('Cambiar de organización'),
              onTap: () => context.go('/organizaciones'),
            ),
          ListTile(
            leading: const Icon(Icons.logout),
            title: const Text('Cerrar sesión'),
            onTap: () => ref.read(sessionControllerProvider.notifier).logout(),
          ),
        ],
      ),
    );
  }
}
