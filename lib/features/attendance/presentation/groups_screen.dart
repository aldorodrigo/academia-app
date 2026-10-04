import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/api_client.dart';
import '../data/attendance_repository.dart';

/// Grupos del técnico.
class GroupsScreen extends ConsumerWidget {
  const GroupsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groups = ref.watch(instructorGroupsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mis grupos'),
        leading: BackButton(onPressed: () => context.go('/inicio')),
      ),
      body: groups.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text(apiErrorMessage(error))),
        data: (groups) => groups.isEmpty
            ? const Center(child: Text('No tenés grupos asignados.'))
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  for (final item in groups)
                    Card(
                      child: ListTile(
                        title: Text(
                          '${item.group.name} · ${item.group.program.name}',
                        ),
                        subtitle: Text(
                          [
                            '${item.studentsCount} '
                                '${item.studentsCount == 1 ? 'alumno' : 'alumnos'}',
                            ...item.group.schedules.map((s) => s.description),
                          ].join('\n'),
                        ),
                        isThreeLine: item.group.schedules.length > 1,
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => context.go('/grupos/${item.group.id}'),
                      ),
                    ),
                ],
              ),
      ),
    );
  }
}
