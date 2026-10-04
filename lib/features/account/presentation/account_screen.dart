import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../auth/data/session_controller.dart';
import '../../onboarding/data/onboarding_controller.dart';
import '../../organizations/data/organization_repository.dart';
import '../../organizations/presentation/roles_list.dart';

class AccountScreen extends ConsumerWidget {
  const AccountScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionControllerProvider).value;
    final theme = Theme.of(context);
    final organization = ref.watch(currentOrganizationProvider).value;
    final onboarding = ref.watch(onboardingProvider).value;
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
              title: const Text('Configurar el club'),
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
