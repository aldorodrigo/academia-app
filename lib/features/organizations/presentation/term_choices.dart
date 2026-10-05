import 'package:flutter/material.dart';

/// Qué nombra cada palabra del vocabulario.
const termLabels = {
  'student': 'A los que aprenden',
  'instructor': 'A quienes enseñan',
  'group': 'A los grupos',
  'space': 'Al lugar de la clase',
};

/// Opciones de una palabra: las sugeridas, más las que ya se usan.
List<String> termOptions(List<String> suggested, Iterable<String?> extra) {
  final options = <String>[...suggested];
  for (final word in extra) {
    if (word != null &&
        word.isNotEmpty &&
        !options.any((o) => o.toLowerCase() == word.toLowerCase())) {
      options.add(word);
    }
  }
  return options;
}

/// Una palabra del vocabulario: chips con las opciones y "Otra…" para
/// escribirla.
class TermChoices extends StatelessWidget {
  const TermChoices({
    super.key,
    required this.termKey,
    required this.options,
    required this.selected,
    required this.onSelected,
  });

  final String termKey;
  final List<String> options;
  final String? selected;
  final ValueChanged<String> onSelected;

  Future<void> _other(BuildContext context) async {
    final word = await showDialog<String>(
      context: context,
      builder: (_) => const _OtherWordDialog(),
    );
    if (word != null && word.trim().isNotEmpty) onSelected(word.trim());
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            termLabels[termKey] ?? termKey,
            style: theme.textTheme.titleSmall,
          ),
          const SizedBox(height: 4),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              for (final option in termOptions(options, [selected]))
                ChoiceChip(
                  key: Key('term-$termKey-$option'),
                  label: Text(option),
                  selected: option == selected,
                  onSelected: (_) => onSelected(option),
                ),
              ActionChip(
                key: Key('term-$termKey-other'),
                avatar: const Icon(Icons.edit_outlined, size: 18),
                label: const Text('Otra…'),
                onPressed: () => _other(context),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _OtherWordDialog extends StatefulWidget {
  const _OtherWordDialog();

  @override
  State<_OtherWordDialog> createState() => _OtherWordDialogState();
}

class _OtherWordDialogState extends State<_OtherWordDialog> {
  final _word = TextEditingController();

  @override
  void dispose() {
    _word.dispose();
    super.dispose();
  }

  void _done() {
    final word = _word.text.trim();
    if (word.isEmpty) return;
    // "pileta" → "Pileta", como las demás.
    Navigator.pop(context, word[0].toUpperCase() + word.substring(1));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('¿Cómo le dicen?'),
      content: TextField(
        key: const Key('term-other-word'),
        controller: _word,
        autofocus: true,
        maxLength: 30,
        textCapitalization: TextCapitalization.sentences,
        decoration: const InputDecoration(
          labelText: 'En singular',
          hintText: 'Pileta, Entrenador…',
        ),
        onSubmitted: (_) => _done(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(onPressed: _done, child: const Text('Listo')),
      ],
    );
  }
}
