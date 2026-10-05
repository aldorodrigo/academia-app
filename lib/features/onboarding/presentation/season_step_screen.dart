import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/utils/format.dart';
import '../../organizations/data/organization_repository.dart';
import '../data/models.dart';
import '../data/step_controllers.dart';
import 'step_scaffold.dart';

/// Paso 3: temporada y cuotas, en tres páginas (temporada, cuotas, revisar)
/// con las mismas preguntas y cálculos que el asistente del panel.
class SeasonStepScreen extends ConsumerStatefulWidget {
  const SeasonStepScreen({super.key});

  @override
  ConsumerState<SeasonStepScreen> createState() => _SeasonStepScreenState();
}

class _SeasonStepScreenState extends ConsumerState<SeasonStepScreen>
    with StepEntry {
  int _page = 0;
  bool _saving = false;

  SeasonStepController get _controller => ref.read(seasonStepProvider.notifier);

  Future<void> _next() async {
    final step = ref.read(seasonStepProvider).value;
    if (step == null) return;
    final error = switch (_page) {
      0 => step.draft.validateSeason(multiplePrograms: step.multiplePrograms),
      1 => step.draft.validatePlan(),
      _ => null,
    };
    if (error != null) {
      showMessage(context, error);
      return;
    }
    if (_page < 2) {
      setState(() => _page++);
      // Los montos no piden el resumen al tipearlos: se pide al pasar.
      await _controller.refreshPreview();
      return;
    }
    setState(() => _saving = true);
    await finishStep(_controller.save);
    if (mounted) setState(() => _saving = false);
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(seasonStepProvider);
    final organization = ref.watch(currentOrganizationProvider).value;
    final step = async.value;
    const titles = ['¿Cuándo es la temporada?', '¿Cuánto se cobra?', 'Revisá'];
    const descriptions = [
      'Puede haber varias a la vez (por disciplina, colonias de verano…).',
      'Las cuotas se crean solas para cada inscripto.',
      'Si algo no está bien, volvé atrás y cambialo.',
    ];

    return PopScope(
      canPop: _page == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _page > 0) setState(() => _page--);
      },
      child: StepScaffold(
        stepKey: 'season',
        title: titles[_page],
        description: descriptions[_page],
        primaryLabel: _page < 2 ? 'Siguiente' : 'Crear temporada',
        onPrimary: step == null ? null : _next,
        loading: _saving,
        secondaryLabel: _page > 0 ? 'Atrás' : null,
        onSecondary: () => setState(() => _page--),
        children: [
          async.when(
            loading: () => const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (error, _) => Text(apiErrorMessage(error)),
            data: (step) => switch (_page) {
              0 => _SeasonPage(step: step, controller: _controller),
              1 => _FeesPage(
                step: step,
                controller: _controller,
                groupTerm: organization?.term('group') ?? 'Categoría',
              ),
              _ => _ReviewPage(step: step),
            },
          ),
        ],
      ),
    );
  }
}

class _SeasonPage extends StatelessWidget {
  const _SeasonPage({required this.step, required this.controller});

  final SeasonStep step;
  final SeasonStepController controller;

  Future<void> _pick(
    BuildContext context,
    DateTime? initial,
    ValueChanged<DateTime> onPicked,
  ) async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: initial ?? now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 3),
    );
    if (date != null) onPicked(date);
  }

  @override
  Widget build(BuildContext context) {
    final draft = step.draft;
    final kinds = step.preview?.kinds ?? const <SeasonKindOption>[];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (step.multiplePrograms) ...[
          const StepSection('¿Para qué disciplinas?'),
          Wrap(
            spacing: 8,
            children: [
              for (final program in step.programs)
                FilterChip(
                  label: Text(program.name),
                  selected: draft.programIds.contains(program.id),
                  onSelected: (_) => controller.toggleProgram(program.id),
                ),
            ],
          ),
        ],
        const StepSection('¿Cuánto dura?'),
        RadioGroup<String>(
          groupValue: draft.kind,
          onChanged: (v) => v == null ? null : controller.setKind(v),
          child: Column(
            children: [
              for (final kind in kinds)
                RadioListTile<String>(
                  contentPadding: EdgeInsets.zero,
                  value: kind.value,
                  title: Text(kind.label),
                  subtitle: Text(kind.example),
                ),
            ],
          ),
        ),
        const StepSection(
          'Fechas',
          help: 'El fin se calcula solo; podés cambiarlo.',
        ),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                key: const Key('starts-on'),
                icon: const Icon(Icons.event),
                label: Text(
                  draft.startsOn == null
                      ? 'Empieza'
                      : 'Empieza ${formatDate(draft.startsOn!)}',
                ),
                onPressed: () =>
                    _pick(context, draft.startsOn, controller.setStartsOn),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                key: const Key('ends-on'),
                icon: const Icon(Icons.event_available),
                label: Text(
                  draft.endsOn == null
                      ? 'Termina'
                      : 'Termina ${formatDate(draft.endsOn!)}',
                ),
                onPressed: () =>
                    _pick(context, draft.endsOn, controller.setEndsOn),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        TextFormField(
          // Se vuelve a armar cuando cambia el nombre sugerido (duración o inicio).
          key: ValueKey(
            'season-name-${draft.kind}-${draft.startsOn}-${step.preview?.suggestedName}',
          ),
          initialValue: draft.name,
          decoration: const InputDecoration(
            labelText: 'Nombre',
            helperText: 'Sugerido según la duración; podés cambiarlo.',
          ),
          onChanged: controller.setName,
        ),
      ],
    );
  }
}

class _FeesPage extends StatelessWidget {
  const _FeesPage({
    required this.step,
    required this.controller,
    required this.groupTerm,
  });

  final SeasonStep step;
  final SeasonStepController controller;
  final String groupTerm;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final draft = step.draft;
    final frequency = draft.feeFrequency;
    // Mes, quincena, semana o día: las palabras las arma la API.
    final terms = step.preview?.terms;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const StepSection('¿Cada cuánto se cobra?'),
        RadioGroup<FeeFrequency?>(
          groupValue: frequency,
          onChanged: controller.setFrequency,
          child: Column(
            children: [
              for (final f in FeeFrequency.values)
                RadioListTile<FeeFrequency?>(
                  contentPadding: EdgeInsets.zero,
                  value: f,
                  title: Text(f.label),
                  subtitle: Text(f.description),
                ),
              const RadioListTile<FeeFrequency?>(
                contentPadding: EdgeInsets.zero,
                value: null,
                title: Text('No cobro cuotas por ahora'),
                subtitle: Text('Se configura después desde el panel.'),
              ),
            ],
          ),
        ),
        if (frequency == FeeFrequency.daily) ...[
          const StepSection('¿Qué días se cuentan?'),
          RadioGroup<String>(
            groupValue: draft.dailyBasis,
            onChanged: (v) => v == null ? null : controller.setDailyBasis(v),
            child: Column(
              children: [
                for (final entry in dailyBasisOptions(groupTerm).entries)
                  RadioListTile<String>(
                    contentPadding: EdgeInsets.zero,
                    value: entry.key,
                    title: Text(entry.value.$1),
                    subtitle: Text(
                      entry.key == 'entrenamiento' || terms == null
                          ? entry.value.$2
                          : '${entry.value.$2} ${terms.basisAfter}',
                    ),
                  ),
              ],
            ),
          ),
          const StepSection('¿Cómo se agrupa?'),
          RadioGroup<String>(
            groupValue: draft.dailyGrouping,
            onChanged: (v) => v == null ? null : controller.setDailyGrouping(v),
            child: Column(
              children: [
                for (final entry in dailyGroupingOptions.entries)
                  RadioListTile<String>(
                    contentPadding: EdgeInsets.zero,
                    value: entry.key,
                    title: Text(entry.value),
                    subtitle: entry.key == 'mes'
                        ? const Text(
                            'Recomendado: una sola cuota y un solo pago por mes.',
                          )
                        : null,
                  ),
              ],
            ),
          ),
        ],
        if (frequency != null) ...[
          const StepSection('Montos'),
          _AmountField(
            key: const Key('fee-amount'),
            label: frequency.amountLabel,
            initial: draft.feeAmount,
            onChanged: controller.setFeeAmount,
          ),
          const SizedBox(height: 12),
          _AmountField(
            key: const Key('enrollment-fee'),
            label: 'Inscripción (opcional)',
            initial: draft.enrollmentFeeAmount,
            onChanged: controller.setEnrollmentFee,
          ),
          if (step.eligibleGroups.length > 1) ...[
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(
                '¿Hay ${pluralize(groupTerm).toLowerCase()} que pagan distinto?',
              ),
              value: draft.groupAmounts.isNotEmpty,
              onChanged: (on) => on
                  ? controller.setGroupAmount(
                      step.eligibleGroups.first.id,
                      draft.feeAmount ?? 0,
                    )
                  : controller.clearGroupAmounts(),
            ),
            if (draft.groupAmounts.isNotEmpty)
              for (final group in step.eligibleGroups)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Expanded(child: Text(group.name)),
                      SizedBox(
                        width: 160,
                        child: _AmountField(
                          label: 'Monto',
                          initial: draft.groupAmounts[group.id],
                          onChanged: (v) =>
                              controller.setGroupAmount(group.id, v),
                          hint: draft.feeAmount == null
                              ? null
                              : formatMoney(draft.feeAmount!),
                        ),
                      ),
                    ],
                  ),
                ),
          ],
          // Como se piensa: "¿Qué día del mes vence?", "¿Qué día de la semana?".
          StepSection(terms?.dueQuestion ?? '¿Cuándo vence?'),
          DropdownButtonFormField<int>(
            key: ValueKey('due-${terms?.unit}-${draft.dueDays}'),
            initialValue: draft.dueDays,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Vence'),
            items: [
              for (final (days, label) in _dueOptions(terms, draft.dueDays))
                DropdownMenuItem(value: days, child: Text(label)),
            ],
            onChanged: (v) => v == null ? null : controller.setDueDays(v),
          ),
          if (step.preview?.dueExample != null) ...[
            const SizedBox(height: 4),
            Text(step.preview!.dueExample!, style: theme.textTheme.bodySmall),
          ],
          if (draft.chargesAfterPeriod && terms != null) ...[
            const StepSection('¿Cuándo se crean las cuotas de cada inscripto?'),
            Text(
              '${terms.issueAfter}, con las clases '
              '${draft.dailyBasis == 'asistencia' ? 'a las que vino según la asistencia' : 'que se dieron'}.',
            ),
          ],
          if (!draft.chargesAfterPeriod) ...[
            const StepSection('¿Cuándo se crean las cuotas de cada inscripto?'),
            RadioGroup<bool>(
              groupValue: draft.issueUpfront,
              onChanged: (v) =>
                  v == null ? null : controller.setIssueUpfront(v),
              child: Column(
                children: [
                  RadioListTile<bool>(
                    contentPadding: EdgeInsets.zero,
                    value: false,
                    title: Text(
                      '${terms?.issueNow ?? 'Al empezar cada cuota'} (recomendado)',
                    ),
                    subtitle: terms == null ? null : Text(terms.issueNowHelp),
                  ),
                  RadioListTile<bool>(
                    contentPadding: EdgeInsets.zero,
                    value: true,
                    title: const Text('Todas juntas al inscribir'),
                    subtitle: terms == null
                        ? null
                        : Text(terms.issueUpfrontHelp),
                  ),
                ],
              ),
            ),
          ],
          // Agrupado por día o por clase asistida no hay "mitad de…".
          if (terms?.midway != null && !draft.chargesAfterPeriod)
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              title: const Text('Opciones avanzadas'),
              children: [
                DropdownButtonFormField<String>(
                  key: ValueKey('mid-${terms!.unit}'),
                  initialValue: draft.midPeriod,
                  isExpanded: true,
                  decoration: InputDecoration(labelText: terms.midway),
                  items: [
                    for (final (value, label)
                        in terms.midPeriodOptions.isEmpty
                            ? midPeriodOptions.entries.map(
                                (e) => (e.key, e.value),
                              )
                            : terms.midPeriodOptions)
                      DropdownMenuItem(value: value, child: Text(label)),
                  ],
                  onChanged: (v) =>
                      v == null ? null : controller.setMidPeriod(v),
                ),
                const SizedBox(height: 8),
              ],
            ),
        ],
      ],
    );
  }
}

class _AmountField extends StatelessWidget {
  const _AmountField({
    super.key,
    required this.label,
    required this.initial,
    required this.onChanged,
    this.hint,
  });

  final String label;
  final int? initial;
  final ValueChanged<int?> onChanged;
  final String? hint;

  @override
  Widget build(BuildContext context) => TextFormField(
    initialValue: initial == null || initial == 0 ? '' : '$initial',
    keyboardType: TextInputType.number,
    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
    decoration: InputDecoration(
      labelText: label,
      prefixText: '₲ ',
      hintText: hint,
    ),
    onChanged: (text) => onChanged(parseAmount(text)),
  );
}

class _ReviewPage extends StatelessWidget {
  const _ReviewPage({required this.step});

  final SeasonStep step;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final preview = step.preview;
    if (preview == null) return const LinearProgressIndicator();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 8),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              preview.summary,
              key: const Key('season-summary'),
              style: theme.textTheme.bodyLarge,
            ),
          ),
        ),
        if (preview.examples.isNotEmpty) ...[
          const StepSection('Primeras cuotas de cada inscripto'),
          Table(
            columnWidths: const {2: IntrinsicColumnWidth()},
            children: [
              TableRow(
                children: [
                  for (final header in ['Período', 'Vence', 'Monto'])
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(header, style: theme.textTheme.labelLarge),
                    ),
                ],
              ),
              for (final example in preview.examples)
                TableRow(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Text(capitalize(example.period)),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(example.dueOn),
                          // "para los que se inscriben hoy" (la API da la fecha real).
                          if (example.dueNote != null)
                            Text(
                              example.dueNote!,
                              style: theme.textTheme.bodySmall,
                            ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Text(example.amount, textAlign: TextAlign.right),
                    ),
                  ],
                ),
            ],
          ),
        ],
      ],
    );
  }
}

String capitalize(String text) =>
    text.isEmpty ? text : '${text[0].toUpperCase()}${text.substring(1)}';

/// Opciones del vencimiento: las de la API según la unidad; sin resumen
/// todavía, el valor actual en días.
List<(int, String)> _dueOptions(BillingTerms? terms, int current) {
  final options = terms?.dueOptions ?? const <(int, String)>[];
  if (options.any((o) => o.$1 == current)) return options;
  return [
    ...options,
    (
      current,
      current == 0
          ? 'El día que empieza'
          : '${countOf(current, 'día', 'días')} después',
    ),
  ]..sort((a, b) => a.$1.compareTo(b.$1));
}
