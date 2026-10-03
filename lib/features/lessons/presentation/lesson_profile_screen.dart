import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/api_client.dart';
import '../../../core/utils/format.dart';
import '../data/booking_controller.dart';
import '../data/models.dart';
import 'booking_sheet.dart';

const _durations = [30, 45, 60, 90, 120];

const _notices = {
  0: 'Sin anticipación',
  60: '1 hora',
  120: '2 horas',
  240: '4 horas',
  1440: '1 día',
};

/// Validez de un paquete en los chips: días, o null = sin vencimiento.
const packValidityPresets = [15, 30, 60];

/// Horas para armar las franjas, cada 30 minutos de 6:00 a 23:30.
final _times = [for (var m = 6 * 60; m < 24 * 60; m += 30) timeOf(m)];

const _weekdayNames = [
  'Lunes',
  'Martes',
  'Miércoles',
  'Jueves',
  'Viernes',
  'Sábado',
  'Domingo',
];

/// Ajustes de clases particulares del profesor: precios, paquetes y disponibilidad.
class LessonProfileScreen extends ConsumerWidget {
  const LessonProfileScreen({super.key});

  Future<void> _save(BuildContext context, WidgetRef ref) async {
    final error = await ref.read(lessonProfileProvider.notifier).save();
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(error ?? 'Guardado.')));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(lessonProfileProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Clases particulares'),
        leading: BackButton(
          onPressed: () =>
              context.canPop() ? context.pop() : context.go('/cuenta'),
        ),
      ),
      body: profile.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text(apiErrorMessage(error))),
        data: (profile) => _ProfileForm(profile),
      ),
      bottomNavigationBar: profile.hasValue
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: FilledButton(
                  onPressed: () => _save(context, ref),
                  child: const Text('Guardar'),
                ),
              ),
            )
          : null,
    );
  }
}

class _ProfileForm extends ConsumerStatefulWidget {
  const _ProfileForm(this.profile);

  final LessonProfile profile;

  @override
  ConsumerState<_ProfileForm> createState() => _ProfileFormState();
}

class _ProfileFormState extends ConsumerState<_ProfileForm> {
  late final _price = TextEditingController(
    text: widget.profile.singlePrice > 0 ? '${widget.profile.singlePrice}' : '',
  );

  LessonProfileController get _controller =>
      ref.read(lessonProfileProvider.notifier);

  @override
  void dispose() {
    _price.dispose();
    super.dispose();
  }

  Future<void> _editPack({int? index}) async {
    final profile = widget.profile;
    final offer = await showDialog<LessonOffer>(
      context: context,
      builder: (_) => PackDialog(
        initial: index == null ? null : profile.packs[index],
        singlePrice: profile.singlePrice,
      ),
    );
    if (offer == null) return;
    index == null
        ? _controller.addPack(offer)
        : _controller.replacePack(index, offer);
  }

  Future<void> _editRange(int weekday, {AvailabilityRange? range}) async {
    final edited = await showDialog<AvailabilityRange>(
      context: context,
      builder: (_) => _RangeDialog(weekday: weekday, initial: range),
    );
    if (edited == null) return;
    range == null
        ? _controller.addRange(edited)
        : _controller.replaceRange(range, edited);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final profile = widget.profile;
    final preview = profile.preview();

    Widget section(String title) => Padding(
      padding: const EdgeInsets.only(top: 24, bottom: 8),
      child: Text(title, style: theme.textTheme.titleMedium),
    );

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Recibir reservas'),
          subtitle: const Text(
            'Tus alumnos reservan dentro de tu disponibilidad y se confirma sola.',
          ),
          value: profile.enabled,
          onChanged: (v) => _controller.edit((p) => p.copyWith(enabled: v)),
        ),
        section('Clase suelta'),
        TextField(
          controller: _price,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: const InputDecoration(
            labelText: 'Precio por clase',
            prefixText: '₲ ',
          ),
          onChanged: (text) => _controller.edit(
            (p) => p.copyWith(singlePrice: parseAmount(text) ?? 0),
          ),
        ),
        const SizedBox(height: 12),
        Text('Duración de la clase', style: theme.textTheme.bodySmall),
        Wrap(
          spacing: 8,
          children: [
            for (final minutes in _durations)
              ChoiceChip(
                label: Text(
                  minutes < 60 || minutes % 60 != 0
                      ? '$minutes min'
                      : '${minutes ~/ 60} h',
                ),
                selected: profile.durationMinutes == minutes,
                onSelected: (_) => _controller.edit(
                  (p) => p.copyWith(durationMinutes: minutes),
                ),
              ),
          ],
        ),
        section('Paquetes'),
        if (profile.packs.isEmpty)
          const Text('Sin paquetes: tus alumnos pagan cada clase suelta.'),
        for (var i = 0; i < profile.packs.length; i++)
          Card(
            child: ListTile(
              title: Text(profile.packs[i].title),
              subtitle: Text(
                '${formatMoney(profile.packs[i].unitPrice)} por clase · ${describeValidDays(profile.packs[i].validDays)}',
              ),
              onTap: () => _editPack(index: i),
              trailing: IconButton(
                tooltip: 'Quitar paquete',
                icon: const Icon(Icons.delete_outline),
                onPressed: () => _controller.removePack(i),
              ),
            ),
          ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            icon: const Icon(Icons.add),
            label: const Text('Agregar paquete'),
            onPressed: () => _editPack(),
          ),
        ),
        section('Disponibilidad'),
        for (var weekday = 1; weekday <= 7; weekday++)
          _DayRow(
            weekday: weekday,
            ranges: profile.rangesOf(weekday),
            onAdd: () => _editRange(weekday),
            onEdit: (range) => _editRange(weekday, range: range),
            onRemove: _controller.removeRange,
            onCopyToAll: () => _controller.copyToAllDays(weekday),
          ),
        if (preview.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            'Tus alumnos van a ver: $preview',
            style: theme.textTheme.bodySmall,
          ),
        ],
        section('Reservas'),
        DropdownButtonFormField<int>(
          initialValue: _notices.containsKey(profile.minNoticeMinutes)
              ? profile.minNoticeMinutes
              : null,
          decoration: const InputDecoration(
            labelText: 'Anticipación mínima para reservar',
          ),
          items: [
            for (final entry in _notices.entries)
              DropdownMenuItem(value: entry.key, child: Text(entry.value)),
          ],
          onChanged: (v) => _controller.edit(
            (p) => p.copyWith(minNoticeMinutes: v ?? p.minNoticeMinutes),
          ),
        ),
        if (profile.moneyAccounts.length > 1) ...[
          const SizedBox(height: 12),
          DropdownButtonFormField<int>(
            initialValue: profile.moneyAccountId,
            decoration: const InputDecoration(
              labelText: 'Cuenta donde entra lo que cobrás',
            ),
            items: [
              for (final account in profile.moneyAccounts)
                DropdownMenuItem(value: account.id, child: Text(account.name)),
            ],
            onChanged: (v) =>
                _controller.edit((p) => p.copyWith(moneyAccountId: v)),
          ),
        ],
      ],
    );
  }
}

class _DayRow extends StatelessWidget {
  const _DayRow({
    required this.weekday,
    required this.ranges,
    required this.onAdd,
    required this.onEdit,
    required this.onRemove,
    required this.onCopyToAll,
  });

  final int weekday;
  final List<AvailabilityRange> ranges;
  final VoidCallback onAdd;
  final ValueChanged<AvailabilityRange> onEdit;
  final ValueChanged<AvailabilityRange> onRemove;
  final VoidCallback onCopyToAll;

  @override
  Widget build(BuildContext context) {
    final name = _weekdayNames[weekday - 1];
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(width: 88, child: Text(name)),
          Expanded(
            child: Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                for (final range in ranges)
                  InputChip(
                    label: Text('${range.startsAt} a ${range.endsAt}'),
                    onPressed: () => onEdit(range),
                    onDeleted: () => onRemove(range),
                    deleteButtonTooltipMessage: 'Quitar franja',
                  ),
                if (ranges.isEmpty)
                  Text(
                    'No das clases',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Agregar franja el ${name.toLowerCase()}',
            icon: const Icon(Icons.add),
            onPressed: onAdd,
          ),
          if (ranges.isNotEmpty)
            PopupMenuButton<void>(
              tooltip: 'Más opciones',
              itemBuilder: (_) => [
                PopupMenuItem(
                  onTap: onCopyToAll,
                  child: const Text('Copiar a todos los días'),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _RangeDialog extends StatefulWidget {
  const _RangeDialog({required this.weekday, this.initial});

  final int weekday;
  final AvailabilityRange? initial;

  @override
  State<_RangeDialog> createState() => _RangeDialogState();
}

class _RangeDialogState extends State<_RangeDialog> {
  late String _from = widget.initial?.startsAt ?? '15:00';
  late String _to = widget.initial?.endsAt ?? '20:00';

  List<String> _options(String current) =>
      _times.contains(current) ? _times : [..._times, current]
        ..sort();

  @override
  Widget build(BuildContext context) {
    final valid = (minutesOf(_to) ?? 0) > (minutesOf(_from) ?? 0);
    return AlertDialog(
      title: Text(_weekdayNames[widget.weekday - 1]),
      content: Row(
        children: [
          Expanded(
            child: DropdownButtonFormField<String>(
              initialValue: _from,
              decoration: const InputDecoration(labelText: 'Desde'),
              items: [
                for (final t in _options(_from))
                  DropdownMenuItem(value: t, child: Text(t)),
              ],
              onChanged: (v) => setState(() => _from = v ?? _from),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: DropdownButtonFormField<String>(
              initialValue: _to,
              decoration: InputDecoration(
                labelText: 'Hasta',
                errorText: valid ? null : 'Después de "desde"',
              ),
              items: [
                for (final t in _options(_to))
                  DropdownMenuItem(value: t, child: Text(t)),
              ],
              onChanged: (v) => setState(() => _to = v ?? _to),
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
          onPressed: valid
              ? () => Navigator.pop(
                  context,
                  AvailabilityRange(
                    weekday: widget.weekday,
                    startsAt: _from,
                    endsAt: _to,
                  ),
                )
              : null,
          child: const Text('Listo'),
        ),
      ],
    );
  }
}

/// Crear o editar un paquete: cantidad de clases, precio y validez.
class PackDialog extends StatefulWidget {
  const PackDialog({super.key, this.initial, required this.singlePrice});

  final LessonOffer? initial;
  final int singlePrice;

  @override
  State<PackDialog> createState() => _PackDialogState();
}

class _PackDialogState extends State<PackDialog> {
  late final _classes = TextEditingController(
    text: '${widget.initial?.classes ?? 4}',
  );
  late final _price = TextEditingController(
    text: widget.initial == null ? '' : '${widget.initial!.price}',
  );
  late final _customDays = TextEditingController(
    text: _isCustom(widget.initial) ? '${widget.initial!.validDays}' : '',
  );

  /// 15, 30, 60, "custom" o null (sin vencimiento).
  late Object? _validity = widget.initial == null
      ? 30
      : _isCustom(widget.initial)
      ? 'custom'
      : widget.initial!.validDays;
  String? _error;

  static bool _isCustom(LessonOffer? offer) =>
      offer?.validDays != null &&
      !packValidityPresets.contains(offer!.validDays);

  @override
  void dispose() {
    _classes.dispose();
    _price.dispose();
    _customDays.dispose();
    super.dispose();
  }

  void _submit() {
    final classes = int.tryParse(_classes.text);
    final price = parseAmount(_price.text);
    int? days;
    if (_validity == 'custom') {
      days = int.tryParse(_customDays.text);
      if (days == null || days < 1 || days > 365) {
        setState(() => _error = 'La validez va de 1 a 365 días.');
        return;
      }
    } else {
      days = _validity as int?;
    }
    if (classes == null || classes < 1) {
      setState(() => _error = 'Poné la cantidad de clases.');
      return;
    }
    if (price == null) {
      setState(() => _error = 'Poné el precio del paquete.');
      return;
    }
    Navigator.pop(
      context,
      LessonOffer(
        id: widget.initial?.id,
        classes: classes,
        price: price,
        validDays: days,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final classes = int.tryParse(_classes.text) ?? 0;
    final price = parseAmount(_price.text) ?? 0;
    final offer = LessonOffer(classes: classes, price: price);

    return AlertDialog(
      title: Text(widget.initial == null ? 'Nuevo paquete' : 'Paquete'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _classes,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(
                labelText: 'Cantidad de clases',
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _price,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(
                labelText: 'Precio del paquete',
                prefixText: '₲ ',
              ),
              onChanged: (_) => setState(() {}),
            ),
            if (classes > 0 && price > 0)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  '${formatMoney(offer.unitPrice)} por clase'
                  '${offer.savings(widget.singlePrice) > 0 ? ' · ahorran ${formatMoney(offer.savings(widget.singlePrice))}' : ''}',
                  style: theme.textTheme.bodySmall,
                ),
              ),
            const SizedBox(height: 16),
            Text('Validez', style: theme.textTheme.bodySmall),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                for (final days in packValidityPresets)
                  ChoiceChip(
                    label: Text('$days días'),
                    selected: _validity == days,
                    onSelected: (_) => setState(() => _validity = days),
                  ),
                ChoiceChip(
                  label: const Text('Personalizado'),
                  selected: _validity == 'custom',
                  onSelected: (_) => setState(() => _validity = 'custom'),
                ),
                ChoiceChip(
                  label: const Text('Sin vencimiento'),
                  selected: _validity == null,
                  onSelected: (_) => setState(() => _validity = null),
                ),
              ],
            ),
            if (_validity == 'custom')
              TextField(
                controller: _customDays,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(
                  labelText: 'Cantidad de días',
                ),
              ),
            const SizedBox(height: 4),
            Text(
              'Cuenta desde que el alumno lo paga.',
              style: theme.textTheme.bodySmall,
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  _error!,
                  style: TextStyle(color: theme.colorScheme.error),
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(onPressed: _submit, child: const Text('Listo')),
      ],
    );
  }
}
