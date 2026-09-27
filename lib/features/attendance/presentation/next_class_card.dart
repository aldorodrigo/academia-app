import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/utils/clock.dart';
import '../../../core/utils/format.dart';
import '../data/attendance_repository.dart';
import '../data/guardian_actions.dart';
import '../data/models.dart';

/// Tarjetas del inicio para el tutor: la próxima clase de cada hijo con
/// "¿Lo llevás?" y, la primera vez, si quiere que le avisen los días de clase.
class NextClassesList extends ConsumerWidget {
  const NextClassesList({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final agenda = ref.watch(agendaProvider).value ?? const [];
    return Column(children: [for (final item in agenda) NextClassCard(item)]);
  }
}

class NextClassCard extends ConsumerStatefulWidget {
  const NextClassCard(this.item, {super.key});

  final AgendaItem item;

  @override
  ConsumerState<NextClassCard> createState() => _NextClassCardState();
}

class _NextClassCardState extends ConsumerState<NextClassCard> {
  bool _changing = false;
  bool _busy = false;

  Future<void> _run(Future<String?> Function() action) async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      final message = await action();
      if (message != null) {
        messenger.showSnackBar(SnackBar(content: Text(message)));
      }
      if (mounted) setState(() => _changing = false);
    } catch (error) {
      messenger.showSnackBar(SnackBar(content: Text(apiErrorMessage(error))));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _respond(bool going) => _run(() async {
    await ref
        .read(guardianActionsProvider)
        .respond(widget.item.session.id, widget.item.studentId, going: going);
    return null;
  });

  void _reminders(bool enabled) => _run(() async {
    final result = await ref
        .read(guardianActionsProvider)
        .setReminders(widget.item.studentId, enabled: enabled);
    return enabled
        ? remindersMessage(result, widget.item.studentFirstName)
        : null;
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final item = widget.item;
    final session = item.session;
    final today = ref.watch(todayProvider);
    final now = ref.watch(nowProvider);
    final canRespond = item.canRespond && !session.hasStarted(now);
    final day = formatDay(session.date, today);
    final isToday = day == 'hoy';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '${item.studentFirstName} tiene ${session.group.program.name} '
              '$day a las ${session.startsAt}',
              style: theme.textTheme.titleSmall,
            ),
            Text(
              [session.group.name, ?session.venue].join(' · '),
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            if (session.suspended)
              Row(
                children: [
                  Icon(Icons.block, color: theme.colorScheme.error),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      session.suspensionReason == null
                          ? 'Clase suspendida.'
                          : 'Clase suspendida: ${session.suspensionReason}.',
                    ),
                  ),
                ],
              )
            else if (item.response == null || _changing)
              canRespond
                  ? _Question(
                      question: isToday ? '¿Lo llevás hoy?' : '¿Lo llevás?',
                      busy: _busy,
                      onAnswer: _respond,
                    )
                  : const Text('No respondiste.')
            else
              Row(
                children: [
                  Icon(
                    item.response == GuardianResponse.going
                        ? Icons.check_circle
                        : Icons.event_busy,
                    color: item.response == GuardianResponse.going
                        ? const Color(0xFF059669)
                        : theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      item.response == GuardianResponse.going
                          ? 'Avisaste que va.'
                          : 'Avisaste que no va.',
                    ),
                  ),
                  if (canRespond)
                    TextButton(
                      onPressed: _busy
                          ? null
                          : () => setState(() => _changing = true),
                      child: const Text('Cambiar'),
                    ),
                ],
              ),
            if (item.classReminders == null) ...[
              const Divider(height: 24),
              Row(
                children: [
                  const Icon(Icons.notifications_active_outlined),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '¿Querés que te avise los días de clase de '
                      '${item.studentFirstName}?',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _busy ? null : () => _reminders(false),
                    child: const Text('Ahora no'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.tonal(
                    onPressed: _busy ? null : () => _reminders(true),
                    child: const Text('Sí, avisame'),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Question extends StatelessWidget {
  const _Question({
    required this.question,
    required this.busy,
    required this.onAnswer,
  });

  final String question;
  final bool busy;
  final ValueChanged<bool> onAnswer;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: Text(question, style: Theme.of(context).textTheme.titleMedium),
      ),
      OutlinedButton(
        onPressed: busy ? null : () => onAnswer(false),
        child: const Text('No va'),
      ),
      const SizedBox(width: 8),
      FilledButton(
        onPressed: busy ? null : () => onAnswer(true),
        child: const Text('Sí, va'),
      ),
    ],
  );
}
