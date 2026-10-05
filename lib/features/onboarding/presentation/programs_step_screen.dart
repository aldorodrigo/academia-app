import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../organizations/data/organization_repository.dart';
import '../data/models.dart';
import '../data/step_controllers.dart';
import 'step_scaffold.dart';
import 'terminology_suggestion_sheet.dart';

/// Paso 1: "¿Qué enseñan?" — disciplinas sugeridas como chips, "Otra" y cómo
/// se arman las categorías de cada una.
class ProgramsStepScreen extends ConsumerStatefulWidget {
  const ProgramsStepScreen({super.key});

  @override
  ConsumerState<ProgramsStepScreen> createState() => _ProgramsStepScreenState();
}

class _ProgramsStepScreenState extends ConsumerState<ProgramsStepScreen>
    with StepEntry {
  bool _saving = false;

  Future<void> _save() async {
    setState(() => _saving = true);
    await finishStep(
      () => ref.read(programsStepProvider.notifier).save(),
      // Una academia que enseña fútbol: ¿categorías, técnicos y canchas?
      beforeNext: (after) async {
        final suggestion = after?.terminologySuggestion;
        if (suggestion != null && mounted) {
          // Ya se guardó: el botón de atrás no sigue cargando.
          setState(() => _saving = false);
          await showTerminologySuggestion(context, suggestion);
        }
      },
    );
    if (mounted) setState(() => _saving = false);
  }

  Future<void> _addCustom(String programTerm) async {
    final result = await showDialog<(String, GroupCriterion)>(
      context: context,
      builder: (_) => _CustomProgramDialog(term: programTerm),
    );
    if (result == null || !mounted) return;
    final error = ref
        .read(programsStepProvider.notifier)
        .addCustom(result.$1, result.$2);
    if (error != null) showMessage(context, error);
  }

  @override
  Widget build(BuildContext context) {
    final step = ref.watch(programsStepProvider);
    final organization = ref.watch(currentOrganizationProvider).value;
    final program = organization?.term('program') ?? 'Disciplina';
    final group = organization?.term('group') ?? 'Categoría';
    final value = step.value;
    final controller = ref.read(programsStepProvider.notifier);
    final ready =
        value != null &&
        (value.selected.isNotEmpty || value.existing.isNotEmpty);

    return StepScaffold(
      stepKey: 'programs',
      title: '¿Qué enseñan?',
      description:
          'Elegí ${gendered(program, 'uno o más', 'una o más')} '
          '${pluralize(program).toLowerCase()}. '
          'Después podés agregar ${gendered(program, 'otros', 'otras')}.',
      primaryLabel: value != null && value.selected.isEmpty && ready
          ? 'Seguir'
          : 'Guardar y seguir',
      onPrimary: ready ? _save : null,
      loading: _saving,
      children: [
        step.when(
          loading: () => const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (error, _) => Text(apiErrorMessage(error)),
          data: (step) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (step.existing.isNotEmpty) ...[
                const StepSection('Ya cargadas'),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    for (final p in step.existing)
                      Chip(
                        avatar: const Icon(Icons.check, size: 18),
                        label: Text(p.name),
                      ),
                  ],
                ),
              ],
              StepSection(step.existing.isEmpty ? 'Elegí' : 'Agregar'),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  for (final name in step.options)
                    FilterChip(
                      label: Text(name),
                      selected: step.selected.containsKey(name),
                      onSelected: (_) => controller.toggle(name),
                    ),
                  ActionChip(
                    avatar: const Icon(Icons.add, size: 18),
                    label: Text(gendered(program, 'Otro', 'Otra')),
                    onPressed: () => _addCustom(program),
                  ),
                ],
              ),
              if (step.selected.isNotEmpty) ...[
                StepSection(
                  '¿Cómo se arman ${gendered(group, 'los', 'las')} '
                  '${pluralize(group).toLowerCase()}?',
                  help:
                      'Por edad (Sub-8, Sub-10…) o por nivel (Inicial, Avanzado…). '
                      'Lo sugerimos según la disciplina.',
                ),
                for (final entry in step.selected.entries)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        Expanded(child: Text(entry.key)),
                        SegmentedButton<GroupCriterion>(
                          showSelectedIcon: false,
                          segments: [
                            for (final c in GroupCriterion.values)
                              ButtonSegment(value: c, label: Text(c.label)),
                          ],
                          selected: {entry.value},
                          onSelectionChanged: (s) =>
                              controller.setCriterion(entry.key, s.first),
                        ),
                      ],
                    ),
                  ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _CustomProgramDialog extends StatefulWidget {
  const _CustomProgramDialog({required this.term});

  final String term;

  @override
  State<_CustomProgramDialog> createState() => _CustomProgramDialogState();
}

class _CustomProgramDialogState extends State<_CustomProgramDialog> {
  final _name = TextEditingController();
  GroupCriterion _criterion = GroupCriterion.level;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        '${gendered(widget.term, 'Otro', 'Otra')} ${widget.term.toLowerCase()}',
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            key: const Key('custom-program'),
            controller: _name,
            autofocus: true,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(labelText: 'Nombre'),
          ),
          const SizedBox(height: 16),
          SegmentedButton<GroupCriterion>(
            showSelectedIcon: false,
            segments: [
              for (final c in GroupCriterion.values)
                ButtonSegment(value: c, label: Text(c.label)),
            ],
            selected: {_criterion},
            onSelectionChanged: (s) => setState(() => _criterion = s.first),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, (_name.text, _criterion)),
          child: const Text('Agregar'),
        ),
      ],
    );
  }
}
