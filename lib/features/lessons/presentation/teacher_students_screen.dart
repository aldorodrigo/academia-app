import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/api_client.dart';
import '../../../core/utils/clock.dart';
import '../../../core/utils/format.dart';
import '../data/booking_controller.dart';
import '../data/lessons_repository.dart';
import '../data/models.dart';
import 'booking_sheet.dart';

/// Texto del paquete para el profesor: "Paquete: 2 de 4 · válido del 3/10 al 1/11".
String describeStudentPack(ClassPack? pack) {
  if (pack == null) return 'Sin paquete (clase suelta)';
  return switch (pack.status) {
    ClassPackStatus.pendingPayment =>
      'Paquete de ${pack.classes} clases pendiente de pago',
    ClassPackStatus.active =>
      'Paquete: le ${pack.remaining == 1 ? 'queda 1' : 'quedan ${pack.remaining}'} de ${pack.classes} · ${pack.validity}',
    ClassPackStatus.finished => 'Usó todas las clases del paquete',
    ClassPackStatus.expired =>
      'Paquete vencido el ${pack.expiresOn!.day}/${pack.expiresOn!.month}${pack.remaining > 0 ? ' (sin usar: ${pack.remaining})' : ''}',
  };
}

/// Alumnos del profesor con su saldo de clases: cobrar, vender y extender paquetes.
class TeacherStudentsScreen extends ConsumerWidget {
  const TeacherStudentsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final students = ref.watch(teacherStudentsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mis alumnos'),
        leading: BackButton(
          onPressed: () =>
              context.canPop() ? context.pop() : context.go('/inicio'),
        ),
      ),
      body: students.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text(apiErrorMessage(error))),
        data: (students) => students.isEmpty
            ? const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    'Todavía no tenés alumnos. Aparecen cuando reservan una clase o les vendés un paquete.',
                    textAlign: TextAlign.center,
                  ),
                ),
              )
            : ListView.separated(
                itemCount: students.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (_, i) => _StudentTile(students[i]),
              ),
      ),
    );
  }
}

class _StudentTile extends ConsumerWidget {
  const _StudentTile(this.summary);

  final TeacherStudentSummary summary;

  void _snack(BuildContext context, String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

  Future<void> _collect(BuildContext context) async {
    final pack = summary.pack;
    final packDue = pack != null && pack.isPending
        ? pack.charge?.pending
        : null;
    final result = await showCollectSheet(
      context,
      student: summary.student,
      amount: packDue ?? summary.debt,
      classPackId: packDue != null ? pack!.id : null,
    );
    if (result != null && context.mounted) _snack(context, result.message);
  }

  Future<void> _sell(BuildContext context, WidgetRef ref) async {
    final offer = await showDialog<LessonOffer>(
      context: context,
      builder: (_) => const _SellPackDialog(),
    );
    if (offer == null || !context.mounted) return;
    try {
      final pack = await ref
          .read(teacherLessonActionsProvider)
          .sellPack(summary.student.id, offer);
      if (!context.mounted) return;
      if (pack.isActive) {
        _snack(context, 'Paquete activo (se pagó con su saldo a favor).');
        return;
      }
      final result = await showCollectSheet(
        context,
        student: summary.student,
        amount: pack.charge?.pending ?? pack.price,
        classPackId: pack.id,
      );
      if (context.mounted) {
        _snack(
          context,
          result?.message ??
              'Paquete cargado. Se activa cuando registres el pago.',
        );
      }
    } catch (error) {
      if (context.mounted) _snack(context, apiErrorMessage(error));
    }
  }

  Future<void> _extend(BuildContext context, WidgetRef ref) async {
    final pack = summary.pack!;
    final today = ref.read(todayProvider);
    final expiresOn = await showModalBottomSheet<DateTime>(
      context: context,
      showDragHandle: true,
      builder: (_) => _ExtendSheet(pack: pack, today: today),
    );
    if (expiresOn == null || !context.mounted) return;
    try {
      await ref.read(teacherLessonActionsProvider).extend(pack, expiresOn);
      if (context.mounted) {
        _snack(context, 'Paquete extendido hasta el ${formatDate(expiresOn)}.');
      }
    } catch (error) {
      if (context.mounted) _snack(context, apiErrorMessage(error));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final today = ref.watch(todayProvider);
    final warning = summary.pack?.expiryWarning(today);
    final money = [
      if (summary.debt > 0) 'Debe ${formatMoney(summary.debt)}',
      if (summary.credit > 0) 'A favor ${formatMoney(summary.credit)}',
    ].join(' · ');

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(summary.student.fullName, style: theme.textTheme.titleSmall),
          Text(describeStudentPack(summary.pack)),
          if (warning != null)
            Text(
              warning,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
          if (money.isNotEmpty) Text(money, style: theme.textTheme.bodySmall),
          Wrap(
            spacing: 4,
            children: [
              TextButton(
                onPressed: () => _collect(context),
                child: const Text('Cobrar'),
              ),
              TextButton(
                onPressed: () => _sell(context, ref),
                child: const Text('Vender paquete'),
              ),
              if (summary.canExtend)
                TextButton(
                  onPressed: () => _extend(context, ref),
                  child: const Text('Extender'),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Elegir cuál de los paquetes del profesor se vende.
class _SellPackDialog extends ConsumerWidget {
  const _SellPackDialog();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(lessonProfileProvider);
    return AlertDialog(
      title: const Text('Vender paquete'),
      content: profile.when(
        loading: () => const LinearProgressIndicator(),
        error: (error, _) => Text(apiErrorMessage(error)),
        data: (profile) {
          final offers = profile.packs.where((p) => p.id != null).toList();
          if (offers.isEmpty) {
            return const Text(
              'No tenés paquetes. Cargalos en los ajustes de clases particulares.',
            );
          }
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final offer in offers)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(offer.title),
                  subtitle: Text(offer.describe(profile.singlePrice)),
                  onTap: () => Navigator.pop(context, offer),
                ),
            ],
          );
        },
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
      ],
    );
  }
}

/// Extender el vencimiento: +7 / +15 / +30 días o una fecha.
class _ExtendSheet extends StatelessWidget {
  const _ExtendSheet({required this.pack, required this.today});

  final ClassPack pack;
  final DateTime today;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Extender el paquete', style: theme.textTheme.titleLarge),
            Text(
              pack.expiresOn == null
                  ? 'No tiene vencimiento.'
                  : '${pack.status == ClassPackStatus.expired ? 'Venció' : 'Vence'} el ${formatDate(pack.expiresOn!)}.',
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              children: [
                for (final days in const [7, 15, 30])
                  ActionChip(
                    label: Text('+$days días'),
                    onPressed: () => Navigator.pop(
                      context,
                      extendedExpiry(pack, days, today),
                    ),
                  ),
                ActionChip(
                  avatar: const Icon(Icons.calendar_today, size: 18),
                  label: const Text('Elegir fecha'),
                  onPressed: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: extendedExpiry(pack, 7, today),
                      firstDate: today,
                      lastDate: DateTime(
                        today.year + 1,
                        today.month,
                        today.day,
                      ),
                    );
                    if (date != null && context.mounted) {
                      Navigator.pop(context, date);
                    }
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
