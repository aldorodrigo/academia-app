import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/vocabulary/vocabulary.dart';
import '../../organizations/data/organization_repository.dart';
import '../data/attendance_repository.dart';
import '../../../core/widgets/error_view.dart';

/// Grupos del técnico.
class GroupsScreen extends ConsumerWidget {
  const GroupsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groups = ref.watch(instructorGroupsProvider);
    final organization = ref.watch(currentOrganizationProvider).value;
    final group = organization?.word('group') ?? Word.of('Grupo');
    final student = organization?.word('student') ?? Word.of('Alumno');

    return Scaffold(
      appBar: AppBar(
        title: Text('Mis ${group.pluralLower}'),
        leading: BackButton(onPressed: () => context.go('/inicio')),
      ),
      body: groups.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => ErrorView(
          error,
          onRetry: () => ref.invalidate(instructorGroupsProvider),
        ),
        data: (groups) => groups.isEmpty
            ? Center(
                child: Text(
                  'No tenés ${group.pluralLower} '
                  '${group.g('asignados', 'asignadas')}.',
                ),
              )
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
                                '${item.studentsCount == 1 ? student.lower : student.pluralLower}',
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
