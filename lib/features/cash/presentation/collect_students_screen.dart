import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/utils/format.dart';
import '../data/cash_repository.dart';
import '../data/models.dart';
import '../../../core/vocabulary/vocabulary.dart';
import '../../../core/widgets/error_view.dart';
import '../../organizations/data/organization_repository.dart';

/// "Cobrar": los alumnos (con la palabra de la organización) que puede cobrar quien usa la app (los de sus grupos,
/// o todos para la comisión), con lo que debe hoy cada familia.
class CollectStudentsScreen extends ConsumerStatefulWidget {
  const CollectStudentsScreen({super.key});

  @override
  ConsumerState<CollectStudentsScreen> createState() =>
      _CollectStudentsScreenState();
}

class _CollectStudentsScreenState extends ConsumerState<CollectStudentsScreen> {
  String _search = '';

  @override
  Widget build(BuildContext context) {
    final students = ref.watch(collectableStudentsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Cobrar'),
        leading: BackButton(onPressed: () => context.go('/inicio')),
        actions: [
          TextButton.icon(
            icon: const Icon(Icons.account_balance_wallet_outlined),
            label: const Text('Mi caja'),
            onPressed: () => context.go('/mi-caja'),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(collectableStudentsProvider.future),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextField(
              key: const Key('collect-search'),
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Buscá por nombre o familia',
              ),
              onChanged: (value) => setState(() => _search = value),
            ),
            const SizedBox(height: 8),
            ...students.when(
              loading: () => const [LinearProgressIndicator()],
              error: (error, _) => [
                ErrorView(
                  error,
                  onRetry: () => ref.invalidate(collectableStudentsProvider),
                ),
              ],
              data: (list) => _list(context, list),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _list(BuildContext context, List<CollectableStudent> list) {
    if (list.isEmpty) {
      final organization = ref.watch(currentOrganizationProvider).value;
      final student = organization?.word('student') ?? Word.of('Jugador');
      final group = organization?.word('group') ?? Word.of('Categoría');
      return [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Text(
            'No hay ${student.pluralLower} '
            '${student.g('inscriptos', 'inscriptas')} en tus '
            '${group.pluralLower}.',
          ),
        ),
      ];
    }
    final shown = list.where((s) => s.matches(_search)).toList();
    if (shown.isEmpty) {
      return const [
        Padding(
          padding: EdgeInsets.symmetric(vertical: 16),
          child: Text('No encontramos a nadie con ese nombre.'),
        ),
      ];
    }
    return [for (final student in shown) _StudentTile(student)];
  }
}

class _StudentTile extends StatelessWidget {
  const _StudentTile(this.student);

  final CollectableStudent student;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final details = [...student.groups, ?student.family].join(' · ');

    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        foregroundImage: student.photoUrl == null
            ? null
            : NetworkImage(student.photoUrl!),
        child: Text(student.initials),
      ),
      title: Text(student.fullName),
      subtitle: details.isEmpty ? null : Text(details),
      trailing: student.dueNow > 0
          ? Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  formatMoney(student.dueNow),
                  style: theme.textTheme.titleSmall,
                ),
                Text(
                  student.overdue > 0 ? 'Vencido' : 'Debe',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: student.overdue > 0
                        ? theme.colorScheme.error
                        : theme.colorScheme.tertiary,
                  ),
                ),
              ],
            )
          : Text(
              'Al día',
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.primary,
              ),
            ),
      onTap: () => context.push('/cobrar/${student.id}'),
    );
  }
}
