import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/api_client.dart';
import '../../../core/utils/clock.dart';
import '../../../core/utils/launcher.dart';
import '../../../core/utils/validators.dart';
import '../../organizations/data/organization_repository.dart';
import '../data/enrollment_repository.dart';
import '../data/models.dart';
import '../data/request_form.dart';
import 'place_picker.dart';
import '../../../core/vocabulary/vocabulary.dart';
import '../../../core/vocabulary/gender_choice.dart';

/// "Cargar alumno" (quien puede crear alumnos, ej. el admin desde el celular):
/// alta directa con la categoría sugerida y su tutor, y la invitación del tutor
/// para mandar por WhatsApp.
class AddStudentScreen extends ConsumerStatefulWidget {
  const AddStudentScreen({super.key});

  @override
  ConsumerState<AddStudentScreen> createState() => _AddStudentScreenState();
}

class _AddStudentScreenState extends ConsumerState<AddStudentScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firstName = TextEditingController();
  final _lastName = TextEditingController();
  final _birthDate = TextEditingController();
  final _document = TextEditingController();
  final _guardianFirstName = TextEditingController();
  final _guardianLastName = TextEditingController();
  final _guardianPhone = TextEditingController();
  final _guardianEmail = TextEditingController();

  Relationship _relationship = Relationship.mother;
  Gender? _gender;
  DateTime? _birth;
  int _optionIndex = 0;
  int? _groupId;
  bool _showGroupError = false;
  bool _sending = false;
  RegisteredStudent? _done;

  List<TextEditingController> get _controllers => [
    _firstName,
    _lastName,
    _birthDate,
    _document,
    _guardianFirstName,
    _guardianLastName,
    _guardianPhone,
    _guardianEmail,
  ];

  @override
  void dispose() {
    for (final controller in _controllers) {
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

  void _another() {
    for (final controller in _controllers) {
      controller.clear();
    }
    setState(() {
      _birth = null;
      _optionIndex = 0;
      _groupId = null;
      _relationship = Relationship.mother;
      _gender = null;
      _done = null;
    });
  }

  Future<void> _submit(EnrollmentOption? option) async {
    final groupId = _groupId ?? option?.defaultGroupId;
    final valid = _formKey.currentState!.validate();
    setState(() => _showGroupError = option != null && groupId == null);
    if (!valid || option == null || groupId == null || _birth == null) return;

    setState(() => _sending = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final done = await ref
          .read(enrollmentRepositoryProvider)
          .registerStudent(
            StudentRegistrationDraft(
              firstName: _firstName.text,
              lastName: _lastName.text,
              birthDate: _birth!,
              document: _document.text,
              seasonId: option.season.id,
              groupId: groupId,
              gender: _gender,
              guardian: GuardianDraft(
                firstName: _guardianFirstName.text,
                lastName: _guardianLastName.text,
                phone: _guardianPhone.text,
                email: _guardianEmail.text,
                relationship: _relationship,
              ),
            ),
          );
      if (mounted) setState(() => _done = done);
    } catch (error) {
      messenger.showSnackBar(SnackBar(content: Text(apiErrorMessage(error))));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final done = _done;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Cargar ${(ref.watch(currentOrganizationProvider).value?.word('student') ?? Word.of('Alumno')).lower}',
        ),
        leading: BackButton(onPressed: () => context.go('/inicio')),
      ),
      body: done != null
          ? _Done(done, onAnother: _another, gender: _gender)
          : _form(context),
    );
  }

  Widget _form(BuildContext context) {
    final theme = Theme.of(context);
    final today = ref.watch(todayProvider);
    final organization = ref.watch(currentOrganizationProvider).value;
    final group = organization?.word('group') ?? Word.of('Categoría');
    final student = organization?.word('student') ?? Word.of('Alumno');
    final guardian = organization?.word('guardian') ?? Word.of('Tutor');
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
          Text(student.word, style: theme.textTheme.titleMedium),
          TextFormField(
            controller: _firstName,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(labelText: 'Nombre'),
            validator: validateChildFirstName,
          ),
          TextFormField(
            controller: _lastName,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(labelText: 'Apellido'),
            validator: validateChildLastName,
          ),
          TextFormField(
            controller: _birthDate,
            keyboardType: TextInputType.datetime,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[\d/]')),
            ],
            decoration: const InputDecoration(
              labelText: 'Fecha de nacimiento',
              hintText: 'dd/mm/aaaa',
            ),
            onChanged: _birthDateChanged,
            validator: (value) => validateBirthDate(value, today),
          ),
          TextFormField(
            controller: _document,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Número de documento'),
            validator: validateDocument,
          ),
          const SizedBox(height: 16),
          PlacePicker(
            options: options,
            optionIndex: _optionIndex,
            groupId: _groupId,
            showError: _showGroupError,
            group: group,
            organization: organization?.org ?? Word.of('club'),
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
          GenderChoice(
            value: _gender,
            onChanged: (gender) => setState(() => _gender = gender),
          ),
          const SizedBox(height: 24),
          Text(guardian.word, style: theme.textTheme.titleMedium),
          TextFormField(
            controller: _guardianFirstName,
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(labelText: 'Nombre ${guardian.of()}'),
            validator: (value) => validateGuardianName(value, guardian),
          ),
          TextFormField(
            controller: _guardianLastName,
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(labelText: 'Apellido ${guardian.of()}'),
          ),
          TextFormField(
            controller: _guardianPhone,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(
              labelText: 'Celular (WhatsApp)',
              hintText: '0981 123 456',
            ),
            validator: validatePhone,
          ),
          TextFormField(
            controller: _guardianEmail,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(labelText: 'Correo (opcional)'),
            validator: validateOptionalEmail,
          ),
          const SizedBox(height: 8),
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
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _sending || (loaded?.isEmpty ?? false)
                ? null
                : () => _submit(option),
            child: _sending
                ? const SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text('Cargar ${student.lower}'),
          ),
        ],
      ),
    );
  }
}

/// Listo: el alumno y la invitación del tutor para mandar por WhatsApp.
class _Done extends ConsumerWidget {
  const _Done(this.done, {required this.onAnother, this.gender});

  final RegisteredStudent done;
  final VoidCallback onAnother;

  /// El que se cargó (o null): "Jugadora cargada".
  final Gender? gender;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final organization = ref.watch(currentOrganizationProvider).value;
    final student = organization?.word('student') ?? Word.of('Alumno');
    final guardian =
        done.guardianName ??
        (organization?.word('guardian') ?? Word.of('Tutor')).the();
    final whatsapp = done.whatsappUrl;
    final link = done.invitationLink;

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Icon(
          Icons.check_circle_outline,
          size: 56,
          color: theme.colorScheme.primary,
        ),
        const SizedBox(height: 16),
        Text(
          '${student.forPerson(gender)} '
          '${student.agree(gender, 'cargado', 'cargada')}',
          textAlign: TextAlign.center,
          style: theme.textTheme.headlineSmall,
        ),
        const SizedBox(height: 8),
        Text(
          '${done.fullName} quedó en ${done.place}.',
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          done.guardianHasAccount
              ? '$guardian ya usa Tuku: lo ve en la app.'
              : 'Mandale la invitación a $guardian para que vea sus clases y '
                    'sus cuotas en la app.',
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        if (whatsapp != null)
          FilledButton.icon(
            icon: const Icon(Icons.send_outlined),
            label: const Text('Mandar por WhatsApp'),
            onPressed: () => ref.read(urlLauncherProvider)(Uri.parse(whatsapp)),
          ),
        if (link != null)
          TextButton.icon(
            icon: const Icon(Icons.copy),
            label: const Text('Copiar el link'),
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: link));
              if (context.mounted) {
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(const SnackBar(content: Text('Link copiado.')));
              }
            },
          ),
        const SizedBox(height: 16),
        OutlinedButton(onPressed: onAnother, child: const Text('Cargar otro')),
        TextButton(
          onPressed: () => context.go('/inicio'),
          child: const Text('Volver al inicio'),
        ),
      ],
    );
  }
}
