import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/utils/format.dart';
import '../../organizations/data/organization_repository.dart';
import '../data/models.dart';
import '../data/step_controllers.dart';
import 'step_scaffold.dart';
import 'weekly_time_editor.dart';

final _ages = [for (var age = 3; age <= 18; age++) age];

/// Paso 2, en dos pantallas: primero qué categorías tienen (generadas por edad
/// o por nivel) y después cuándo entrena cada una (sus días y horarios, el lugar).
class GroupsStepScreen extends ConsumerStatefulWidget {
  const GroupsStepScreen({super.key});

  @override
  ConsumerState<GroupsStepScreen> createState() => _GroupsStepScreenState();
}

class _GroupsStepScreenState extends ConsumerState<GroupsStepScreen>
    with StepEntry {
  /// 0 = la lista, 1 = los horarios.
  int _page = 0;
  bool _saving = false;
  final _capacity = TextEditingController();

  GroupsStepController get _controller => ref.read(groupsStepProvider.notifier);

  @override
  void initState() {
    super.initState();
    // El cupo del borrador (de acá, de otro dispositivo o del panel) vuelve al
    // campo; lo que se escribe va al estado y de ahí al borrador.
    ref.listenManual(groupsStepProvider, (_, next) {
      final capacity = next.value?.capacity;
      if (parseAmount(_capacity.text) != capacity) {
        _capacity.text = capacity?.toString() ?? '';
      }
    }, fireImmediately: true);
  }

  @override
  void dispose() {
    _capacity.dispose();
    super.dispose();
  }

  void _toSchedules() {
    final error = ref.read(groupsStepProvider).value?.validateList();
    if (error != null) {
      showMessage(context, error);
      return;
    }
    setState(() => _page = 1);
  }

  Future<void> _create() async {
    final step = ref.read(groupsStepProvider).value;
    if (step == null) return;
    setState(() => _saving = true);
    final programName = step.program?.name;
    final error = await _controller.save();
    if (!mounted) return;
    setState(() => _saving = false);
    if (error != null) {
      showMessage(context, error);
      return;
    }
    final next = ref.read(groupsStepProvider).value;
    if (next?.programId != step.programId && next?.program != null) {
      // Queda otra disciplina sin categorías: se sigue en esta pantalla.
      setState(() => _page = 0);
      showMessage(
        context,
        'Listo, $programName. Ahora ${next!.program!.name}.',
      );
      return;
    }
    await _continue();
  }

  Future<void> _continue() async {
    setState(() => _saving = true);
    await finishStep(() async => null);
    if (mounted) setState(() => _saving = false);
  }

  Future<String?> _askName({
    required String title,
    String initial = '',
    String? helper,
    String? hint,
  }) async {
    final controller = TextEditingController(text: initial);
    final name = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: TextField(
          key: const Key('new-group'),
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(
            labelText: 'Nombre',
            helperText: helper,
            hintText: hint,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, controller.text),
            child: const Text('Listo'),
          ),
        ],
      ),
    );
    controller.dispose();
    return name == null || name.trim().isEmpty ? null : name.trim();
  }

  /// "Nuevo lugar": nombre, dirección y sus canchas (opcional).
  Future<void> _newSite(String space) async {
    final result = await showDialog<(String, String, List<String>)>(
      context: context,
      builder: (_) => _SiteDialog(space: space),
    );
    if (result == null || !mounted) return;
    final error = await _controller.createSite(
      name: result.$1,
      address: result.$2,
      spaces: result.$3,
    );
    if (error != null && mounted) showMessage(context, error);
  }

  Future<void> _addSpace(Site site, String space) async {
    final name = await _askName(
      title: 'En ${site.name}',
      hint: '$space ${site.spaces.length + 1}',
    );
    if (name == null) return;
    final error = await _controller.addSpace(site, name);
    if (error != null && mounted) showMessage(context, error);
  }

  Future<void> _existingTime(SetupGroup group) async {
    final choice = await showDialog<WeeklyTimeChoice>(
      context: context,
      builder: (_) => WeeklyTimeDialog(
        title: 'Horario de ${group.name}',
        initial: WeeklyTime.of(group.schedules),
      ),
    );
    if (choice?.time == null) return;
    final error = await _controller.updateTime(group, choice!.time!);
    if (mounted) showMessage(context, error ?? 'Horario guardado.');
  }

  Future<void> _delete(SetupGroup group) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('¿Borrar ${group.name}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Borrar'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final error = await _controller.delete(group);
    if (error != null && mounted) showMessage(context, error);
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(groupsStepProvider);
    final organization = ref.watch(currentOrganizationProvider).value;
    final term = organization?.term('group') ?? 'Categoría';
    final plural = pluralize(term).toLowerCase();
    // Concordancia con el término del club: "cada una" (categoría) / "cada uno" (grupo).
    String g(String masculine, String feminine) =>
        gendered(term, masculine, feminine);
    final step = async.value;
    final drafts = step?.drafts ?? const <GroupDraft>[];
    final hasAny = step != null && step.groups.isNotEmpty;
    final missing = step?.withoutSchedule ?? 0;

    final (String label, VoidCallback? action) = switch (_page) {
      0 when drafts.isEmpty => ('Seguir', hasAny ? _continue : null),
      0 => ('Siguiente: horarios', _toSchedules),
      _ => (
        [
          'Crear ${drafts.length} ${drafts.length == 1 ? term.toLowerCase() : plural}',
          if (missing > 0) '($missing sin horario)',
        ].join(' '),
        _create,
      ),
    };

    return PopScope(
      canPop: _page == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _page > 0) setState(() => _page = 0);
      },
      child: StepScaffold(
        stepKey: 'groups',
        title: _page == 0
            ? '¿Qué $plural tienen?'
            : '¿Cuándo entrena cada ${term.toLowerCase()}?',
        description: _page == 0
            ? 'Las familias eligen ${g('el', 'la')} ${term.toLowerCase()} al inscribirse. '
                  'Te sugerimos una lista: cambiá lo que haga falta.'
            : 'Elegí los días y el horario de cada ${g('uno', 'una')}. Si entrenan igual, '
                  'cargá ${g('uno', 'una')} y tocá «Copiar a ${g('todos', 'todas')}».',
        primaryLabel: label,
        onPrimary: step == null ? null : action,
        loading: _saving,
        secondaryLabel: _page == 1 ? 'Atrás' : null,
        onSecondary: () => setState(() => _page = 0),
        children: [
          async.when(
            loading: () => const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (error, _) => Text(apiErrorMessage(error)),
            data: (step) => step.programs.isEmpty
                ? const Padding(
                    padding: EdgeInsets.only(top: 16),
                    child: Text('Primero elegí qué enseñan (paso 1).'),
                  )
                : _page == 0
                ? _list(step, term, plural)
                : _schedules(step, term),
          ),
        ],
      ),
    );
  }

  /// Pantalla 1: la disciplina, las que ya existen y las nuevas.
  Widget _list(GroupsStep step, String term, String plural) {
    final program = step.program!;
    final existing = step.groupsOf(program.id);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (step.programs.length > 1) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              for (final p in step.programs)
                ChoiceChip(
                  avatar: step.groupsOf(p.id).isNotEmpty
                      ? const Icon(Icons.check, size: 18)
                      : null,
                  label: Text(p.name),
                  selected: p.id == program.id,
                  onSelected: (_) => _controller.selectProgram(p.id),
                ),
            ],
          ),
        ],
        if (existing.isNotEmpty) ...[
          StepSection(
            '${gendered(term, 'Ya creados', 'Ya creadas')} en ${program.name}',
          ),
          for (final group in existing)
            Card(
              child: ListTile(
                title: Text(group.name),
                subtitle: Text(describeSchedules(group.schedules)),
                trailing: PopupMenuButton<String>(
                  tooltip: 'Opciones de ${group.name}',
                  onSelected: (action) =>
                      action == 'time' ? _existingTime(group) : _delete(group),
                  itemBuilder: (_) => [
                    const PopupMenuItem(
                      value: 'time',
                      child: Text('Cambiar horario'),
                    ),
                    if (group.enrollmentsCount == 0)
                      const PopupMenuItem(
                        value: 'delete',
                        child: Text('Borrar'),
                      ),
                  ],
                ),
              ),
            ),
          if (step.drafts.isEmpty)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                icon: const Icon(Icons.auto_awesome_outlined),
                label: Text('Agregar más $plural'),
                onPressed: _controller.suggest,
              ),
            ),
        ],
        if (existing.isEmpty || step.drafts.isNotEmpty) ...[
          StepSection(
            existing.isEmpty
                ? '${gendered(term, 'Nuevos', 'Nuevas')} en ${program.name}'
                : 'Agregar',
            help: step.byAge
                ? 'Por edad: la que cumplen en el año de la temporada.'
                : 'Por nivel.',
          ),
          if (step.byAge) ...[
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<int>(
                    key: const Key('ages-from'),
                    initialValue: step.agesFrom,
                    decoration: const InputDecoration(labelText: 'Desde'),
                    items: [
                      for (final age in _ages)
                        DropdownMenuItem(value: age, child: Text('$age años')),
                    ],
                    onChanged: (v) => _controller.setAges(from: v),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<int>(
                    key: ValueKey('ages-to-${step.agesTo}'),
                    initialValue: step.agesTo,
                    decoration: const InputDecoration(labelText: 'Hasta'),
                    items: [
                      for (final age in _ages)
                        DropdownMenuItem(value: age, child: Text('$age años')),
                    ],
                    onChanged: (v) => _controller.setAges(to: v),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SegmentedButton<int>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(value: 1, label: Text('De a 1 año')),
                ButtonSegment(value: 2, label: Text('De a 2 años')),
              ],
              selected: {step.agesSpan},
              onSelectionChanged: (s) => _controller.setAges(span: s.first),
            ),
          ],
          const SizedBox(height: 8),
          for (var i = 0; i < step.drafts.length; i++)
            Card(
              child: ListTile(
                title: Text(step.drafts[i].name),
                subtitle: step.drafts[i].detail == null
                    ? null
                    : Text(step.drafts[i].detail!),
                onTap: () async {
                  final name = await _askName(
                    title: 'Nombre',
                    initial: step.drafts[i].name,
                    helper: step.drafts[i].detail,
                  );
                  if (name != null) _controller.renameDraft(i, name);
                },
                trailing: IconButton(
                  tooltip: 'Quitar ${step.drafts[i].name}',
                  icon: const Icon(Icons.close),
                  onPressed: () => _controller.removeDraft(i),
                ),
              ),
            ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              icon: const Icon(Icons.add),
              label: Text('Agregar ${gendered(term, 'otro', 'otra')}'),
              onPressed: () async {
                final name = await _askName(
                  title: 'Agregar',
                  hint: step.byAge ? 'Sub-18' : 'Competición',
                );
                if (name != null) _controller.addDraft(name);
              },
            ),
          ),
          if (step.drafts.isNotEmpty) ...[
            StepSection(
              'Cupo',
              help: 'Opcional: cuántos entran en cada ${term.toLowerCase()}.',
            ),
            TextField(
              key: const Key('capacity'),
              controller: _capacity,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(labelText: 'Cupo'),
              onChanged: (v) => _controller.setCapacity(parseAmount(v)),
            ),
          ],
        ],
      ],
    );
  }

  /// Pantalla 2: los días y horarios de cada una, y el lugar.
  Widget _schedules(GroupsStep step, String term) {
    final theme = Theme.of(context);

    final space =
        ref.read(currentOrganizationProvider).value?.term('space') ?? 'Cancha';
    final spaces = pluralize(space).toLowerCase();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Los lugares (con sus canchas) primero: cada horario elige su cancha.
        StepSection(
          '¿Dónde entrenan?',
          help: 'Opcional. Un lugar puede tener varias $spaces.',
        ),
        for (final site in step.sites)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.place_outlined),
            title: Text(site.name),
            subtitle: Text(
              [
                if (site.address != null && site.address!.isNotEmpty)
                  site.address!,
                if (site.spaces.length > 1 ||
                    (site.spaces.isNotEmpty &&
                        site.spaces.first.name != site.name))
                  site.spaces.map((s) => s.name).join(', '),
              ].join(' · '),
            ),
            trailing: IconButton(
              tooltip:
                  'Agregar ${gendered(space, 'un', 'una')} '
                  '${space.toLowerCase()} en ${site.name}',
              icon: const Icon(Icons.add),
              onPressed: () => _addSpace(site, space),
            ),
          ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            key: const Key('new-site'),
            icon: const Icon(Icons.add_location_alt_outlined),
            label: const Text('Nuevo lugar'),
            onPressed: () => _newSite(space),
          ),
        ),
        const SizedBox(height: 8),
        for (var i = 0; i < step.drafts.length; i++)
          Card(
            key: ValueKey('schedule-$i'),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          step.drafts[i].name,
                          style: theme.textTheme.titleMedium,
                        ),
                      ),
                      if (step.drafts[i].withoutSchedule)
                        Text(
                          'Falta el horario',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.error,
                          ),
                        )
                      else if (step.drafts.length > 1)
                        TextButton(
                          onPressed: () {
                            _controller.copySlotsToAll(i);
                            showMessage(
                              context,
                              'Horario de ${step.drafts[i].name} copiado a '
                              '${gendered(term, 'todos', 'todas')}.',
                            );
                          },
                          child: Text(
                            'Copiar a ${gendered(term, 'todos', 'todas')}',
                          ),
                        ),
                    ],
                  ),
                  for (var j = 0; j < step.drafts[i].slots.length; j++)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                WeeklyTimeEditor(
                                  key: ValueKey('slot-$i-$j'),
                                  value: step.drafts[i].slots[j],
                                  onChanged: (time) =>
                                      _controller.setSlot(i, j, time),
                                ),
                                if (step.spaces.isNotEmpty) ...[
                                  const SizedBox(height: 8),
                                  DropdownButtonFormField<int?>(
                                    key: ValueKey(
                                      'space-$i-$j-${step.drafts[i].slots[j].venueId}',
                                    ),
                                    initialValue:
                                        step.drafts[i].slots[j].venueId,
                                    isExpanded: true,
                                    decoration: InputDecoration(
                                      labelText: space,
                                    ),
                                    items: [
                                      DropdownMenuItem(
                                        value: null,
                                        child: Text(
                                          'Sin ${space.toLowerCase()}',
                                        ),
                                      ),
                                      for (final option in step.spaces)
                                        DropdownMenuItem(
                                          value: option.id,
                                          child: Text(option.label),
                                        ),
                                    ],
                                    onChanged: (id) => _controller.setSlot(
                                      i,
                                      j,
                                      step.drafts[i].slots[j].copyWith(
                                        venueId: id,
                                        clearVenue: id == null,
                                      ),
                                    ),
                                  ),
                                ],
                                // Choques: misma cancha, mismo día y hora.
                                for (final warning
                                    in step.conflicts['$i-$j'] ?? const [])
                                  Padding(
                                    padding: const EdgeInsets.only(top: 6),
                                    child: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Icon(
                                          Icons.warning_amber_rounded,
                                          size: 18,
                                          color: theme.colorScheme.error,
                                        ),
                                        const SizedBox(width: 6),
                                        Expanded(
                                          child: Text(
                                            warning,
                                            style: theme.textTheme.bodySmall
                                                ?.copyWith(
                                                  color:
                                                      theme.colorScheme.error,
                                                ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          if (step.drafts[i].slots.length > 1)
                            IconButton(
                              tooltip: 'Quitar este horario',
                              icon: const Icon(Icons.delete_outline),
                              onPressed: () => _controller.removeSlot(i, j),
                            ),
                        ],
                      ),
                    ),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      icon: const Icon(Icons.add),
                      label: const Text('Otro horario'),
                      onPressed: () => _controller.addSlot(i),
                    ),
                  ),
                ],
              ),
            ),
          ),
        const SizedBox(height: 8),
        Text(
          'Quién da cada ${gendered(term, 'uno', 'una')} lo elegís en el paso de '
          '${pluralize(ref.read(currentOrganizationProvider).value?.term('instructor') ?? 'Técnico').toLowerCase()}.',
          style: theme.textTheme.bodySmall,
        ),
      ],
    );
  }
}

class _SiteDialog extends StatefulWidget {
  const _SiteDialog({required this.space});

  final String space;

  @override
  State<_SiteDialog> createState() => _SiteDialogState();
}

class _SiteDialogState extends State<_SiteDialog> {
  final _name = TextEditingController();
  final _address = TextEditingController();
  final _spaces = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    _address.dispose();
    _spaces.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final plural = pluralize(widget.space);
    return AlertDialog(
      title: const Text('Nuevo lugar'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            key: const Key('site-name'),
            controller: _name,
            autofocus: true,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Lugar',
              hintText: 'Polideportivo, Cancha del club…',
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _address,
            decoration: const InputDecoration(labelText: 'Dirección'),
          ),
          const SizedBox(height: 8),
          TextField(
            key: const Key('site-spaces'),
            controller: _spaces,
            decoration: InputDecoration(
              labelText: '$plural (opcional)',
              helperText:
                  'Separadas por coma: ${widget.space} 1, ${widget.space} 2. '
                  'Vacío si tiene una sola.',
              helperMaxLines: 2,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () {
            if (_name.text.trim().isEmpty) return;
            Navigator.pop(context, (
              _name.text.trim(),
              _address.text.trim(),
              [
                for (final name in _spaces.text.split(','))
                  if (name.trim().isNotEmpty) name.trim(),
              ],
            ));
          },
          child: const Text('Agregar'),
        ),
      ],
    );
  }
}
