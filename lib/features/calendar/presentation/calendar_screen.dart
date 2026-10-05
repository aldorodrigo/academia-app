import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/api_client.dart';
import '../../../core/storage/offline_store.dart';
import '../../../core/utils/clock.dart';
import '../../../core/utils/format.dart';
import '../../attendance/data/attendance_repository.dart';
import '../../attendance/data/models.dart';
import '../../auth/data/session_controller.dart';
import '../../lessons/presentation/booking_sheet.dart';
import '../../organizations/data/models.dart';
import '../../organizations/data/organization_repository.dart';
import '../../students/data/models.dart';
import '../../students/data/students_repository.dart';
import '../data/calendar_providers.dart';
import '../data/models.dart';
import 'calendar_entry_tile.dart';
import 'calendar_style.dart';
import 'class_entry_sheet.dart';
import 'month_grid.dart';

enum CalendarView { month, list }

const _viewKey = 'calendar:view';

/// Calendario de actividades: clases, particulares, eventos y días sin clase.
class CalendarScreen extends ConsumerStatefulWidget {
  const CalendarScreen({super.key, this.initialDate, this.studentId});

  /// Día elegido al abrir (por ejemplo, desde un aviso de días sin clase).
  final DateTime? initialDate;
  final int? studentId;

  @override
  ConsumerState<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends ConsumerState<CalendarScreen> {
  late DateTime _selected;
  late DateTime _month;
  var _view = CalendarView.month;

  /// Grilla plegada a una semana (null = según el tamaño de la pantalla).
  bool? _compact;
  int? _studentId;
  int? _groupId;
  var _types = {...CalendarType.values};
  var _legend = false;

  /// Lo último que se cargó, para no dejar la pantalla vacía al cambiar de mes.
  CalendarRange? _last;

  @override
  void initState() {
    super.initState();
    final today = ref.read(todayProvider);
    final initial = widget.initialDate ?? today;
    _selected = DateTime(initial.year, initial.month, initial.day);
    _month = DateTime(initial.year, initial.month);
    _studentId = widget.studentId;
    _restoreView();
  }

  /// La vista elegida se recuerda en este dispositivo (si se puede).
  Future<void> _restoreView() async {
    try {
      final saved = await ref.read(offlineStoreProvider).read(_viewKey);
      if (saved == CalendarView.list.name && mounted) {
        setState(() => _view = CalendarView.list);
      }
    } catch (_) {
      // Sin almacenamiento: queda la vista por defecto.
    }
  }

  void _setView(CalendarView view) {
    setState(() => _view = view);
    try {
      ref.read(offlineStoreProvider).write(_viewKey, view.name);
    } catch (_) {}
  }

  void _select(DateTime day) => setState(() {
    _selected = day;
    _month = DateTime(day.year, day.month);
  });

  void _moveMonth(int delta) => setState(() {
    _month = DateTime(_month.year, _month.month + delta);
    final today = ref.read(todayProvider);
    _selected = today.year == _month.year && today.month == _month.month
        ? today
        : _month;
  });

  void _moveWeek(int delta) => _select(
    DateTime(_selected.year, _selected.month, _selected.day + 7 * delta),
  );

  CalendarQuery get _query {
    final range = gridRange(_month);
    return (
      from: range.from,
      to: range.to,
      studentId: _studentId,
      groupId: _groupId,
    );
  }

  Future<void> _open(CalendarEntry entry) async {
    switch (entry) {
      case ClassEntry(:final item):
        if (item.canTakeAttendance) {
          await context.push('/clases/${item.session.id}');
        } else {
          await showClassEntrySheet(context, item);
        }
      case BookingEntry(:final item):
        if (item.asTeacher) {
          await showBookingSheet(context, item.booking);
          ref.invalidate(calendarProvider);
        } else {
          await context.push('/reservas');
        }
      case EventEntry(:final event):
        await context.push('/eventos/${event.id}');
    }
  }

  Future<void> _publish() async {
    final kind = await showModalBottomSheet<EventKind>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.event_outlined),
              title: const Text('Evento'),
              subtitle: const Text('Torneo, amistoso, festival, reunión…'),
              onTap: () => Navigator.pop(context, EventKind.event),
            ),
            ListTile(
              leading: const Icon(Icons.event_busy),
              title: const Text('Día sin clase'),
              subtitle: const Text(
                'Feriado, vacaciones o lluvia: suspende las clases.',
              ),
              onTap: () => Navigator.pop(context, EventKind.dayOff),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (kind == null || !mounted) return;
    final event = await context.push<CalendarEvent>(
      Uri(
        path: '/calendario/nuevo',
        queryParameters: {'tipo': kind.value, 'fecha': apiDate(_selected)},
      ).toString(),
    );
    if (event != null && mounted) _select(event.startsOn);
  }

  @override
  Widget build(BuildContext context) {
    final today = ref.watch(todayProvider);
    final now = ref.watch(nowProvider);
    final organization = ref.watch(currentOrganizationProvider).value;
    final organizationName = ref
        .watch(sessionControllerProvider)
        .value
        ?.organization
        ?.name;
    final students = ref.watch(studentsProvider).value ?? const <Student>[];
    final staff = organization?.can('take_attendance') ?? false;
    final groups = staff
        ? ref.watch(instructorGroupsProvider).value ?? const <InstructorGroup>[]
        : const <InstructorGroup>[];
    final canPublish = organization?.can('publish_events') ?? false;
    final lessons = organization?.hasFeature('private_lessons') ?? false;
    final types = {
      for (final type in _types)
        if (type != CalendarType.bookings || lessons) type,
    };

    final query = _query;
    final async = ref.watch(calendarProvider(query));
    final data = async.value ?? _last;
    if (async.hasValue) _last = async.value;

    final size = MediaQuery.sizeOf(context);
    final wide = size.width >= 840;
    final compact =
        _compact ??
        (size.height < 640 || MediaQuery.textScalerOf(context).scale(10) > 13);

    void retry() => ref.invalidate(calendarProvider(query));

    final filters = _Filters(
      students: students,
      groups: groups,
      organization: organization,
      studentId: _studentId,
      groupId: _groupId,
      types: types,
      showBookings: lessons,
      onStudent: (id) => setState(() {
        _studentId = id;
        _groupId = null;
      }),
      onGroup: (id) => setState(() {
        _groupId = id;
        _studentId = null;
      }),
      onTypes: (value) => setState(() => _types = value),
    );

    final monthHeader = _MonthHeader(
      label: compact && !wide ? _monthLabel(_selected) : _monthLabel(_month),
      compact: compact && !wide,
      showToggle: !wide && _view == CalendarView.month,
      onPrevious: () => compact && !wide && _view == CalendarView.month
          ? _moveWeek(-1)
          : _moveMonth(-1),
      onNext: () => compact && !wide && _view == CalendarView.month
          ? _moveWeek(1)
          : _moveMonth(1),
      onToggle: () => setState(() => _compact = !compact),
    );

    Widget grid({bool large = false}) => GestureDetector(
      onHorizontalDragEnd: (details) {
        final velocity = details.primaryVelocity ?? 0;
        if (velocity.abs() < 200) return;
        final delta = velocity < 0 ? 1 : -1;
        compact && !large ? _moveWeek(delta) : _moveMonth(delta);
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: compact && !large
            ? WeekStrip(
                selected: _selected,
                today: today,
                data: data,
                types: types,
                onSelect: _select,
              )
            : MonthGrid(
                month: _month,
                selected: _selected,
                today: today,
                data: data,
                types: types,
                large: large,
                onSelect: _select,
              ),
      ),
    );

    final legend = _Legend(
      open: _legend,
      showBookings: lessons,
      onToggle: () => setState(() => _legend = !_legend),
    );

    List<Widget> day(DateTime day) => _DayContent.children(
      context: context,
      day: day,
      today: today,
      now: now,
      data: data,
      types: types,
      onOpen: _open,
    );

    Widget body;
    if (data == null && async.hasError) {
      body = _ErrorView(message: apiErrorMessage(async.error!), onRetry: retry);
    } else if (_view == CalendarView.list) {
      body = RefreshIndicator(
        onRefresh: () => ref.refresh(calendarProvider(query).future),
        child: ListView(
          padding: const EdgeInsets.only(bottom: 96),
          children: [
            monthHeader,
            ..._listDays(
              data,
              today,
            ).expand((d) => [_DayHeader(day: d, today: today), ...day(d)]),
            if (data != null && _listDays(data, today).isEmpty)
              const _Empty('Todavía no hay clases ni eventos este mes.'),
            Padding(
              padding: const EdgeInsets.all(16),
              child: OutlinedButton(
                onPressed: () => _moveMonth(1),
                child: Text(
                  'Ver ${monthName(DateTime(_month.year, _month.month + 1).month)}',
                ),
              ),
            ),
            const _SyncHint(),
          ],
        ),
      );
    } else if (wide) {
      body = Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 3,
            child: ListView(
              padding: const EdgeInsets.only(bottom: 24),
              children: [monthHeader, grid(large: true), legend],
            ),
          ),
          const VerticalDivider(width: 1),
          Expanded(
            flex: 2,
            child: ListView(
              padding: const EdgeInsets.only(bottom: 24),
              children: [
                _DayHeader(day: _selected, today: today),
                ...day(_selected),
              ],
            ),
          ),
        ],
      );
    } else {
      body = RefreshIndicator(
        onRefresh: () => ref.refresh(calendarProvider(query).future),
        child: ListView(
          padding: const EdgeInsets.only(bottom: 96),
          children: [
            monthHeader,
            grid(),
            legend,
            const Divider(height: 1),
            _DayHeader(day: _selected, today: today),
            ...day(_selected),
            const _SyncHint(),
          ],
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        leading: BackButton(
          onPressed: () =>
              context.canPop() ? context.pop() : context.go('/inicio'),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Calendario'),
            if (organizationName != null)
              Text(
                organizationName,
                style: Theme.of(context).textTheme.bodySmall,
              ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Sincronizar con Google Calendar o iPhone',
            icon: const Icon(Icons.sync),
            onPressed: () => context.push('/calendario/sincronizar'),
          ),
          IconButton(
            tooltip: 'Ir a hoy',
            icon: const Icon(Icons.today_outlined),
            onPressed: () => _select(today),
          ),
          IconButton(
            tooltip: _view == CalendarView.month
                ? 'Ver como lista'
                : 'Ver como mes',
            icon: Icon(
              _view == CalendarView.month
                  ? Icons.view_agenda_outlined
                  : Icons.calendar_view_month_outlined,
            ),
            onPressed: () => _setView(
              _view == CalendarView.month
                  ? CalendarView.list
                  : CalendarView.month,
            ),
          ),
          if (canPublish && wide)
            Padding(
              padding: const EdgeInsets.only(right: 12, left: 4),
              child: FilledButton.icon(
                onPressed: _publish,
                icon: const Icon(Icons.add),
                label: const Text('Publicar'),
              ),
            ),
        ],
      ),
      floatingActionButton: canPublish && !wide
          ? FloatingActionButton.extended(
              onPressed: _publish,
              icon: const Icon(Icons.add),
              label: const Text('Publicar'),
            )
          : null,
      body: Column(
        children: [
          filters,
          SizedBox(
            height: 3,
            child: async.isLoading && data != null
                ? const LinearProgressIndicator()
                : null,
          ),
          if (async.hasError && data != null)
            MaterialBanner(
              content: Text(
                'No se pudo actualizar: ${apiErrorMessage(async.error!)}',
              ),
              actions: [
                TextButton(onPressed: retry, child: const Text('Reintentar')),
              ],
            ),
          Expanded(child: body),
        ],
      ),
    );
  }

  /// Días del mes con algo, desde hoy si es el mes actual.
  List<DateTime> _listDays(CalendarRange? data, DateTime today) {
    if (data == null) return const [];
    final current = today.year == _month.year && today.month == _month.month;
    final first = current ? today.day : 1;
    final last = DateTime(_month.year, _month.month + 1, 0).day;
    final types = _types;
    return [
      for (var d = first; d <= last; d++)
        if (data
                .entriesOn(DateTime(_month.year, _month.month, d), types: types)
                .isNotEmpty ||
            data
                .daysOffOn(DateTime(_month.year, _month.month, d), types: types)
                .isNotEmpty)
          DateTime(_month.year, _month.month, d),
    ];
  }

  static String _monthLabel(DateTime date) {
    final name = monthName(date.month);
    return '${name[0].toUpperCase()}${name.substring(1)} ${date.year}';
  }
}

/// Filas de un día: avisos de días sin clase y lo que hay, por hora.
abstract final class _DayContent {
  static List<Widget> children({
    required BuildContext context,
    required DateTime day,
    required DateTime today,
    required DateTime now,
    required CalendarRange? data,
    required Set<CalendarType> types,
    required void Function(CalendarEntry) onOpen,
  }) {
    if (data == null) {
      return const [
        Padding(
          padding: EdgeInsets.all(32),
          child: Center(child: CircularProgressIndicator()),
        ),
      ];
    }
    final daysOff = data.daysOffOn(day, types: types);
    final entries = data.entriesOn(day, types: types);
    return [
      for (final event in daysOff)
        DayOffBanner(
          event: event,
          onTap: () => context.push('/eventos/${event.id}'),
        ),
      for (final entry in entries)
        CalendarEntryTile(
          entry: entry,
          day: day,
          today: today,
          now: now,
          onTap: () => onOpen(entry),
        ),
      if (entries.isEmpty && daysOff.isEmpty)
        _Empty(
          data.classes.isEmpty && data.bookings.isEmpty && data.events.isEmpty
              ? 'Todavía no hay clases ni eventos este mes.'
              : 'No hay nada este día.',
        ),
    ];
  }
}

class _Filters extends StatelessWidget {
  const _Filters({
    required this.students,
    required this.groups,
    required this.organization,
    required this.studentId,
    required this.groupId,
    required this.types,
    required this.showBookings,
    required this.onStudent,
    required this.onGroup,
    required this.onTypes,
  });

  final List<Student> students;
  final List<InstructorGroup> groups;
  final OrganizationDetails? organization;
  final int? studentId;
  final int? groupId;
  final Set<CalendarType> types;
  final bool showBookings;
  final ValueChanged<int?> onStudent;
  final ValueChanged<int?> onGroup;
  final ValueChanged<Set<CalendarType>> onTypes;

  Future<void> _pickGroup(BuildContext context) async {
    final term = organization?.term('group') ?? 'Grupo';
    final byProgram = <String, List<InstructorGroup>>{};
    for (final group in groups) {
      byProgram.putIfAbsent(group.group.program.name, () => []).add(group);
    }
    final picked = await showModalBottomSheet<int>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            ListTile(
              title: Text('Todos mis grupos ($term)'),
              trailing: groupId == null ? const Icon(Icons.check) : null,
              onTap: () => Navigator.pop(context, 0),
            ),
            for (final entry in byProgram.entries) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: Text(
                  entry.key,
                  style: Theme.of(context).textTheme.labelLarge,
                ),
              ),
              for (final group in entry.value)
                ListTile(
                  title: Text(group.group.name),
                  trailing: groupId == group.group.id
                      ? const Icon(Icons.check)
                      : null,
                  onTap: () => Navigator.pop(context, group.group.id),
                ),
            ],
          ],
        ),
      ),
    );
    if (picked != null) onGroup(picked == 0 ? null : picked);
  }

  @override
  Widget build(BuildContext context) {
    final kids = students.where((s) => !s.isSelf).toList();
    String? groupName;
    for (final group in groups) {
      if (group.group.id == groupId) groupName = group.group.name;
    }
    final chips = <Widget>[
      if (kids.length > 1) ...[
        ChoiceChip(
          label: const Text('Todos'),
          selected: studentId == null && groupId == null,
          onSelected: (_) => onStudent(null),
        ),
        for (final kid in kids)
          ChoiceChip(
            label: Text(kid.firstName),
            selected: studentId == kid.id,
            onSelected: (_) => onStudent(kid.id),
          ),
      ],
      if (groups.length > 1)
        ActionChip(
          avatar: const Icon(Icons.filter_list, size: 18),
          label: Text(groupName ?? 'Mis grupos'),
          onPressed: () => _pickGroup(context),
        ),
      for (final type in CalendarType.values)
        if (type != CalendarType.bookings || showBookings)
          FilterChip(
            label: Text(type.label),
            selected: types.contains(type),
            onSelected: (selected) {
              final next = {...types};
              selected ? next.add(type) : next.remove(type);
              // Siempre queda algo para ver.
              if (next.isNotEmpty) onTypes(next);
            },
          ),
    ];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Row(
        children: [
          for (final chip in chips)
            Padding(padding: const EdgeInsets.only(right: 8), child: chip),
        ],
      ),
    );
  }
}

class _MonthHeader extends StatelessWidget {
  const _MonthHeader({
    required this.label,
    required this.compact,
    required this.showToggle,
    required this.onPrevious,
    required this.onNext,
    required this.onToggle,
  });

  final String label;
  final bool compact;
  final bool showToggle;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 8),
    child: Row(
      children: [
        IconButton(
          tooltip: compact ? 'Semana anterior' : 'Mes anterior',
          icon: const Icon(Icons.chevron_left),
          onPressed: onPrevious,
        ),
        Expanded(
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        IconButton(
          tooltip: compact ? 'Semana siguiente' : 'Mes siguiente',
          icon: const Icon(Icons.chevron_right),
          onPressed: onNext,
        ),
        if (showToggle)
          IconButton(
            tooltip: compact ? 'Ver el mes' : 'Ver la semana',
            icon: Icon(compact ? Icons.unfold_more : Icons.unfold_less),
            onPressed: onToggle,
          ),
      ],
    ),
  );
}

class _DayHeader extends StatelessWidget {
  const _DayHeader({required this.day, required this.today});

  final DateTime day;
  final DateTime today;

  @override
  Widget build(BuildContext context) {
    final long =
        '${weekdayLong(day.weekday)} ${day.day} de ${monthName(day.month)}';
    final relative = formatDay(day, today);
    final text = switch (relative) {
      'hoy' ||
      'mañana' ||
      'ayer' => '${relative[0].toUpperCase()}${relative.substring(1)}, $long',
      _ => '${long[0].toUpperCase()}${long.substring(1)}',
    };
    return Semantics(
      header: true,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
        child: Text(text, style: Theme.of(context).textTheme.titleSmall),
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({
    required this.open,
    required this.onToggle,
    required this.showBookings,
  });

  final bool open;
  final bool showBookings;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextButton.icon(
            onPressed: onToggle,
            icon: Icon(open ? Icons.expand_less : Icons.expand_more),
            label: const Text('Qué significa cada marca'),
          ),
          if (open)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
              child: Wrap(
                spacing: 16,
                runSpacing: 8,
                children: [
                  for (final marker in CalendarMarker.values)
                    if (marker != CalendarMarker.booking || showBookings)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CalendarMarkerDot(marker, size: 8),
                          const SizedBox(width: 6),
                          Text(markerLabel(marker)),
                        ],
                      ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.event_busy,
                        size: 14,
                        color: scheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 6),
                      const Text('Sin clases'),
                    ],
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Al pie: llevar el calendario a Google o al iPhone.
class _SyncHint extends StatelessWidget {
  const _SyncHint();

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(8, 16, 8, 0),
    child: Center(
      child: TextButton.icon(
        onPressed: () => context.push('/calendario/sincronizar'),
        icon: const Icon(Icons.sync),
        label: const Text('Verlo en Google Calendar o en tu iPhone'),
      ),
    ),
  );
}

class _Empty extends StatelessWidget {
  const _Empty(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
    child: Text(
      text,
      textAlign: TextAlign.center,
      style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
    ),
  );
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 12),
          FilledButton.tonal(
            onPressed: onRetry,
            child: const Text('Reintentar'),
          ),
        ],
      ),
    ),
  );
}
