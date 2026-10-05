import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/api_client.dart';
import '../../../core/utils/launcher.dart';
import '../data/calendar_providers.dart';
import '../data/models.dart';

/// Sincronizar con Google Calendar, el Calendario de iPhone/Mac u otro: un
/// link de suscripción que se agrega una vez y se actualiza solo.
class CalendarSyncScreen extends ConsumerWidget {
  const CalendarSyncScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final feed = ref.watch(calendarFeedProvider);
    return Scaffold(
      appBar: AppBar(
        leading: BackButton(
          onPressed: () =>
              context.canPop() ? context.pop() : context.go('/calendario'),
        ),
        title: const Text('Sincronizar calendario'),
      ),
      body: switch (feed) {
        AsyncValue(value: final feed?) => _SyncOptions(feed),
        AsyncValue(:final error?) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(apiErrorMessage(error), textAlign: TextAlign.center),
                const SizedBox(height: 12),
                FilledButton.tonal(
                  onPressed: () => ref.invalidate(calendarFeedProvider),
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

/// El calendario del sistema va primero (Apple en iPhone/Mac, Google en el resto).
bool get _appleFirst =>
    defaultTargetPlatform == TargetPlatform.iOS ||
    defaultTargetPlatform == TargetPlatform.macOS;

class _SyncOptions extends ConsumerStatefulWidget {
  const _SyncOptions(this.feed);

  final CalendarFeed feed;

  @override
  ConsumerState<_SyncOptions> createState() => _SyncOptionsState();
}

class _SyncOptionsState extends ConsumerState<_SyncOptions> {
  var _resetting = false;

  void _message(String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

  Future<void> _open(String url) async {
    final opened = await ref.read(urlLauncherProvider)(Uri.parse(url));
    if (!opened && mounted) {
      _message('No se pudo abrir. Copiá el link y agregalo a mano.');
    }
  }

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: widget.feed.url));
    if (mounted) _message('Link copiado.');
  }

  Future<void> _reset() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('¿Generar un link nuevo?'),
        content: const Text(
          'El link actual deja de funcionar: el calendario que agregaste deja '
          'de actualizarse y vas a tener que agregarlo de nuevo.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Volver'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Generar link nuevo'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _resetting = true);
    try {
      await ref.read(calendarActionsProvider).resetFeed();
      _message('Listo: link nuevo. Volvé a agregarlo a tu calendario.');
    } catch (error) {
      _message(apiErrorMessage(error));
    } finally {
      if (mounted) setState(() => _resetting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final feed = widget.feed;

    final google = _Option(
      icon: Icons.calendar_month_outlined,
      title: 'Google Calendar',
      subtitle: 'Android, la web o tu cuenta de Google',
      onTap: () => _open(feed.googleUrl),
    );
    final apple = _Option(
      icon: Icons.event_available_outlined,
      title: 'Calendario de iPhone o Mac',
      subtitle: 'Te pregunta si querés suscribirte',
      onTap: () => _open(feed.webcalUrl),
    );

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: [
        CircleAvatar(
          radius: 32,
          backgroundColor: scheme.primaryContainer,
          child: Icon(Icons.sync, size: 32, color: scheme.onPrimaryContainer),
        ),
        const SizedBox(height: 16),
        Text(
          'Tus actividades en el calendario de tu celular',
          textAlign: TextAlign.center,
          style: theme.textTheme.titleLarge,
        ),
        const SizedBox(height: 8),
        Text(
          'Clases, particulares, eventos y días sin clase aparecen junto a '
          'tus otras cosas y se actualizan solos. Si se suspende una clase, '
          'también se marca ahí.',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium,
        ),
        const SizedBox(height: 24),
        Text('Agregalo a', style: theme.textTheme.titleSmall),
        const SizedBox(height: 8),
        Card(
          margin: EdgeInsets.zero,
          child: Column(
            children: [
              if (_appleFirst) apple else google,
              const Divider(height: 1),
              if (_appleFirst) google else apple,
              const Divider(height: 1),
              _Option(
                icon: Icons.link,
                title: 'Copiar link',
                subtitle: 'Para Outlook u otro calendario',
                onTap: _copy,
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        const _GoogleHelp(),
        const SizedBox(height: 16),
        _Note(
          icon: Icons.schedule,
          text:
              'Google actualiza el calendario cada algunas horas. Si se '
              'suspende una clase a último momento, te llega igual el aviso.',
        ),
        _Note(
          icon: Icons.lock_outline,
          text:
              'El link es personal: quien lo tenga ve tus actividades (nunca '
              'pagos ni datos de salud). No lo compartas.',
        ),
        _Note(
          icon: Icons.visibility_off_outlined,
          text:
              'Para dejar de verlo, quitá el calendario "Tuku" desde la app de '
              'calendario.',
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: _resetting ? null : _reset,
            icon: const Icon(Icons.refresh),
            label: const Text('Generar un link nuevo'),
          ),
        ),
      ],
    );
  }
}

class _Option extends StatelessWidget {
  const _Option({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => ListTile(
    leading: Icon(icon, color: Theme.of(context).colorScheme.primary),
    title: Text(title),
    subtitle: Text(subtitle),
    trailing: const Icon(Icons.chevron_right),
    onTap: onTap,
  );
}

/// Pasos para agregarlo a mano en Google (desde el celular no siempre se puede).
class _GoogleHelp extends StatelessWidget {
  const _GoogleHelp();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Theme(
      data: theme.copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 4),
        childrenPadding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        title: Text(
          '¿No se agregó en Google?',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.primary,
            fontWeight: FontWeight.w600,
          ),
        ),
        children: const [
          Text(
            '1. Tocá "Copiar link".\n'
            '2. En una compu, entrá a calendar.google.com.\n'
            '3. Al lado de "Otros calendarios", tocá + y elegí "Desde URL".\n'
            '4. Pegá el link y tocá "Agregar calendario".\n'
            '5. En la app Google Calendar del celular, activá "Tuku" en la '
            'lista de calendarios si no aparece.',
          ),
        ],
      ),
    );
  }
}

class _Note extends StatelessWidget {
  const _Note({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
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
