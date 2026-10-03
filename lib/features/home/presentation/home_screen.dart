import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../attendance/presentation/next_class_card.dart';
import '../../attendance/presentation/today_classes_card.dart';
import '../../auth/data/session_controller.dart';
import '../../billing/presentation/account_summary_card.dart';
import '../../lessons/presentation/lessons_card.dart';
import '../../lessons/presentation/today_lessons_card.dart';
import '../../organizations/data/organization_repository.dart';
import '../../organizations/presentation/roles_list.dart';
import '../../reports/presentation/reports_card.dart';
import '../../students/data/students_repository.dart';
import '../../students/presentation/students_list.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionControllerProvider).value;
    final theme = Theme.of(context);
    final isGuardian =
        ref.watch(currentOrganizationProvider).value?.hasRole('tutor') ?? false;
    final students = ref.watch(studentsProvider).value ?? const [];
    final onlySelf = students.isNotEmpty && students.every((s) => s.isSelf);

    return Scaffold(
      appBar: AppBar(
        title: Text(session?.organization?.name ?? 'Inicio'),
        actions: [
          IconButton(
            tooltip: 'Mi cuenta',
            icon: const Icon(Icons.account_circle_outlined),
            onPressed: () => context.go('/cuenta'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text(
            'Hola, ${session?.name ?? ''}.',
            style: theme.textTheme.headlineSmall,
          ),
          const SizedBox(height: 16),
          const RolesList(),
          const SizedBox(height: 16),
          const TodayClassesCard(),
          const TodayLessonsCard(),
          const ReportsCard(),
          const LessonsCard(),
          if (isGuardian || students.isNotEmpty) ...[
            const SizedBox(height: 32),
            Text(
              onlySelf ? 'Mis inscripciones' : 'Mis hijos',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            const NextClassesList(),
            const AccountSummaryCard(),
            const SizedBox(height: 8),
            const StudentsList(),
          ],
        ],
      ),
    );
  }
}
