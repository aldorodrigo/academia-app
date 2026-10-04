import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/api_client.dart';
import '../../../core/utils/clock.dart';
import '../../../core/utils/format.dart';
import '../../organizations/data/organization_repository.dart';
import '../data/enrollment_repository.dart';
import '../data/models.dart';
import '../data/request_form.dart';

/// El tutor pide la inscripción de un hijo: datos, dónde (la API sugiere la
/// categoría por edad) y ficha médica opcional. Queda en revisión del club.
class EnrollChildScreen extends ConsumerStatefulWidget {
  const EnrollChildScreen({super.key});

  @override
  ConsumerState<EnrollChildScreen> createState() => _EnrollChildScreenState();
}

class _EnrollChildScreenState extends ConsumerState<EnrollChildScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firstName = TextEditingController();
  final _lastName = TextEditingController();
  final _birthDate = TextEditingController();
  final _document = TextEditingController();
  final _notes = TextEditingController();
  final _bloodType = TextEditingController();
  final _allergies = TextEditingController();
  final _conditions = TextEditingController();
  final _medications = TextEditingController();
  final _emergencyName = TextEditingController();
  final _emergencyPhone = TextEditingController();

  Relationship _relationship = Relationship.mother;
  DateTime? _birth;
  int _optionIndex = 0;

  /// `null` = la que se elige sola (la sugerida o la única).
  int? _groupId;
  bool _showGroupError = false;
  bool _sending = false;
  EnrollmentRequest? _sent;

  @override
  void dispose() {
    for (final controller in [
      _firstName,
      _lastName,
      _birthDate,
      _document,
      _notes,
      _bloodType,
      _allergies,
      _conditions,
      _medications,
      _emergencyName,
      _emergencyPhone,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  void _birthDateChanged(String text) {
    final today = ref.read(todayProvider);
    final date = validateBirthDate(text, today) == null
        ? parseDayMonthYear(text)
        : null;
    if (date == _birth) return;
    setState(() {
      _birth = date;
      _optionIndex = 0;
      _groupId = null;
    });
  }

  Future<void> _pickBirthDate() async {
    final today = ref.read(todayProvider);
    final date = await showDatePicker(
      context: context,
      initialDate: _birth ?? DateTime(today.year - 8, today.month, today.day),
      firstDate: DateTime(today.year - 100),
      lastDate: today.subtract(const Duration(days: 1)),
      initialDatePickerMode: DatePickerMode.year,
    );
    if (date == null) return;
    _birthDate.text = formatDate(date);
    _birthDateChanged(_birthDate.text);
  }

  Future<void> _submit(EnrollmentOption? option) async {
    final groupId = _groupId ?? option?.defaultGroupId;
    final valid = _formKey.currentState!.validate();
    setState(() => _showGroupError = option != null && groupId == null);
    if (!valid || option == null || groupId == null || _birth == null) return;

    setState(() => _sending = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final request = await ref
          .read(enrollmentRepositoryProvider)
          .submit(
            EnrollmentRequestDraft(
              firstName: _firstName.text,
              lastName: _lastName.text,
              birthDate: _birth!,
              document: _document.text,
              relationship: _relationship,
              seasonId: option.season.id,
              groupId: groupId,
              notes: _notes.text,
              medical: MedicalDraft(
                bloodType: _bloodType.text,
                allergies: _allergies.text,
                conditions: _conditions.text,
                medications: _medications.text,
                emergencyContactName: _emergencyName.text,
                emergencyContactPhone: _emergencyPhone.text,
              ),
            ),
          );
      ref.invalidate(myEnrollmentRequestsProvider);
      if (mounted) setState(() => _sent = request);
    } catch (error) {
      messenger.showSnackBar(SnackBar(content: Text(apiErrorMessage(error))));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final sent = _sent;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Inscribir a un hijo'),
        leading: BackButton(onPressed: () => context.go('/inicio')),
      ),
      body: sent != null ? _Sent(sent) : _form(context),
    );
  }

  Widget _form(BuildContext context) {
    final today = ref.watch(todayProvider);
    final organization = ref.watch(currentOrganizationProvider).value;
    final groupTerm = organization?.term('group') ?? 'Categoría';
    final birth = _birth;
    final options = birth == null
        ? null
        : ref.watch(enrollmentOptionsProvider(birth));
    final loaded = options?.value;
    final option = loaded == null || loaded.isEmpty
        ? null
        : loaded[_optionIndex.clamp(0, loaded.length - 1)];

    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Completá los datos y el club revisa la solicitud. Te avisamos '
            'cuando la apruebe.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _firstName,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(labelText: 'Nombre'),
            validator: validateChildFirstName,
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _lastName,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(labelText: 'Apellido'),
            validator: validateChildLastName,
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _birthDate,
            keyboardType: TextInputType.datetime,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[\d/]')),
            ],
            decoration: InputDecoration(
              labelText: 'Fecha de nacimiento',
              hintText: 'dd/mm/aaaa',
              suffixIcon: IconButton(
                tooltip: 'Elegir en el calendario',
                icon: const Icon(Icons.calendar_month_outlined),
                onPressed: _pickBirthDate,
              ),
            ),
            onChanged: _birthDateChanged,
            validator: (value) => validateBirthDate(value, today),
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _document,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Documento (opcional)',
              helperText: 'Evita que quede cargado dos veces.',
            ),
            validator: validateDocument,
          ),
          const SizedBox(height: 16),
          Text('Sos su…', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 4),
          Wrap(
            spacing: 8,
            children: [
              for (final relationship in Relationship.values)
                ChoiceChip(
                  label: Text(relationship.label),
                  selected: _relationship == relationship,
                  onSelected: (_) =>
                      setState(() => _relationship = relationship),
                ),
            ],
          ),
          const SizedBox(height: 16),
          ..._where(context, options, option, groupTerm, today),
          const SizedBox(height: 8),
          ExpansionTile(
            title: const Text('Ficha médica (opcional)'),
            subtitle: const Text('La ven solo quienes cuidan a tu hijo.'),
            tilePadding: EdgeInsets.zero,
            childrenPadding: const EdgeInsets.only(bottom: 8),
            children: [
              TextFormField(
                controller: _bloodType,
                decoration: const InputDecoration(labelText: 'Grupo sanguíneo'),
              ),
              TextFormField(
                controller: _allergies,
                decoration: const InputDecoration(labelText: 'Alergias'),
              ),
              TextFormField(
                controller: _conditions,
                decoration: const InputDecoration(
                  labelText: 'Enfermedades o condiciones',
                ),
              ),
              TextFormField(
                controller: _medications,
                decoration: const InputDecoration(labelText: 'Medicación'),
              ),
              TextFormField(
                controller: _emergencyName,
                decoration: const InputDecoration(
                  labelText: 'Contacto de emergencia',
                ),
              ),
              TextFormField(
                controller: _emergencyPhone,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Celular de emergencia',
                ),
              ),
            ],
          ),
          TextFormField(
            controller: _notes,
            maxLines: 2,
            maxLength: 500,
            decoration: const InputDecoration(
              labelText: 'Algo que el club tenga que saber (opcional)',
            ),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _sending || (loaded?.isEmpty ?? false)
                ? null
                : () => _submit(option),
            child: _sending
                ? const SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Enviar solicitud'),
          ),
        ],
      ),
    );
  }

  /// Disciplina, temporada y categoría, cuando ya hay fecha de nacimiento.
  List<Widget> _where(
    BuildContext context,
    AsyncValue<List<EnrollmentOption>>? options,
    EnrollmentOption? option,
    String groupTerm,
    DateTime today,
  ) {
    final theme = Theme.of(context);
    if (options == null) {
      return [
        Text(
          'Con la fecha de nacimiento te sugerimos la ${groupTerm.toLowerCase()}.',
          style: theme.textTheme.bodySmall,
        ),
      ];
    }
    if (options.isLoading) return const [LinearProgressIndicator()];
    if (options.hasError) return [Text(apiErrorMessage(options.error!))];

    final loaded = options.value!;
    if (loaded.isEmpty || option == null) {
      return const [
        Text(
          'El club todavía no tiene inscripciones abiertas. Consultá con el club.',
        ),
      ];
    }

    final selected = _groupId ?? option.defaultGroupId;
    return [
      if (loaded.length > 1) ...[
        Text('¿En qué lo inscribís?', style: theme.textTheme.titleSmall),
        const SizedBox(height: 4),
        Wrap(
          spacing: 8,
          children: [
            for (final (index, o) in loaded.indexed)
              ChoiceChip(
                label: Text('${o.program.name} · ${o.season.name}'),
                selected: o == option,
                onSelected: (_) => setState(() {
                  _optionIndex = index;
                  _groupId = null;
                }),
              ),
          ],
        ),
        const SizedBox(height: 8),
      ],
      Text(
        '$groupTerm · ${option.program.name}',
        style: theme.textTheme.titleSmall,
      ),
      if (option.season.startsAfter(today))
        Text(
          '${option.season.name}: empieza el ${formatDate(option.season.startsOn!)}',
          style: theme.textTheme.bodySmall,
        ),
      if (option.groups.isEmpty)
        const Text('Todavía no hay categorías abiertas.'),
      RadioGroup<int>(
        groupValue: selected,
        onChanged: (id) => setState(() {
          _groupId = id;
          _showGroupError = false;
        }),
        child: Column(
          children: [
            for (final group in option.groups)
              RadioListTile<int>(
                contentPadding: EdgeInsets.zero,
                value: group.id,
                title: Text(group.name),
                subtitle: _groupDetails(group, option, theme),
              ),
          ],
        ),
      ),
      if (_showGroupError)
        Text(
          validateGroup(null)!,
          style: TextStyle(color: theme.colorScheme.error),
        ),
    ];
  }

  Widget? _groupDetails(
    GroupOption group,
    EnrollmentOption option,
    ThemeData theme,
  ) {
    final lines = [
      if (group.id == option.suggestedGroupId) 'Le corresponde por la edad',
      if (group.schedules.isNotEmpty)
        group.schedules
            .map((s) => '${weekdayShort(s.weekday)} ${s.startsAt}')
            .join(', '),
      if (group.full)
        'Completo: el club decide si hay lugar'
      else
        ?group.spotsLabel,
    ];
    return lines.isEmpty ? null : Text(lines.join(' · '));
  }
}

/// "Solicitud enviada", con lo que pasa después.
class _Sent extends StatelessWidget {
  const _Sent(this.request);

  final EnrollmentRequest request;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.mark_email_read_outlined,
              size: 56,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(height: 16),
            Text('Solicitud enviada', style: theme.textTheme.headlineSmall),
            const SizedBox(height: 8),
            Text(
              'Pediste lugar para ${request.child.firstName} en '
              '${request.placeLabel}. Te avisamos cuando el club la apruebe.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () => context.go('/inicio'),
              child: const Text('Volver al inicio'),
            ),
          ],
        ),
      ),
    );
  }
}
