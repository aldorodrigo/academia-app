import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/utils/launcher.dart';
import '../../../core/utils/format.dart';
import '../../../core/utils/validators.dart';
import '../../organizations/data/organization_repository.dart';
import '../data/models.dart';
import '../data/step_controllers.dart';
import 'step_scaffold.dart';

/// Paso 4: quién da las clases. El admin puede ser uno ("Yo también doy
/// clases"); a los demás se los invita con sus categorías y se comparte el link.
class InstructorsStepScreen extends ConsumerStatefulWidget {
  const InstructorsStepScreen({super.key});

  @override
  ConsumerState<InstructorsStepScreen> createState() =>
      _InstructorsStepScreenState();
}

class _InstructorsStepScreenState extends ConsumerState<InstructorsStepScreen>
    with StepEntry {
  bool _saving = false;

  /// "Yo también doy clases" encendido sin categorías elegidas todavía: se
  /// guarda recién al elegir la primera (no se dan todas por defecto).
  bool _choosingMine = false;

  InstructorsStepController get _controller =>
      ref.read(instructorsStepProvider.notifier);

  Future<void> _setTeaching(bool teaches, List<int> groupIds) async {
    final error = await _controller.setTeaching(
      teaches: teaches,
      groupIds: groupIds,
    );
    if (!mounted) return;
    if (error != null) {
      showMessage(context, error);
    } else {
      setState(() => _choosingMine = false);
    }
  }

  /// Encender pide elegir; apagar deja de dar clases.
  void _toggleTeaching(InstructorsStep step, bool on) {
    if (on && step.groups.isNotEmpty) {
      setState(() => _choosingMine = true);
    } else if (on) {
      _setTeaching(true, const []);
    } else {
      setState(() => _choosingMine = false);
      if (step.team.teaches) _setTeaching(false, const []);
    }
  }

  void _toggleMine(
    InstructorsStep step,
    int groupId,
    bool selected,
    String group,
  ) {
    final ids = [
      for (final id in step.team.myGroupIds)
        if (id != groupId) id,
      if (selected) groupId,
    ];
    if (ids.isEmpty) {
      showMessage(
        context,
        'Elegí al menos ${gendered(group, 'un', 'una')} ${group.toLowerCase()}; '
        'si no das clases, apagá «Yo también doy clases».',
      );
      return;
    }
    _setTeaching(true, ids);
  }

  Future<void> _invite(InstructorsStep step, String role) async {
    final invited = await showModalBottomSheet<SetupInstructor>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _InviteSheet(groups: step.groups, role: role),
    );
    if (invited == null || !mounted) return;
    await _share(invited, invited.link, role);
  }

  Future<void> _share(SetupInstructor instructor, String? link, String role) =>
      showDialog<void>(
        context: context,
        builder: (_) => _ShareInvitationDialog(
          instructor: instructor,
          link: link,
          role: role,
        ),
      );

  Future<void> _resend(SetupInstructor instructor, String role) async {
    try {
      final link = await _controller.resend(instructor);
      if (mounted) await _share(instructor, link, role);
    } catch (error) {
      if (mounted) showMessage(context, apiErrorMessage(error));
    }
  }

  Future<void> _editGroups(
    SetupInstructor instructor,
    InstructorsStep step,
  ) async {
    final selected = await showDialog<List<int>>(
      context: context,
      builder: (_) => _GroupsDialog(
        title: instructor.name,
        groups: step.groups,
        initial: instructor.groups.map((g) => g.id).toList(),
      ),
    );
    if (selected == null) return;
    final error = await _controller.setGroups(instructor, selected);
    if (error != null && mounted) showMessage(context, error);
  }

  Future<void> _revoke(SetupInstructor instructor) async {
    final error = await _controller.revoke(instructor);
    if (mounted) showMessage(context, error ?? 'Invitación borrada.');
  }

  Future<void> _continue() async {
    setState(() => _saving = true);
    await finishStep(() async => null);
    if (mounted) setState(() => _saving = false);
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(instructorsStepProvider);
    final organization = ref.watch(currentOrganizationProvider).value;
    final role = organization?.term('instructor') ?? 'Técnico';
    final groupTerm = organization?.term('group') ?? 'Categoría';
    final plural = pluralize(role);
    final step = async.value;
    final anyone =
        step != null && (step.team.teaches || step.team.instructors.isNotEmpty);

    return StepScaffold(
      stepKey: 'instructors',
      title: '¿Quién da las clases?',
      description:
          '${gendered(role, 'Los', 'Las')} ${plural.toLowerCase()} toman '
          'asistencia desde la app y ven a sus '
          '${pluralize(organization?.term('student') ?? 'Alumno').toLowerCase()}. '
          '${gendered(role, 'Los', 'Las')} invitás con su correo.',
      primaryLabel: 'Listo, seguir',
      onPrimary: anyone ? _continue : null,
      loading: _saving,
      secondaryLabel: anyone ? null : 'Lo hago después',
      onSecondary: () => skipStep('instructors'),
      children: [
        async.when(
          loading: () => const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (error, _) => Text(apiErrorMessage(error)),
          data: (step) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SwitchListTile(
                key: const Key('i-teach'),
                contentPadding: EdgeInsets.zero,
                title: const Text('Yo también doy clases'),
                subtitle: const Text(
                  'Tomás asistencia desde la app con tu cuenta.',
                ),
                value: step.team.teaches || _choosingMine,
                onChanged: (on) => _toggleTeaching(step, on),
              ),
              if ((step.team.teaches || _choosingMine) &&
                  step.groups.isNotEmpty) ...[
                Text(
                  step.team.myGroupIds.isEmpty
                      ? '¿Cuáles das vos? Elegí al menos '
                            '${gendered(groupTerm, 'un', 'una')} '
                            '${groupTerm.toLowerCase()}.'
                      : '¿Cuáles das vos?',
                  key: const Key('i-teach-hint'),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: step.team.myGroupIds.isEmpty
                        ? Theme.of(context).colorScheme.error
                        : null,
                  ),
                ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    for (final group in step.groups)
                      FilterChip(
                        label: Text(group.name),
                        selected: step.team.myGroupIds.contains(group.id),
                        onSelected: (selected) =>
                            _toggleMine(step, group.id, selected, groupTerm),
                      ),
                  ],
                ),
              ],
              StepSection(plural),
              if (step.team.instructors.isEmpty)
                Text(
                  'Todavía no invitaste a ${gendered(role, 'ningún', 'ninguna')} '
                  '${role.toLowerCase()}.',
                ),
              for (final instructor in step.team.instructors)
                Card(
                  child: ListTile(
                    title: Text(instructor.name),
                    subtitle: Text(
                      [
                        instructor.status.label,
                        if (instructor.groups.isNotEmpty)
                          instructor.groups.map((g) => g.name).join(', ')
                        else
                          'Sin asignar',
                      ].join(' · '),
                    ),
                    trailing: PopupMenuButton<String>(
                      tooltip: 'Opciones de ${instructor.name}',
                      onSelected: (action) => switch (action) {
                        'groups' => _editGroups(instructor, step),
                        'resend' => _resend(instructor, role),
                        _ => _revoke(instructor),
                      },
                      itemBuilder: (_) => [
                        if (instructor.userId != null)
                          const PopupMenuItem(
                            value: 'groups',
                            child: Text('Cambiar lo que da'),
                          ),
                        if (instructor.invitationId != null) ...[
                          const PopupMenuItem(
                            value: 'resend',
                            child: Text('Reenviar invitación'),
                          ),
                          const PopupMenuItem(
                            value: 'revoke',
                            child: Text('Borrar invitación'),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                key: const Key('invite-instructor'),
                icon: const Icon(Icons.person_add_alt_1_outlined),
                label: Text(
                  'Invitar a ${gendered(role, 'un', 'una')} ${role.toLowerCase()}',
                ),
                onPressed: () => _invite(step, role),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _InviteSheet extends ConsumerStatefulWidget {
  const _InviteSheet({required this.groups, required this.role});

  final List<SetupGroup> groups;
  final String role;

  @override
  ConsumerState<_InviteSheet> createState() => _InviteSheetState();
}

class _InviteSheetState extends ConsumerState<_InviteSheet> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _contact = TextEditingController();
  final _groups = <int>{};
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _contact.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final invited = await ref
          .read(instructorsStepProvider.notifier)
          .invite(
            name: _name.text,
            contact: _contact.text,
            groupIds: _groups.toList(),
          );
      if (mounted) Navigator.pop(context, invited);
    } catch (error) {
      setState(() {
        _loading = false;
        _error = apiErrorMessage(error);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        16,
        16,
        16 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Invitar a ${gendered(widget.role, 'un', 'una')} '
                '${widget.role.toLowerCase()}',
                style: theme.textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              TextFormField(
                key: const Key('invite-name'),
                controller: _name,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Nombre y apellido',
                ),
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Ingresá el nombre.' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                key: const Key('invite-contact'),
                controller: _contact,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'Celular o correo',
                  hintText: '0981 123 456',
                  helperText: 'Le mandás la invitación para crear su cuenta.',
                ),
                validator: (v) => v == null || v.trim().isEmpty
                    ? 'Ingresá el celular o el correo.'
                    : validateLogin(v),
              ),
              if (widget.groups.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text('¿Qué da?', style: theme.textTheme.titleSmall),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    for (final group in widget.groups)
                      FilterChip(
                        label: Text(group.name),
                        selected: _groups.contains(group.id),
                        onSelected: (selected) => setState(
                          () => selected
                              ? _groups.add(group.id)
                              : _groups.remove(group.id),
                        ),
                      ),
                  ],
                ),
              ],
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
              ],
              const SizedBox(height: 16),
              FilledButton(
                key: const Key('invite-send'),
                onPressed: _loading ? null : _submit,
                child: _loading
                    ? const SizedBox.square(
                        dimension: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Invitar'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ShareInvitationDialog extends ConsumerWidget {
  const _ShareInvitationDialog({
    required this.instructor,
    required this.link,
    required this.role,
  });

  final SetupInstructor instructor;
  final String? link;
  final String role;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final organization = ref.watch(currentOrganizationProvider).value;
    return AlertDialog(
      title: Text(
        instructor.phone != null && link != null
            ? 'Invitación lista'
            : 'Invitación enviada',
      ),
      content: Text(
        link == null
            ? 'Ya está: le asignamos lo que da.'
            : instructor.phone != null
            ? 'Mandale el link por WhatsApp al '
                  '${formatPhone(instructor.phone!)} (vale 14 días).'
            : 'Le mandamos un correo a ${instructor.email}. También podés '
                  'mandarle el link por WhatsApp (vale 14 días).',
      ),
      actions: [
        if (link != null) ...[
          TextButton(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: link!));
              if (context.mounted) showMessage(context, 'Link copiado.');
            },
            child: const Text('Copiar link'),
          ),
          FilledButton.icon(
            icon: const Icon(Icons.chat_outlined),
            label: const Text('WhatsApp'),
            onPressed: () => ref.read(urlLauncherProvider)(
              whatsappUri(
                invitationMessage(
                  name: instructor.name,
                  organization: organization?.name ?? '',
                  role: role,
                  link: link!,
                ),
                phone: instructor.phone,
              ),
            ),
          ),
        ],
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Listo'),
        ),
      ],
    );
  }
}

class _GroupsDialog extends StatefulWidget {
  const _GroupsDialog({
    required this.title,
    required this.groups,
    required this.initial,
  });

  final String title;
  final List<SetupGroup> groups;
  final List<int> initial;

  @override
  State<_GroupsDialog> createState() => _GroupsDialogState();
}

class _GroupsDialogState extends State<_GroupsDialog> {
  late final _selected = {...widget.initial};

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.title),
    content: Wrap(
      spacing: 8,
      runSpacing: 4,
      children: [
        for (final group in widget.groups)
          FilterChip(
            label: Text(group.name),
            selected: _selected.contains(group.id),
            onSelected: (selected) => setState(
              () => selected
                  ? _selected.add(group.id)
                  : _selected.remove(group.id),
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
        onPressed: () => Navigator.pop(context, _selected.toList()),
        child: const Text('Listo'),
      ),
    ],
  );
}
