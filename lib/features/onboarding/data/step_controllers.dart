import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../attendance/data/models.dart';
import '../../organizations/data/organization_repository.dart';
import 'models.dart';
import 'onboarding_controller.dart';
import 'onboarding_repository.dart';

// ---------------------------------------------------------------------------
// Paso 1: ¿Qué enseñan?

class ProgramsStep {
  const ProgramsStep({
    required this.existing,
    required this.templates,
    this.selected = const {},
  });

  final List<SetupProgram> existing;
  final List<ProgramTemplate> templates;

  /// Disciplinas nuevas elegidas, con su criterio.
  final Map<String, GroupCriterion> selected;

  bool exists(String name) =>
      existing.any((p) => p.name.toLowerCase() == name.toLowerCase());

  /// Sugeridas que todavía no existen, más las que agregó a mano.
  List<String> get options => [
    for (final t in templates)
      if (!exists(t.name)) t.name,
    for (final name in selected.keys)
      if (!templates.any((t) => t.name == name)) name,
  ];

  ProgramsStep copyWith({Map<String, GroupCriterion>? selected}) =>
      ProgramsStep(
        existing: existing,
        templates: templates,
        selected: selected ?? this.selected,
      );
}

class ProgramsStepController extends AsyncNotifier<ProgramsStep> {
  OnboardingRepository get _repository =>
      ref.read(onboardingRepositoryProvider);

  @override
  Future<ProgramsStep> build() async {
    final templates = await ref.watch(onboardingTemplatesProvider.future);
    return ProgramsStep(
      existing: await _repository.programs(),
      templates: templates.programs,
    );
  }

  ProgramsStep? get _step => state.value;

  void toggle(String name) {
    final step = _step;
    if (step == null) return;
    final selected = {...step.selected};
    if (selected.containsKey(name)) {
      selected.remove(name);
    } else {
      final template = step.templates.where((t) => t.name == name);
      selected[name] = template.isEmpty
          ? GroupCriterion.level
          : template.first.criterion;
    }
    state = AsyncData(step.copyWith(selected: selected));
  }

  /// "Otra": una disciplina que no está en las sugeridas.
  String? addCustom(String name, GroupCriterion criterion) {
    final step = _step;
    final clean = name.trim();
    if (step == null) return null;
    if (clean.isEmpty) return 'Ingresá el nombre.';
    if (step.exists(clean) ||
        step.selected.keys.any((n) => n.toLowerCase() == clean.toLowerCase())) {
      return 'Ya está en la lista.';
    }
    state = AsyncData(
      step.copyWith(selected: {...step.selected, clean: criterion}),
    );
    return null;
  }

  void setCriterion(String name, GroupCriterion criterion) {
    final step = _step;
    if (step == null || !step.selected.containsKey(name)) return;
    state = AsyncData(
      step.copyWith(selected: {...step.selected, name: criterion}),
    );
  }

  /// Crea las elegidas; devuelve el error o null.
  Future<String?> save() async {
    final step = _step;
    if (step == null) return null;
    if (step.selected.isEmpty) {
      return step.existing.isEmpty ? 'Elegí al menos una.' : null;
    }
    try {
      final programs = await _repository.createPrograms(step.selected);
      state = AsyncData(
        ProgramsStep(existing: programs, templates: step.templates),
      );
      return null;
    } catch (error) {
      return apiErrorMessage(error);
    }
  }
}

final programsStepProvider =
    AsyncNotifierProvider.autoDispose<ProgramsStepController, ProgramsStep>(
      ProgramsStepController.new,
      retry: (_, _) => null,
    );

// ---------------------------------------------------------------------------
// Paso 2: categorías y horarios

class GroupsStep {
  const GroupsStep({
    required this.programs,
    required this.groups,
    required this.venues,
    required this.levels,
    this.programId,
    this.drafts = const [],
    this.agesFrom = 4,
    this.agesTo = 16,
    this.agesSpan = 2,
    this.capacity,
    this.venueId,
    this.newVenueName = '',
    this.newVenueAddress = '',
  });

  final List<SetupProgram> programs;
  final List<SetupGroup> groups;
  final List<Venue> venues;

  /// Niveles para generar (con criterio por nivel).
  final List<String> levels;

  /// Disciplina que se está armando.
  final int? programId;
  final List<GroupDraft> drafts;
  final int agesFrom;
  final int agesTo;
  final int agesSpan;

  final int? capacity;

  /// Lugar existente; si es null y hay nombre, se crea uno nuevo.
  final int? venueId;
  final String newVenueName;
  final String newVenueAddress;

  SetupProgram? get program {
    for (final p in programs) {
      if (p.id == programId) return p;
    }
    return null;
  }

  bool get byAge => program?.criterion == GroupCriterion.birthYear;

  List<SetupGroup> groupsOf(int programId) =>
      groups.where((g) => g.programId == programId).toList();

  /// La primera disciplina sin categorías (la que sigue después de guardar).
  SetupProgram? get nextWithoutGroups {
    for (final p in programs) {
      if (p.id != programId && groupsOf(p.id).isEmpty) return p;
    }
    return null;
  }

  GroupsStep copyWith({
    List<SetupProgram>? programs,
    List<SetupGroup>? groups,
    List<Venue>? venues,
    List<String>? levels,
    int? programId,
    List<GroupDraft>? drafts,
    int? agesFrom,
    int? agesTo,
    int? agesSpan,
    int? capacity,
    bool clearCapacity = false,
    int? venueId,
    bool clearVenue = false,
    String? newVenueName,
    String? newVenueAddress,
  }) => GroupsStep(
    programs: programs ?? this.programs,
    groups: groups ?? this.groups,
    venues: venues ?? this.venues,
    levels: levels ?? this.levels,
    programId: programId ?? this.programId,
    drafts: drafts ?? this.drafts,
    agesFrom: agesFrom ?? this.agesFrom,
    agesTo: agesTo ?? this.agesTo,
    agesSpan: agesSpan ?? this.agesSpan,
    capacity: clearCapacity ? null : (capacity ?? this.capacity),
    venueId: clearVenue ? null : (venueId ?? this.venueId),
    newVenueName: newVenueName ?? this.newVenueName,
    newVenueAddress: newVenueAddress ?? this.newVenueAddress,
  );

  /// Pantalla 1 (la lista): null si se puede seguir a los horarios.
  String? validateList() {
    if (program == null) return 'Elegí la disciplina.';
    if (drafts.isEmpty) return 'Agregá al menos una.';
    final names = <String>{};
    for (final draft in drafts) {
      if (draft.name.trim().isEmpty) return 'Hay una sin nombre.';
      if (!names.add(draft.name.trim().toLowerCase())) {
        return '«${draft.name}» está repetida.';
      }
    }
    return null;
  }

  /// Pantalla 2: null si se puede guardar. Una categoría sin días se puede
  /// guardar igual (queda "sin horario"); un horario con días tiene que estar bien.
  String? validate() {
    final error = validateList();
    if (error != null) return error;
    for (final draft in drafts) {
      for (final slot in draft.filledSlots) {
        final slotError = slot.validate();
        if (slotError != null) return '${draft.name}: $slotError';
      }
    }
    return null;
  }

  /// Categorías que todavía no tienen días.
  int get withoutSchedule => drafts.where((d) => d.withoutSchedule).length;
}

class GroupsStepController extends AsyncNotifier<GroupsStep> {
  OnboardingRepository get _repository =>
      ref.read(onboardingRepositoryProvider);

  @override
  Future<GroupsStep> build() async {
    final templates = await ref.watch(onboardingTemplatesProvider.future);
    final programs = await _repository.programs();
    final groups = await _repository.groups();
    final venues = await _repository.venues();
    var step = GroupsStep(
      programs: programs,
      groups: groups,
      venues: venues,
      levels: templates.levels,
      agesFrom: templates.agesFrom,
      agesTo: templates.agesTo,
      agesSpan: templates.agesSpan,
      venueId: venues.length == 1 ? venues.first.id : null,
    );
    final first = programs.where((p) => step.groupsOf(p.id).isEmpty);
    final program = first.isNotEmpty
        ? first.first
        : (programs.isEmpty ? null : programs.first);
    if (program == null) return step;
    step = step.copyWith(programId: program.id);
    // Con categorías ya creadas no se sugieren más (se piden con "Sugerir").
    if (step.groupsOf(program.id).isNotEmpty) return step;
    return step.copyWith(drafts: await _suggest(step));
  }

  GroupsStep? get _step => state.value;

  Future<List<GroupDraft>> _suggest(GroupsStep step) async {
    final program = step.program;
    if (program == null) return const [];
    return _repository.suggestGroups(
      programId: program.id,
      from: step.agesFrom,
      to: step.agesTo,
      span: step.agesSpan,
      levels: step.byAge ? null : step.levels,
    );
  }

  Future<void> _regenerate(GroupsStep step) async {
    state = AsyncData(step);
    try {
      final drafts = await _suggest(step);
      if (_step?.programId == step.programId) {
        state = AsyncData(_step!.copyWith(drafts: drafts));
      }
    } catch (_) {
      // Se puede seguir armando a mano.
    }
  }

  Future<void> selectProgram(int id) async {
    final step = _step;
    if (step == null || step.programId == id) return;
    final next = step.copyWith(programId: id, drafts: const []);
    next.groupsOf(id).isEmpty
        ? await _regenerate(next)
        : state = AsyncData(next);
  }

  /// Sugiere categorías para la disciplina elegida (sin las que ya existen).
  Future<void> suggest() async {
    final step = _step;
    if (step != null) await _regenerate(step);
  }

  Future<void> setAges({int? from, int? to, int? span}) async {
    final step = _step;
    if (step == null) return;
    var next = step.copyWith(agesFrom: from, agesTo: to, agesSpan: span);
    if (next.agesTo < next.agesFrom) {
      next = next.copyWith(agesTo: next.agesFrom);
    }
    await _regenerate(next);
  }

  Future<void> setLevels(List<String> levels) async {
    final step = _step;
    if (step == null) return;
    await _regenerate(step.copyWith(levels: levels));
  }

  void _edit(GroupsStep Function(GroupsStep) change) {
    final step = _step;
    if (step != null) state = AsyncData(change(step));
  }

  void renameDraft(int index, String name) => _edit(
    (s) => s.copyWith(
      drafts: [...s.drafts]..[index] = s.drafts[index].copyWith(name: name),
    ),
  );

  void removeDraft(int index) =>
      _edit((s) => s.copyWith(drafts: [...s.drafts]..removeAt(index)));

  void addDraft(String name) => _edit(
    (s) => s.copyWith(
      drafts: [
        ...s.drafts,
        GroupDraft(name: name.trim(), level: s.byAge ? null : name.trim()),
      ],
    ),
  );

  void _editSlots(
    int index,
    List<WeeklyTime> Function(List<WeeklyTime>) change,
  ) => _edit(
    (s) => s.copyWith(
      drafts: [...s.drafts]
        ..[index] = s.drafts[index].copyWith(
          slots: change([...s.drafts[index].slots]),
        ),
    ),
  );

  /// Cambia un horario de una categoría (días u horas).
  void setSlot(int index, int slot, WeeklyTime time) =>
      _editSlots(index, (slots) => slots..[slot] = time);

  /// "+ Otro horario": otros días a otra hora (ej. sábado a la mañana).
  void addSlot(int index) => _editSlots(
    index,
    (slots) => [
      ...slots,
      WeeklyTime(
        startsAt: slots.isEmpty ? '17:00' : slots.last.startsAt,
        endsAt: slots.isEmpty ? '18:30' : slots.last.endsAt,
      ),
    ],
  );

  void removeSlot(int index, int slot) => _editSlots(
    index,
    (slots) =>
        slots.length == 1 ? [const WeeklyTime()] : (slots..removeAt(slot)),
  );

  /// "Copiar a todas": los horarios de una categoría pasan a las demás.
  void copySlotsToAll(int index) => _edit((s) {
    final slots = s.drafts[index].slots;
    return s.copyWith(
      drafts: [for (final draft in s.drafts) draft.copyWith(slots: slots)],
    );
  });

  void setCapacity(int? capacity) => _edit(
    (s) => s.copyWith(capacity: capacity, clearCapacity: capacity == null),
  );

  void selectVenue(int? id) =>
      _edit((s) => s.copyWith(venueId: id, clearVenue: id == null));

  void setNewVenue({String? name, String? address}) => _edit(
    (s) => s.copyWith(
      newVenueName: name,
      newVenueAddress: address,
      clearVenue: true,
    ),
  );

  /// Crea las categorías de la disciplina; devuelve el error o null. Si queda
  /// otra disciplina sin categorías, pasa a esa.
  Future<String?> save() async {
    final step = _step;
    if (step == null) return null;
    final error = step.validate();
    if (error != null) return error;
    try {
      final created = await _repository.createGroups(
        programId: step.programId!,
        groups: step.drafts,
        capacity: step.capacity,
        venueId: step.venueId,
        venueName: step.venueId == null ? step.newVenueName : null,
        venueAddress: step.newVenueAddress,
      );
      final venues = step.venueId == null && step.newVenueName.trim().isNotEmpty
          ? await _repository.venues()
          : step.venues;
      var next = step.copyWith(
        groups: [...step.groups, ...created],
        venues: venues,
        drafts: const [],
        newVenueName: '',
        newVenueAddress: '',
      );
      // El lugar recién creado queda elegido para la próxima disciplina.
      if (step.venueId == null && step.newVenueName.trim().isNotEmpty) {
        final match = venues.where((v) => v.name == step.newVenueName.trim());
        if (match.isNotEmpty) next = next.copyWith(venueId: match.first.id);
      }
      final pending = next.nextWithoutGroups;
      if (pending != null) {
        await _regenerate(next.copyWith(programId: pending.id));
      } else {
        state = AsyncData(next);
      }
      return null;
    } catch (error) {
      return apiErrorMessage(error);
    }
  }

  Future<String?> updateTime(SetupGroup group, WeeklyTime time) async {
    final step = _step;
    if (step == null) return null;
    final error = time.validate();
    if (error != null) return error;
    try {
      final venueId = group.schedules.isEmpty
          ? null
          : group.schedules.first.venueId;
      final updated = await _repository.updateGroup(
        group,
        time.toSchedules(venueId: venueId),
      );
      state = AsyncData(
        step.copyWith(
          groups: [for (final g in step.groups) g.id == group.id ? updated : g],
        ),
      );
      return null;
    } catch (error) {
      return apiErrorMessage(error);
    }
  }

  Future<String?> delete(SetupGroup group) async {
    final step = _step;
    if (step == null) return null;
    try {
      await _repository.deleteGroup(group.id);
      state = AsyncData(
        step.copyWith(
          groups: [
            for (final g in step.groups)
              if (g.id != group.id) g,
          ],
        ),
      );
      return null;
    } catch (error) {
      return apiErrorMessage(error);
    }
  }
}

final groupsStepProvider =
    AsyncNotifierProvider.autoDispose<GroupsStepController, GroupsStep>(
      GroupsStepController.new,
      retry: (_, _) => null,
    );

// ---------------------------------------------------------------------------
// Paso 3: temporada y cuotas

class SeasonStep {
  const SeasonStep({
    required this.draft,
    required this.programs,
    required this.groups,
    required this.seasons,
    this.preview,
  });

  final SeasonDraft draft;
  final List<SetupProgram> programs;

  /// Categorías activas (para "¿Alguna paga distinto?").
  final List<SetupGroup> groups;
  final List<SetupSeason> seasons;
  final SeasonPreview? preview;

  bool get multiplePrograms => programs.length > 1;

  /// Categorías de las disciplinas elegidas.
  List<SetupGroup> get eligibleGroups => draft.programIds.isEmpty
      ? groups
      : groups.where((g) => draft.programIds.contains(g.programId)).toList();

  SeasonStep copyWith({SeasonDraft? draft, SeasonPreview? preview}) =>
      SeasonStep(
        draft: draft ?? this.draft,
        programs: programs,
        groups: groups,
        seasons: seasons,
        preview: preview ?? this.preview,
      );
}

class SeasonStepController extends AsyncNotifier<SeasonStep> {
  OnboardingRepository get _repository =>
      ref.read(onboardingRepositoryProvider);

  @override
  Future<SeasonStep> build() async {
    final draft = await _repository.newSeason();
    final groups = await _repository.groups();
    final step = SeasonStep(
      draft: draft,
      programs: await _repository.programs(),
      groups: groups.where((g) => g.isActive).toList(),
      seasons: await _repository.seasons(),
    );
    return step.copyWith(preview: await _repository.previewSeason(draft));
  }

  SeasonStep? get _step => state.value;

  /// Cambia el borrador y pide el resumen; con [apply] usa lo sugerido.
  Future<void> _change(
    SeasonDraft Function(SeasonDraft) change, {
    SeasonDraft Function(SeasonDraft, SeasonPreview)? apply,
  }) async {
    final step = _step;
    if (step == null) return;
    var draft = change(step.draft);
    state = AsyncData(step.copyWith(draft: draft));
    try {
      var preview = await _repository.previewSeason(draft);
      if (apply != null) {
        draft = apply(draft, preview);
        preview = await _repository.previewSeason(draft);
      }
      final current = _step;
      if (current != null) {
        state = AsyncData(current.copyWith(draft: draft, preview: preview));
      }
    } catch (_) {
      // El resumen se vuelve a pedir con el próximo cambio.
    }
  }

  static SeasonDraft _dates(SeasonDraft d, SeasonPreview p) =>
      d.copyWith(endsOn: p.suggestedEndsOn, name: p.suggestedName);

  Future<void> setKind(String kind) => _change(
    (d) => d.copyWith(kind: kind),
    apply: (d, p) {
      final frequency = d.hasPlan ? p.suggestedFrequency : null;
      return _dates(d, p).copyWith(
        feeFrequency: frequency,
        dueDays: frequency == null ? null : p.dueDaysByFrequency[frequency],
      );
    },
  );

  Future<void> setStartsOn(DateTime date) =>
      _change((d) => d.copyWith(startsOn: date), apply: _dates);

  Future<void> setEndsOn(DateTime date) =>
      _change((d) => d.copyWith(endsOn: date));

  void setName(String name) {
    final step = _step;
    if (step != null) {
      state = AsyncData(step.copyWith(draft: step.draft.copyWith(name: name)));
    }
  }

  Future<void> toggleProgram(int id) => _change(
    (d) => d.copyWith(
      programIds: d.programIds.contains(id)
          ? [
              for (final p in d.programIds)
                if (p != id) p,
            ]
          : [...d.programIds, id],
    ),
  );

  /// null = sin plan de cobro.
  Future<void> setFrequency(FeeFrequency? frequency) {
    final dueDays = frequency == null
        ? null
        : _step?.preview?.dueDaysByFrequency[frequency];
    return _change(
      (d) => d.copyWith(
        feeFrequency: frequency,
        noPlan: frequency == null,
        dueDays: dueDays,
      ),
    );
  }

  Future<void> setDailyBasis(String basis) =>
      _change((d) => d.copyWith(dailyBasis: basis));

  Future<void> setDailyGrouping(String grouping) =>
      _change((d) => d.copyWith(dailyGrouping: grouping));

  /// Montos: el resumen se pide al pasar de página ([refreshPreview]).
  void setFeeAmount(int? amount) => _edit(
    (d) => d.copyWith(feeAmount: amount, clearFeeAmount: amount == null),
  );

  void setEnrollmentFee(int? amount) => _edit(
    (d) => d.copyWith(
      enrollmentFeeAmount: amount,
      clearEnrollmentFee: amount == null,
    ),
  );

  void setGroupAmount(int groupId, int? amount) => _edit((d) {
    final amounts = {...d.groupAmounts};
    amount == null ? amounts.remove(groupId) : amounts[groupId] = amount;
    return d.copyWith(groupAmounts: amounts);
  });

  void clearGroupAmounts() => _edit((d) => d.copyWith(groupAmounts: const {}));

  Future<void> setDueDays(int days) =>
      _change((d) => d.copyWith(dueDays: days));

  Future<void> setIssueUpfront(bool value) =>
      _change((d) => d.copyWith(issueUpfront: value));

  Future<void> setMidPeriod(String value) =>
      _change((d) => d.copyWith(midPeriod: value));

  void _edit(SeasonDraft Function(SeasonDraft) change) {
    final step = _step;
    if (step != null) {
      state = AsyncData(step.copyWith(draft: change(step.draft)));
    }
  }

  Future<void> refreshPreview() => _change((d) => d);

  /// Crea la temporada; devuelve el error o null.
  Future<String?> save() async {
    final step = _step;
    if (step == null) return null;
    final error =
        step.draft.validateSeason(multiplePrograms: step.multiplePrograms) ??
        step.draft.validatePlan();
    if (error != null) return error;
    try {
      await _repository.createSeason(step.draft);
      return null;
    } catch (error) {
      return apiErrorMessage(error);
    }
  }
}

final seasonStepProvider =
    AsyncNotifierProvider.autoDispose<SeasonStepController, SeasonStep>(
      SeasonStepController.new,
      retry: (_, _) => null,
    );

// ---------------------------------------------------------------------------
// Paso 4: técnicos

class InstructorsStep {
  const InstructorsStep({required this.team, required this.groups});

  final SetupInstructors team;
  final List<SetupGroup> groups;

  InstructorsStep copyWith({SetupInstructors? team}) =>
      InstructorsStep(team: team ?? this.team, groups: groups);
}

class InstructorsStepController extends AsyncNotifier<InstructorsStep> {
  OnboardingRepository get _repository =>
      ref.read(onboardingRepositoryProvider);

  @override
  Future<InstructorsStep> build() async {
    final groups = await _repository.groups();
    return InstructorsStep(
      team: await _repository.instructors(),
      groups: groups.where((g) => g.isActive).toList(),
    );
  }

  InstructorsStep? get _step => state.value;

  Future<String?> _reload() async {
    final step = _step;
    if (step == null) return null;
    state = AsyncData(step.copyWith(team: await _repository.instructors()));
    return null;
  }

  /// "Yo también doy clases" y sus categorías.
  Future<String?> setTeaching({
    required bool teaches,
    required List<int> groupIds,
  }) async {
    final step = _step;
    if (step == null) return null;
    try {
      final team = await _repository.setTeaching(
        teaches: teaches,
        groupIds: groupIds,
      );
      state = AsyncData(step.copyWith(team: team));
      // Dar clases cambia el permiso de tomar asistencia (tarjeta del inicio).
      ref.invalidate(currentOrganizationProvider);
      return null;
    } catch (error) {
      return apiErrorMessage(error);
    }
  }

  /// Invita a un técnico por celular o correo ([contact], con `@` es un
  /// correo); devuelve la invitación (con el link) o lanza.
  Future<SetupInstructor> invite({
    required String name,
    required String contact,
    required List<int> groupIds,
  }) async {
    final value = contact.trim();
    final byEmail = value.contains('@');
    final invited = await _repository.inviteInstructor(
      name: name.trim(),
      phone: byEmail ? null : value,
      email: byEmail ? value : null,
      groupIds: groupIds,
    );
    await _reload();
    return invited;
  }

  Future<String?> setGroups(
    SetupInstructor instructor,
    List<int> groupIds,
  ) async {
    try {
      await _repository.setInstructorGroups(instructor.userId!, groupIds);
      return await _reload();
    } catch (error) {
      return apiErrorMessage(error);
    }
  }

  /// Link nuevo de una invitación pendiente o vencida.
  Future<String> resend(SetupInstructor instructor) async {
    final link = await _repository.resendInvitation(instructor.invitationId!);
    await _reload();
    return link;
  }

  Future<String?> revoke(SetupInstructor instructor) async {
    try {
      await _repository.revokeInvitation(instructor.invitationId!);
      return await _reload();
    } catch (error) {
      return apiErrorMessage(error);
    }
  }
}

final instructorsStepProvider =
    AsyncNotifierProvider.autoDispose<
      InstructorsStepController,
      InstructorsStep
    >(InstructorsStepController.new, retry: (_, _) => null);
