import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../enrollment/data/enrollment_repository.dart';
import '../../enrollment/presentation/my_requests.dart';
import '../data/students_repository.dart';
import 'students_list.dart';

class StudentsScreen extends ConsumerWidget {
  const StudentsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final students = ref.watch(studentsProvider).value ?? const [];
    final onlySelf = students.isNotEmpty && students.every((s) => s.isSelf);

    return Scaffold(
      appBar: AppBar(
        title: Text(onlySelf ? 'Mis inscripciones' : 'Mis hijos'),
        leading: BackButton(onPressed: () => context.go('/inicio')),
      ),
      body: RefreshIndicator(
        onRefresh: () {
          ref.invalidate(myEnrollmentRequestsProvider);
          return ref.refresh(studentsProvider.future);
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const MyEnrollmentRequests(),
            const StudentsList(),
            if (!onlySelf) const EnrollChildButton(),
          ],
        ),
      ),
    );
  }
}
