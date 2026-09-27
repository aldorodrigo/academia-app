import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/api_client.dart';
import '../../attendance/data/guardian_actions.dart';
import '../data/models.dart';
import '../data/notification_settings_repository.dart';

/// Avisos de los días de clase: cuántos y cuándo, para el técnico y el tutor.
class NotificationSettingsScreen extends ConsumerWidget {
  const NotificationSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(notificationSettingsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notificaciones'),
        leading: BackButton(
          onPressed: () =>
              context.canPop() ? context.pop() : context.go('/inicio'),
        ),
      ),
      body: settings.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(apiErrorMessage(error), textAlign: TextAlign.center),
          ),
        ),
        data: (settings) => _Settings(settings),
      ),
    );
  }
}

class _Settings extends ConsumerWidget {
  const _Settings(this.settings);

  final NotificationSettings settings;

  Future<void> _run(
    BuildContext context,
    Future<String?> Function() action,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final message = await action();
      if (message != null) {
        messenger.showSnackBar(SnackBar(content: Text(message)));
      }
    } catch (error) {
      messenger.showSnackBar(SnackBar(content: Text(apiErrorMessage(error))));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final controller = ref.read(notificationSettingsProvider.notifier);
    final instructor = settings.instructor;
    final guardian = settings.guardian;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (instructor == null && guardian == null)
          const Text('No tenés clases ni hijos inscriptos para avisarte.'),
        if (instructor != null) ...[
          Text('Mis clases', style: theme.textTheme.titleMedium),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Avisarme los días que doy clase'),
            subtitle: const Text(
              'Con cuántos van y un acceso a la asistencia.',
            ),
            value: instructor.enabled,
            onChanged: (value) => _run(context, () async {
              await controller.setInstructorEnabled(value);
              return null;
            }),
          ),
          if (instructor.enabled)
            _OffsetsEditor(
              settings: settings,
              offsets: instructor.offsets,
              onAdd: (offset) => _run(context, () async {
                await controller.addOffset(offset, instructor: true);
                return null;
              }),
              onRemove: (offset) => _run(context, () async {
                await controller.removeOffset(offset, instructor: true);
                return null;
              }),
            ),
          const Divider(height: 32),
        ],
        if (guardian != null) ...[
          Text(
            'Días de clase de mis hijos',
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: 4),
          Text(
            'Te preguntamos "¿Lo llevás?". Si ya respondiste, no te volvemos '
            'a avisar.',
            style: theme.textTheme.bodySmall,
          ),
          for (final child in guardian.students)
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(child.firstName),
              value: child.enabled,
              onChanged: (value) => _run(context, () async {
                final result = await controller.setChild(
                  child.id,
                  enabled: value,
                );
                return remindersMessage(result, child.firstName);
              }),
            ),
          if (guardian.students.any((s) => s.enabled))
            _OffsetsEditor(
              settings: settings,
              offsets: guardian.offsets,
              onAdd: (offset) => _run(context, () async {
                await controller.addOffset(offset, instructor: false);
                return null;
              }),
              onRemove: (offset) => _run(context, () async {
                await controller.removeOffset(offset, instructor: false);
                return null;
              }),
            ),
        ],
      ],
    );
  }
}

/// Chips con los avisos elegidos (hasta [NotificationSettings.max]) y el ejemplo en vivo.
class _OffsetsEditor extends StatelessWidget {
  const _OffsetsEditor({
    required this.settings,
    required this.offsets,
    required this.onAdd,
    required this.onRemove,
  });

  final NotificationSettings settings;
  final List<ReminderOffset> offsets;
  final ValueChanged<ReminderOffset> onAdd;
  final ValueChanged<ReminderOffset> onRemove;

  Future<void> _pick(BuildContext context) async {
    final available = settings.options
        .where((o) => !offsets.contains(o.offset))
        .toList();
    final picked = await showModalBottomSheet<ReminderOffset>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            for (final option in available)
              ListTile(
                title: Text(option.label),
                onTap: () => Navigator.pop(context, option.offset),
              ),
          ],
        ),
      ),
    );
    if (picked != null) onAdd(picked);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final canAdd = offsets.length < settings.max;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final offset in offsets)
              InputChip(
                label: Text(settings.labelOf(offset)),
                onDeleted: offsets.length > 1 ? () => onRemove(offset) : null,
                deleteButtonTooltipMessage: 'Quitar',
              ),
            if (canAdd)
              ActionChip(
                avatar: const Icon(Icons.add, size: 18),
                label: const Text('Agregar aviso'),
                onPressed: () => _pick(context),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Por ejemplo, para una clase del lunes a las 17:00 te avisamos '
          '${describeReminderTimes(offsets)}.',
          style: theme.textTheme.bodySmall,
        ),
        if (!canAdd)
          Text(
            'Podés tener hasta ${settings.max} avisos por clase.',
            style: theme.textTheme.bodySmall,
          ),
      ],
    );
  }
}
