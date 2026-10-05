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
import '../../students/data/students_repository.dart';
import 'place_picker.dart';

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
      ref
        ..invalidate(myEnrollmentRequestsProvider)
        ..invalidate(studentsProvider);
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
    final option = selectedOption(loaded, _optionIndex);

    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Completá los datos: tu hijo ya puede ir a las clases y el club '
            'confirma la inscripción.',
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
            decoration: const InputDecoration(labelText: 'Número de documento'),
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
          PlacePicker(
            options: options,
            optionIndex: _optionIndex,
            groupId: _groupId,
            showError: _showGroupError,
            groupTerm: groupTerm,
            today: today,
            onOptionChanged: (index) => setState(() {
              _optionIndex = index;
              _groupId = null;
            }),
            onGroupChanged: (id) => setState(() {
              _groupId = id;
              _showGroupError = false;
            }),
          ),
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
}

/// "Listo": ya puede ir a clases; falta (o no) que el club la confirme.
class _Sent extends StatelessWidget {
  const _Sent(this.request);

  final EnrollmentRequest request;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final name = request.child.firstName;
    final confirmed = request.isApproved;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              confirmed
                  ? Icons.check_circle_outline
                  : Icons.how_to_reg_outlined,
              size: 56,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(height: 16),
            Text(
              confirmed ? 'Inscripción confirmada' : 'Solicitud enviada',
              style: theme.textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              confirmed
                  ? '$name ya está en ${request.placeLabel}. Sus cuotas ya '
                        'aparecen en el estado de cuenta.'
                  : '$name ya puede ir a las clases de ${request.placeLabel}. '
                        'Te avisamos cuando el club confirme la inscripción.',
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
