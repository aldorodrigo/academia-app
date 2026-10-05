import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/api_client.dart';
import '../../../core/utils/clock.dart';
import '../../../core/utils/format.dart';
import '../data/calendar_providers.dart';
import '../data/models.dart';
import 'calendar_style.dart';

/// Detalle de un evento o día sin clase, con editar y cancelar.
class EventScreen extends ConsumerWidget {
  const EventScreen({required this.id, super.key});

  final int id;

  Future<void> _cancel(
    BuildContext context,
    WidgetRef ref,
    CalendarEvent event,
  ) async {
    final reason = await showDialog<String>(
      context: context,
      builder: (_) => CancelEventDialog(event: event),
    );
    if (reason == null || !context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(calendarActionsProvider).cancel(event.id, reason: reason);
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            event.isDayOff
                ? 'Listo: las clases vuelven a quedar programadas.'
                : 'Listo: avisamos que se canceló.',
          ),
        ),
      );
    } catch (error) {
      messenger.showSnackBar(SnackBar(content: Text(apiErrorMessage(error))));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(eventProvider(id));
    final event = async.value;
    return Scaffold(
      appBar: AppBar(
        leading: BackButton(
          onPressed: () =>
              context.canPop() ? context.pop() : context.go('/calendario'),
        ),
        title: Text(
          event == null
              ? 'Evento'
              : event.isDayOff
              ? 'Día sin clase'
              : event.categoryLabel,
        ),
        actions: [
          if (event != null &&
              !event.cancelled &&
              (event.canEdit || event.canCancel))
            PopupMenuButton<String>(
              tooltip: 'Más opciones',
              onSelected: (action) => action == 'edit'
                  ? context.push('/eventos/${event.id}/editar')
                  : _cancel(context, ref, event),
              itemBuilder: (_) => [
                if (event.canEdit)
                  const PopupMenuItem(value: 'edit', child: Text('Editar')),
                if (event.canCancel)
                  PopupMenuItem(
                    value: 'cancel',
                    child: Text(
                      event.isDayOff
                          ? 'Cancelar día sin clase'
                          : 'Cancelar evento',
                    ),
                  ),
              ],
            ),
        ],
      ),
      body: switch (async) {
        AsyncValue(value: final event?) => _EventDetail(event),
        AsyncValue(:final error?) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(apiErrorMessage(error), textAlign: TextAlign.center),
                const SizedBox(height: 12),
                FilledButton.tonal(
                  onPressed: () => ref.invalidate(eventProvider(id)),
                  child: const Text('Reintentar'),
                ),
              ],
            ),
          ),
        ),
        _ => const Center(child: CircularProgressIndicator()),
      },
    );
  }
}

class _EventDetail extends ConsumerWidget {
  const _EventDetail(this.event);

  final CalendarEvent event;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final today = ref.watch(todayProvider);
    final color = event.cancelled ? scheme.onSurfaceVariant : scheme.tertiary;
    final createdAt = event.createdAt;

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        if (event.cancelled)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Material(
              color: scheme.errorContainer,
              borderRadius: BorderRadius.circular(14),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Icon(Icons.cancel_outlined, color: scheme.onErrorContainer),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        event.cancelReason == null
                            ? 'Se canceló.'
                            : 'Se canceló: ${event.cancelReason}',
                        style: TextStyle(color: scheme.onErrorContainer),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        Row(
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: color.withValues(alpha: 0.12),
              child: Icon(eventIcon(event), color: color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                event.categoryLabel,
                style: theme.textTheme.titleMedium?.copyWith(color: color),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Text(
          event.title,
          style: theme.textTheme.headlineSmall?.copyWith(
            decoration: event.cancelled ? TextDecoration.lineThrough : null,
          ),
        ),
        const SizedBox(height: 16),
        _Info(
          icon: Icons.calendar_today_outlined,
          text: '${event.dateDescription} · ${event.timeDescription}',
        ),
        if (event.placeName != null)
          _Info(icon: Icons.place_outlined, text: event.placeName!),
        _Info(
          icon: Icons.groups_outlined,
          text: 'Para: ${event.audienceDescription}',
        ),
        if (event.isDayOff && event.waiveCharge)
          const _Info(
            icon: Icons.money_off_outlined,
            text: 'Las clases suspendidas no se cobran.',
          ),
        if (event.description != null) ...[
          const SizedBox(height: 8),
          Text(event.description!, style: theme.textTheme.bodyLarge),
        ],
        if (event.isDayOff && event.affectedClasses.isNotEmpty) ...[
          const SizedBox(height: 24),
          Text(
            event.cancelled
                ? 'Clases que se habían suspendido'
                : 'Clases suspendidas',
            style: theme.textTheme.titleSmall,
          ),
          const SizedBox(height: 4),
          for (final item in event.affectedClasses)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.block),
              title: Text(item.group.name),
              subtitle: Text(
                '${formatShortDay(item.date, today)} ${item.startsAt}'
                '${item.endsAt == null ? '' : '–${item.endsAt}'}',
              ),
            ),
        ],
        if (event.createdBy != null) ...[
          const SizedBox(height: 24),
          Text(
            [
              'Publicado por ${event.createdBy}',
              if (createdAt != null)
                'el ${createdAt.day} de ${monthName(createdAt.month)}',
            ].join(' '),
            style: theme.textTheme.bodySmall,
          ),
        ],
      ],
    );
  }
}

class _Info extends StatelessWidget {
  const _Info({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          size: 20,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
        const SizedBox(width: 12),
        Expanded(child: Text(text)),
      ],
    ),
  );
}

/// Confirma la cancelación con un motivo opcional; devuelve el motivo
/// ("" sin motivo) o null si se arrepintió.
class CancelEventDialog extends StatefulWidget {
  const CancelEventDialog({required this.event, super.key});

  final CalendarEvent event;

  @override
  State<CancelEventDialog> createState() => _CancelEventDialogState();
}

class _CancelEventDialogState extends State<CancelEventDialog> {
  final _reason = TextEditingController();

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final event = widget.event;
    final classes = event.affectedClasses.length;
    final effect = event.isDayOff
        ? classes > 0
              ? 'Las $classes clases que se suspendieron vuelven a quedar '
                    'programadas y avisamos a las familias.'
              : 'Las clases que se suspendieron vuelven a quedar programadas '
                    'y avisamos a las familias.'
        : 'Avisamos a las familias que se canceló.';
    return AlertDialog(
      title: Text(
        event.isDayOff ? '¿Cancelar el día sin clase?' : '¿Cancelar el evento?',
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(effect),
          const SizedBox(height: 16),
          TextField(
            controller: _reason,
            maxLength: 200,
            decoration: const InputDecoration(
              labelText: 'Motivo (opcional)',
              hintText: 'Ej.: se pasó para el sábado',
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Volver'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, _reason.text),
          child: const Text('Cancelar y avisar'),
        ),
      ],
    );
  }
}
