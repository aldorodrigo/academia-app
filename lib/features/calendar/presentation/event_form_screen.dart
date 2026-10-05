import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/api_client.dart';
import '../../../core/utils/clock.dart';
import '../../../core/utils/format.dart';
import '../../organizations/data/organization_repository.dart';
import '../data/calendar_providers.dart';
import '../data/event_form_controller.dart';
import '../data/models.dart';
import 'calendar_style.dart';

/// Publicar un evento o un día sin clase, o editar uno ya publicado.
class EventFormScreen extends ConsumerWidget {
  const EventFormScreen({
    super.key,
    this.kind = EventKind.event,
    this.date,
    this.eventId,
  });

  final EventKind kind;
  final DateTime? date;

  /// Para editar.
  final int? eventId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final id = eventId;
    if (id == null) {
      return _EventForm(args: (kind: kind, date: date, event: null));
    }
    final event = ref.watch(eventProvider(id));
    return switch (event) {
      AsyncValue(value: final event?) => _EventForm(
        args: (kind: event.kind, date: null, event: event),
      ),
      AsyncValue(:final error?) => Scaffold(
        appBar: AppBar(title: const Text('Editar')),
        body: Center(child: Text(apiErrorMessage(error))),
      ),
      _ => Scaffold(
        appBar: AppBar(title: const Text('Editar')),
        body: const Center(child: CircularProgressIndicator()),
      ),
    };
  }
}

class _EventForm extends ConsumerStatefulWidget {
  const _EventForm({required this.args});

  final EventFormArgs args;

  @override
  ConsumerState<_EventForm> createState() => _EventFormState();
}

class _EventFormState extends ConsumerState<_EventForm> {
  late final EventDraft _initial = ref
      .read(eventFormProvider(widget.args))
      .draft;
  late final _title = TextEditingController(text: _initial.title);
  late final _place = TextEditingController(text: _initial.place);
  late final _description = TextEditingController(text: _initial.description);

  /// Eligió "Otro lugar…" (escribe el lugar en vez de elegir una sede).
  late var _otherPlace =
      _initial.venueId == null && _initial.place.trim().isNotEmpty;
  late var _manyDays =
      _initial.endsOn != null && _initial.endsOn != _initial.startsOn;

  EventFormController get _controller =>
      ref.read(eventFormProvider(widget.args).notifier);

  @override
  void initState() {
    super.initState();
    // Técnico con un solo grupo: ya queda elegido.
    ref.listenManual(eventOptionsProvider, (_, next) {
      final options = next.value;
      if (options != null) _controller.applyOptions(options);
    }, fireImmediately: true);
  }

  @override
  void dispose() {
    _title.dispose();
    _place.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _pickDate({required bool end}) async {
    final draft = ref.read(eventFormProvider(widget.args)).draft;
    final today = ref.read(todayProvider);
    final start = draft.startsOn ?? today;
    final first = draft.isDayOff ? today : DateTime(today.year - 1);
    final initial = end ? draft.endsOn ?? start : start;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial.isBefore(first) ? first : initial,
      firstDate: end && !start.isBefore(first) ? start : first,
      lastDate: DateTime(today.year + 1, today.month, today.day),
      helpText: end ? 'Hasta' : 'Desde',
    );
    if (picked == null) return;
    _controller.update(
      (d) => end
          ? d.copyWith(endsOn: () => picked)
          : d.copyWith(
              startsOn: picked,
              // El fin no puede quedar antes del inicio.
              endsOn: d.endsOn != null && d.endsOn!.isBefore(picked)
                  ? () => picked
                  : null,
            ),
    );
  }

  Future<void> _pickTime({required bool end}) async {
    final draft = ref.read(eventFormProvider(widget.args)).draft;
    final current = minutesOf((end ? draft.endsAt : draft.startsAt) ?? '');
    final picked = await showTimePicker(
      context: context,
      initialTime: current == null
          ? TimeOfDay(hour: end ? 18 : 9, minute: 0)
          : TimeOfDay(hour: current ~/ 60, minute: current % 60),
      helpText: end ? 'Termina' : 'Empieza',
    );
    if (picked == null) return;
    final time = timeOf(picked.hour * 60 + picked.minute);
    _controller.update(
      (d) => end
          ? d.copyWith(endsAt: () => time)
          : d.copyWith(startsAt: () => time),
    );
  }

  Future<void> _submit() async {
    final state = ref.read(eventFormProvider(widget.args));
    final draft = state.draft;
    if (!_controller.validate()) return;
    if (draft.isDayOff && !_controller.isEditing) {
      final preview = state.preview;
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('¿Publicamos el día sin clase?'),
          content: Text(
            preview == null
                ? 'Se suspenden las clases de esos días y avisamos a las familias.'
                : '${preview.classesText ?? ''} ${preview.recipientsText()}'
                      .trim(),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Volver'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Publicar y avisar'),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
    }
    final messenger = ScaffoldMessenger.of(context);
    final router = GoRouter.of(context);
    final event = await _controller.submit();
    if (event == null) return;
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          _controller.isEditing ? 'Listo, guardado.' : 'Listo, publicado.',
        ),
      ),
    );
    if (router.canPop()) {
      router.pop(event);
    } else {
      router.go('/eventos/${event.id}');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final state = ref.watch(eventFormProvider(widget.args));
    final draft = state.draft;
    final errors = state.errors;
    final options = ref.watch(eventOptionsProvider);
    final organization = ref.watch(currentOrganizationProvider).value;
    final groupTerm = organization?.term('group') ?? 'Grupo';
    final instructorTerm = organization?.term('instructor') ?? 'Técnico';
    final today = ref.watch(todayProvider);
    final editing = _controller.isEditing;
    final title = switch ((draft.isDayOff, editing)) {
      (true, false) => 'Nuevo día sin clase',
      (false, false) => 'Nuevo evento',
      (true, true) => 'Editar día sin clase',
      (false, true) => 'Editar evento',
    };

    final loaded = options.value;
    if (loaded == null) {
      return Scaffold(
        appBar: AppBar(title: Text(title)),
        body: Center(
          child: options.hasError
              ? Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(apiErrorMessage(options.error!)),
                    const SizedBox(height: 12),
                    FilledButton.tonal(
                      onPressed: () => ref.invalidate(eventOptionsProvider),
                      child: const Text('Reintentar'),
                    ),
                  ],
                )
              : const CircularProgressIndicator(),
        ),
      );
    }

    final categories = loaded.categories[draft.kind] ?? const [];

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          if (draft.isDayOff)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Text(
                'Las clases de esos días se suspenden solas y avisamos a las '
                'familias.',
                style: theme.textTheme.bodyMedium,
              ),
            ),
          _Section(
            title: 'Tipo',
            error: errors['category'],
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final option in categories)
                  ChoiceChip(
                    avatar: Icon(
                      categoryIcon(draft.kind, option.value),
                      size: 18,
                    ),
                    label: Text(option.label),
                    selected: draft.category == option.value,
                    onSelected: (_) {
                      _controller.selectCategory(option);
                      final suggested = ref
                          .read(eventFormProvider(widget.args))
                          .draft
                          .title;
                      if (_title.text != suggested) _title.text = suggested;
                    },
                  ),
              ],
            ),
          ),
          TextField(
            controller: _title,
            maxLength: 120,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              labelText: 'Título',
              hintText: draft.isDayOff
                  ? 'Ej.: Vacaciones de invierno'
                  : 'Ej.: Torneo Apertura Sub-10',
              errorText: errors['title'],
            ),
            onChanged: (value) =>
                _controller.update((d) => d.copyWith(title: value)),
          ),
          const SizedBox(height: 8),
          _Section(
            title: 'Cuándo',
            error: errors['starts_on'] ?? errors['ends_on'],
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _PickerButton(
                        icon: Icons.calendar_today_outlined,
                        label: _manyDays ? 'Desde' : 'Fecha',
                        value: draft.startsOn == null
                            ? 'Elegir'
                            : formatShortDay(draft.startsOn!, today),
                        onPressed: () => _pickDate(end: false),
                      ),
                    ),
                    if (_manyDays) ...[
                      const SizedBox(width: 8),
                      Expanded(
                        child: _PickerButton(
                          icon: Icons.event_outlined,
                          label: 'Hasta',
                          value: draft.endsOn == null
                              ? 'Elegir'
                              : formatShortDay(draft.endsOn!, today),
                          onPressed: () => _pickDate(end: true),
                        ),
                      ),
                    ],
                  ],
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Varios días'),
                  value: _manyDays,
                  onChanged: (value) {
                    setState(() => _manyDays = value);
                    // Al activarlo, arranca con dos días (se cambia con "Hasta").
                    _controller.update(
                      (d) => d.copyWith(
                        endsOn: () => value && d.startsOn != null
                            ? DateTime(
                                d.startsOn!.year,
                                d.startsOn!.month,
                                d.startsOn!.day + 1,
                              )
                            : null,
                      ),
                    );
                  },
                ),
                if (!draft.isDayOff) ...[
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Todo el día'),
                    value: draft.allDay,
                    onChanged: (value) =>
                        _controller.update((d) => d.copyWith(allDay: value)),
                  ),
                  if (!draft.allDay)
                    Row(
                      children: [
                        Expanded(
                          child: _PickerButton(
                            icon: Icons.schedule,
                            label: 'Empieza',
                            value: draft.startsAt ?? 'Elegir',
                            onPressed: () => _pickTime(end: false),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _PickerButton(
                            icon: Icons.schedule,
                            label: 'Termina',
                            value: draft.endsAt ?? 'Elegir',
                            onPressed: () => _pickTime(end: true),
                          ),
                        ),
                      ],
                    ),
                  if (errors['starts_at'] ?? errors['ends_at']
                      case final error?)
                    _ErrorText(error),
                ],
              ],
            ),
          ),
          if (!draft.isDayOff) ...[
            DropdownButtonFormField<int>(
              initialValue: _otherPlace ? -1 : draft.venueId ?? 0,
              decoration: InputDecoration(
                labelText: 'Lugar',
                errorText: errors['venue_id'] ?? errors['place'],
              ),
              items: [
                const DropdownMenuItem(value: 0, child: Text('Sin lugar')),
                for (final venue in loaded.venues)
                  DropdownMenuItem(value: venue.id, child: Text(venue.name)),
                const DropdownMenuItem(value: -1, child: Text('Otro lugar…')),
              ],
              onChanged: (value) {
                setState(() => _otherPlace = value == -1);
                _controller.update(
                  (d) => d.copyWith(
                    venueId: () => value == null || value <= 0 ? null : value,
                  ),
                );
              },
            ),
            if (_otherPlace)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: TextField(
                  controller: _place,
                  maxLength: 120,
                  decoration: const InputDecoration(
                    labelText: 'Dónde',
                    hintText: 'Ej.: Club Olimpia, Mariscal López 1234',
                  ),
                  onChanged: (value) =>
                      _controller.update((d) => d.copyWith(place: value)),
                ),
              ),
            const SizedBox(height: 8),
          ],
          TextField(
            controller: _description,
            maxLength: 1000,
            minLines: 2,
            maxLines: 5,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              labelText: 'Detalles (opcional)',
              hintText: draft.isDayOff
                  ? 'Ej.: Volvemos el lunes 21.'
                  : 'Ej.: Llevar la camiseta blanca y agua.',
              errorText: errors['description'],
            ),
            onChanged: (value) =>
                _controller.update((d) => d.copyWith(description: value)),
          ),
          const SizedBox(height: 8),
          _Section(
            title: '¿Para quién?',
            error: errors['group_ids'] ?? errors['for_everyone'],
            child: AudiencePicker(
              options: loaded,
              groupTerm: groupTerm,
              forEveryone: draft.forEveryone,
              selected: draft.groupIds,
              onEveryone: (value) =>
                  _controller.update((d) => d.copyWith(forEveryone: value)),
              onGroups: (ids) =>
                  _controller.update((d) => d.copyWith(groupIds: ids)),
            ),
          ),
          if (draft.isDayOff && (state.preview?.canWaiveCharge ?? false))
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('No cobrar las clases suspendidas'),
              subtitle: const Text(
                'Solo en las temporadas que cobran por día de entrenamiento.',
              ),
              value: draft.waiveCharge,
              onChanged: (value) =>
                  _controller.update((d) => d.copyWith(waiveCharge: value)),
            ),
          EventPreviewCard(state: state, instructorTerm: instructorTerm),
          if (editing)
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Avisar del cambio'),
              subtitle: const Text(
                'Les llega un aviso si cambió la fecha, la hora, el lugar o '
                'para quién es.',
              ),
              value: state.notify,
              onChanged: _controller.setNotify,
            ),
          if (state.error != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: _ErrorText(state.error!),
            ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: state.submitting ? null : _submit,
            icon: state.submitting
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.send_outlined),
            label: Text(editing ? 'Guardar cambios' : 'Publicar y avisar'),
          ),
        ],
      ),
    );
  }
}

/// "¿Para quién?": todo el club o grupos por disciplina.
class AudiencePicker extends StatelessWidget {
  const AudiencePicker({
    required this.options,
    required this.groupTerm,
    required this.forEveryone,
    required this.selected,
    required this.onEveryone,
    required this.onGroups,
    super.key,
  });

  final EventOptions options;
  final String groupTerm;
  final bool forEveryone;
  final Set<int> selected;
  final ValueChanged<bool> onEveryone;
  final ValueChanged<Set<int>> onGroups;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final byProgram = options.groupsByProgram;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (options.canTargetOrganization)
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Todo el club'),
            value: forEveryone,
            onChanged: onEveryone,
          ),
        if (!forEveryone) ...[
          if (options.groups.isEmpty)
            Text(
              'No tenés grupos para elegir.',
              style: theme.textTheme.bodyMedium,
            ),
          for (final entry in byProgram.entries) ...[
            if (byProgram.length > 1 || entry.value.length > 1)
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                tristate: true,
                title: Text(
                  entry.key.isEmpty ? '$groupTerm: todas' : entry.key,
                  style: theme.textTheme.titleSmall,
                ),
                value: _programValue(entry.value),
                onChanged: (_) {
                  final ids = {for (final g in entry.value) g.id};
                  final all = ids.every(selected.contains);
                  onGroups(
                    all ? selected.difference(ids) : {...selected, ...ids},
                  );
                },
              ),
            Padding(
              padding: const EdgeInsets.only(left: 8, bottom: 8),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final group in entry.value)
                    FilterChip(
                      label: Text(group.name),
                      selected: selected.contains(group.id),
                      onSelected: (value) => onGroups(
                        value
                            ? {...selected, group.id}
                            : ({...selected}..remove(group.id)),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ],
      ],
    );
  }

  bool? _programValue(List<EventGroup> groups) {
    final count = groups.where((g) => selected.contains(g.id)).length;
    if (count == 0) return false;
    return count == groups.length ? true : null;
  }
}

/// A cuántos les llega y qué clases se suspenden.
class EventPreviewCard extends StatefulWidget {
  const EventPreviewCard({
    required this.state,
    required this.instructorTerm,
    super.key,
  });

  final EventFormState state;
  final String instructorTerm;

  @override
  State<EventPreviewCard> createState() => _EventPreviewCardState();
}

class _EventPreviewCardState extends State<EventPreviewCard> {
  var _open = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final state = widget.state;
    final preview = state.preview;
    if (preview == null &&
        !state.previewLoading &&
        state.previewError == null) {
      return const SizedBox.shrink();
    }
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.campaign_outlined),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('Al publicar', style: theme.textTheme.titleSmall),
                ),
                if (state.previewLoading)
                  const SizedBox.square(
                    dimension: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            if (state.previewError != null && preview == null)
              Text(state.previewError!)
            else if (preview != null) ...[
              Text(
                preview.recipientsText(instructorTerm: widget.instructorTerm),
              ),
              if (preview.classesText case final classes?) ...[
                const SizedBox(height: 4),
                Text(classes),
                if (preview.items.isNotEmpty)
                  TextButton.icon(
                    style: TextButton.styleFrom(
                      alignment: Alignment.centerLeft,
                      padding: EdgeInsets.zero,
                    ),
                    onPressed: () => setState(() => _open = !_open),
                    icon: Icon(_open ? Icons.expand_less : Icons.expand_more),
                    label: Text(
                      _open ? 'Ocultar las clases' : 'Ver las clases',
                    ),
                  ),
                if (_open)
                  for (final item in preview.items)
                    Text(
                      '${weekdayShort(item.date.weekday)} '
                      '${item.date.day}/${item.date.month} '
                      '${item.startsAt} · ${item.group.name}',
                      style: theme.textTheme.bodySmall,
                    ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child, this.error});

  final String title;
  final Widget child;
  final String? error;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          header: true,
          child: Text(title, style: Theme.of(context).textTheme.titleSmall),
        ),
        const SizedBox(height: 8),
        child,
        if (error != null) _ErrorText(error!),
      ],
    ),
  );
}

class _ErrorText extends StatelessWidget {
  const _ErrorText(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 4),
    child: Text(
      text,
      style: TextStyle(color: Theme.of(context).colorScheme.error),
    ),
  );
}

class _PickerButton extends StatelessWidget {
  const _PickerButton({
    required this.icon,
    required this.label,
    required this.value,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final String value;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => OutlinedButton(
    onPressed: onPressed,
    style: OutlinedButton.styleFrom(
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
    ),
    child: Row(
      children: [
        Icon(icon, size: 18),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: Theme.of(context).textTheme.labelSmall),
              Text(value),
            ],
          ),
        ),
      ],
    ),
  );
}
