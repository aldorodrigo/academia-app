import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/api_client.dart';
import '../../auth/data/session_controller.dart';
import '../data/models.dart';
import '../data/onboarding_controller.dart';

const _typeIcons = {
  'club': Icons.stadium_outlined,
  'academy': Icons.school_outlined,
  'school': Icons.account_balance_outlined,
  'parents_association': Icons.family_restroom_outlined,
};

const _termQuestions = {
  'student': '¿Cómo les dicen a los que entrenan?',
  'instructor': '¿Y a quienes enseñan?',
  'group': '¿Cómo se llaman los grupos?',
};

/// "Tu club": nombre, tipo y vocabulario. Al crearlo entra directo a la guía.
class ClubFormScreen extends ConsumerStatefulWidget {
  const ClubFormScreen({super.key});

  @override
  ConsumerState<ClubFormScreen> createState() => _ClubFormScreenState();
}

class _ClubFormScreenState extends ConsumerState<ClubFormScreen> {
  final _name = TextEditingController();
  final _slug = TextEditingController();
  final _nameFocus = FocusNode();
  bool _editingTerms = false;
  bool _editingSlug = false;
  bool _loading = false;
  String? _error;

  ClubFormController get _controller => ref.read(clubFormProvider.notifier);

  @override
  void initState() {
    super.initState();
    // El identificador se sugiere al terminar de escribir el nombre.
    _nameFocus.addListener(() {
      if (!_nameFocus.hasFocus && !_editingSlug) {
        _controller.checkSlug(_name.text);
      }
    });
  }

  @override
  void dispose() {
    _name.dispose();
    _slug.dispose();
    _nameFocus.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final draft = ref.read(clubFormProvider).value;
    if (draft != null && draft.slug == null && draft.name.trim().isNotEmpty) {
      await _controller.checkSlug(_name.text);
    }
    final error = await _controller.create();
    if (!mounted) return;
    if (error != null) {
      setState(() {
        _loading = false;
        _error = error;
      });
      return;
    }
    // La guía está en el inicio.
    context.go('/inicio');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final async = ref.watch(clubFormProvider);
    final templates = ref.watch(onboardingTemplatesProvider).value;
    final session = ref.watch(sessionControllerProvider).value;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tu club'),
        leading: (session?.organizations.isNotEmpty ?? false)
            ? BackButton(onPressed: () => context.go('/organizaciones'))
            : null,
        actions: [
          if (session?.organizations.isEmpty ?? true)
            IconButton(
              tooltip: 'Cerrar sesión',
              icon: const Icon(Icons.logout),
              onPressed: () =>
                  ref.read(sessionControllerProvider.notifier).logout(),
            ),
        ],
      ),
      body: SafeArea(
        child: async.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => Center(child: Text(apiErrorMessage(error))),
          data: (draft) => Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Contanos de tu club',
                      style: theme.textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Con esto armamos todo con las palabras que usan ustedes.',
                    ),
                    const SizedBox(height: 24),
                    TextField(
                      key: const Key('club-name'),
                      controller: _name,
                      focusNode: _nameFocus,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(
                        labelText: 'Nombre',
                        hintText: 'Club Jakare, Academia Ritmo…',
                      ),
                      onChanged: _controller.setName,
                      onSubmitted: (v) => _controller.checkSlug(v),
                    ),
                    const SizedBox(height: 8),
                    _SlugLine(
                      draft: draft,
                      editing: _editingSlug,
                      controller: _slug,
                      onEdit: () => setState(() {
                        _editingSlug = true;
                        _slug.text = draft.slug ?? '';
                      }),
                      onCheck: _controller.checkSlug,
                    ),
                    const SizedBox(height: 24),
                    Text('¿Qué es?', style: theme.textTheme.titleMedium),
                    const SizedBox(height: 8),
                    for (final type
                        in templates?.organizationTypes ??
                            const <OrganizationTypeOption>[])
                      Card(
                        clipBehavior: Clip.antiAlias,
                        shape: draft.type == type.value
                            ? RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                                side: BorderSide(
                                  color: theme.colorScheme.primary,
                                  width: 2,
                                ),
                              )
                            : null,
                        child: ListTile(
                          leading: Icon(
                            _typeIcons[type.value] ?? Icons.groups_outlined,
                          ),
                          title: Text(type.label),
                          subtitle: Text(type.description),
                          trailing: draft.type == type.value
                              ? Icon(
                                  Icons.check_circle,
                                  color: theme.colorScheme.primary,
                                )
                              : null,
                          onTap: () => _controller.setType(type.value),
                        ),
                      ),
                    const SizedBox(height: 16),
                    if (!_editingTerms)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.translate_outlined),
                        title: const Text('Así van a decir las pantallas'),
                        subtitle: Text(draft.termsSummary),
                        trailing: TextButton(
                          onPressed: () => setState(() => _editingTerms = true),
                          child: const Text('Cambiar'),
                        ),
                      )
                    else
                      for (final entry in _termQuestions.entries) ...[
                        Text(entry.value, style: theme.textTheme.titleSmall),
                        const SizedBox(height: 4),
                        Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          children: [
                            for (final option
                                in templates?.terminologyOptions[entry.key] ??
                                    const <String>[])
                              ChoiceChip(
                                label: Text(
                                  entry.key == 'group'
                                      ? option
                                      : pluralize(option),
                                ),
                                selected: draft.term(entry.key) == option,
                                onSelected: (_) =>
                                    _controller.setTerm(entry.key, option),
                              ),
                          ],
                        ),
                        const SizedBox(height: 12),
                      ],
                    if (_error != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        _error!,
                        style: TextStyle(color: theme.colorScheme.error),
                      ),
                    ],
                    const SizedBox(height: 24),
                    FilledButton(
                      key: const Key('create-club'),
                      onPressed: _loading || draft.name.trim().length < 3
                          ? null
                          : _create,
                      child: _loading
                          ? const SizedBox.square(
                              dimension: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Crear club'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// "Identificador: club-jakare · Cambiar". Va en el link de inscripción y no
/// se puede cambiar después.
class _SlugLine extends StatelessWidget {
  const _SlugLine({
    required this.draft,
    required this.editing,
    required this.controller,
    required this.onEdit,
    required this.onCheck,
  });

  final ClubDraft draft;
  final bool editing;
  final TextEditingController controller;
  final VoidCallback onEdit;
  final ValueChanged<String> onCheck;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final taken = draft.slugTaken == null
        ? null
        : '«${draft.slugTaken}» ya está en uso: te proponemos «${draft.slug}».';

    if (editing) {
      return TextField(
        key: const Key('club-slug'),
        controller: controller,
        decoration: InputDecoration(
          labelText: 'Identificador',
          helperText:
              taken ??
              'Va en el link de inscripción. No se puede cambiar después.',
          suffixIcon: IconButton(
            tooltip: 'Revisar',
            icon: const Icon(Icons.check),
            onPressed: () => onCheck(controller.text),
          ),
        ),
        onSubmitted: onCheck,
      );
    }

    if (draft.slug == null) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Identificador: ${draft.slug}',
                style: theme.textTheme.bodySmall,
              ),
            ),
            TextButton(onPressed: onEdit, child: const Text('Cambiar')),
          ],
        ),
        if (taken != null) Text(taken, style: theme.textTheme.bodySmall),
      ],
    );
  }
}
