import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/utils/format.dart';
import '../data/models.dart';
import '../data/request_form.dart';
import '../../../core/vocabulary/vocabulary.dart';

/// La opción elegida (disciplina y temporada) dentro de las que trajo la API.
EnrollmentOption? selectedOption(List<EnrollmentOption>? loaded, int index) =>
    loaded == null || loaded.isEmpty
    ? null
    : loaded[index.clamp(0, loaded.length - 1)];

/// Dónde se inscribe: disciplina y temporada (si hay varias) y la categoría,
/// con la sugerida por edad marcada, sus horarios y el cupo. Lo usan
/// "Inscribir a un hijo" y "Cargar alumno".
class PlacePicker extends StatelessWidget {
  const PlacePicker({
    super.key,
    required this.options,
    required this.optionIndex,
    required this.groupId,
    required this.showError,
    required this.group,
    required this.organization,
    required this.today,
    required this.onOptionChanged,
    required this.onGroupChanged,
  });

  /// `null` mientras no hay fecha de nacimiento.
  final AsyncValue<List<EnrollmentOption>>? options;
  final int optionIndex;

  /// `null` = la que se elige sola (la sugerida o la única).
  final int? groupId;
  final bool showError;

  /// La palabra del club para los grupos ("Categoría") y qué es la organización ("club", "academia").
  final Word group;
  final Word organization;
  final DateTime today;
  final ValueChanged<int> onOptionChanged;
  final ValueChanged<int?> onGroupChanged;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: _children(Theme.of(context)),
  );

  List<Widget> _children(ThemeData theme) {
    final options = this.options;
    if (options == null) {
      return [
        Text(
          'Con la fecha de nacimiento te sugerimos ${group.the()}.',
          style: theme.textTheme.bodySmall,
        ),
      ];
    }
    if (options.isLoading) return const [LinearProgressIndicator()];
    if (options.hasError) return [Text(apiErrorMessage(options.error!))];

    final loaded = options.value!;
    final option = selectedOption(loaded, optionIndex);
    if (option == null) {
      return [
        Text(
          '${organization.theUpper()} todavía no tiene inscripciones '
          'abiertas. Consultá con ${organization.the()}.',
        ),
      ];
    }

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
                onSelected: (_) => onOptionChanged(index),
              ),
          ],
        ),
        const SizedBox(height: 8),
      ],
      Text(
        '${group.word} · ${option.program.name}',
        style: theme.textTheme.titleSmall,
      ),
      if (option.season.startsAfter(today))
        Text(
          '${option.season.name}: empieza el ${formatDate(option.season.startsOn!)}',
          style: theme.textTheme.bodySmall,
        ),
      if (option.groups.isEmpty)
        Text(
          'Todavía no hay ${group.pluralLower} '
          '${group.g('abiertos', 'abiertas')}.',
        ),
      RadioGroup<int>(
        groupValue: groupId ?? option.defaultGroupId,
        onChanged: onGroupChanged,
        child: Column(
          children: [
            for (final group in option.groups)
              RadioListTile<int>(
                contentPadding: EdgeInsets.zero,
                value: group.id,
                title: Text(group.name),
                subtitle: _groupDetails(group, option),
              ),
          ],
        ),
      ),
      if (showError)
        Text(
          validateGroup(null, group)!,
          style: TextStyle(color: theme.colorScheme.error),
        ),
    ];
  }

  Widget? _groupDetails(GroupOption group, EnrollmentOption option) {
    final lines = [
      if (group.id == option.suggestedGroupId) 'Le corresponde por la edad',
      if (group.schedules.isNotEmpty)
        group.schedules
            .map((s) => '${weekdayShort(s.weekday)} ${s.startsAt}')
            .join(', '),
      if (group.full)
        'Completo: ${organization.the()} decide si hay lugar'
      else
        ?group.spotsLabel,
    ];
    return lines.isEmpty ? null : Text(lines.join(' · '));
  }
}
