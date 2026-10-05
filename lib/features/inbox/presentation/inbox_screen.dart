import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/api_client.dart';
import '../../../core/utils/format.dart';
import '../data/inbox_repository.dart';

/// `/avisos`: la bandeja con la copia de cada aviso (push y correo), los más
/// nuevos primero. Le llega a toda cuenta, aunque no tenga notificaciones ni
/// correo. Tocar uno lo marca leído y, si tiene pantalla, la abre.
class InboxScreen extends ConsumerWidget {
  const InboxScreen({super.key});

  Future<void> _open(
    BuildContext context,
    WidgetRef ref,
    InboxNotification notification,
  ) async {
    await ref.read(inboxProvider.notifier).markRead(notification);
    final route = notification.route;
    if (route != null && route.startsWith('/') && context.mounted) {
      context.go(route);
    }
  }

  Future<void> _markAll(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(inboxProvider.notifier).markAllRead();
    } catch (error) {
      messenger.showSnackBar(SnackBar(content: Text(apiErrorMessage(error))));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final inbox = ref.watch(inboxProvider);
    final unread = inbox.value?.unread ?? 0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Avisos'),
        leading: BackButton(
          onPressed: () =>
              context.canPop() ? context.pop() : context.go('/inicio'),
        ),
        actions: [
          if (unread > 0)
            TextButton(
              onPressed: () => _markAll(context, ref),
              child: const Text('Marcar todos como leídos'),
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(inboxProvider.future),
        child: inbox.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => ListView(
            padding: const EdgeInsets.all(24),
            children: [Text(apiErrorMessage(error))],
          ),
          data: (page) => page.items.isEmpty
              ? ListView(
                  padding: const EdgeInsets.all(24),
                  children: const [
                    Text(
                      'Todavía no tenés avisos. Acá van a quedar los que te '
                      'mande el club.',
                    ),
                  ],
                )
              : ListView(
                  children: [
                    for (final notification in page.items)
                      _InboxTile(
                        notification,
                        onTap: () => _open(context, ref, notification),
                      ),
                    if (page.hasMore)
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: OutlinedButton(
                          onPressed: () =>
                              ref.read(inboxProvider.notifier).loadMore(),
                          child: const Text('Ver más'),
                        ),
                      ),
                  ],
                ),
        ),
      ),
    );
  }
}

class _InboxTile extends StatelessWidget {
  const _InboxTile(this.notification, {required this.onTap});

  final InboxNotification notification;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final unread = !notification.isRead;
    final at = notification.createdAt;
    String two(int n) => n.toString().padLeft(2, '0');

    return ListTile(
      key: Key('inbox-${notification.id}'),
      leading: Icon(
        unread ? Icons.mark_email_unread_outlined : Icons.drafts_outlined,
        color: unread ? theme.colorScheme.primary : null,
      ),
      title: Text(
        notification.title,
        style: unread ? const TextStyle(fontWeight: FontWeight.bold) : null,
      ),
      subtitle: Text(
        '${notification.body}\n${formatDate(at)} ${two(at.hour)}:${two(at.minute)}'
        '${unread ? ' · Sin leer' : ''}',
      ),
      isThreeLine: true,
      onTap: onTap,
    );
  }
}

/// En el inicio, solo si hay avisos sin leer.
class InboxCard extends ConsumerWidget {
  const InboxCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unread = ref.watch(unreadNotificationsProvider);
    if (unread == 0) return const SizedBox.shrink();

    return Card(
      key: const Key('inbox-card'),
      child: ListTile(
        leading: Badge(
          label: Text('$unread'),
          child: const Icon(Icons.notifications_outlined),
        ),
        title: const Text('Avisos'),
        subtitle: Text(
          unread == 1
              ? 'Tenés 1 aviso sin leer'
              : 'Tenés $unread avisos sin leer',
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => context.push('/avisos'),
      ),
    );
  }
}
