import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../organizations/data/vocabulary_controller.dart';
import '../../organizations/presentation/term_choices.dart';
import '../data/models.dart';
import '../data/onboarding_controller.dart';

/// Propone las palabras de cada deporte (fútbol: Jugador, Técnico, Categoría,
/// Cancha; natación: Nivel, Pileta…) después del paso 1 o desde el recordatorio
/// de la guía. Cerrarla sin contestar no decide nada: la guía la sigue
/// recordando hasta que use las elegidas o deje las de antes.
Future<void> showTerminologySuggestion(
  BuildContext context,
  TerminologySuggestion suggestion,
) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  builder: (_) => TerminologySuggestionSheet(suggestion: suggestion),
);

class TerminologySuggestionSheet extends ConsumerStatefulWidget {
  const TerminologySuggestionSheet({super.key, required this.suggestion});

  final TerminologySuggestion suggestion;

  @override
  ConsumerState<TerminologySuggestionSheet> createState() =>
      _TerminologySuggestionSheetState();
}

class _TerminologySuggestionSheetState
    extends ConsumerState<TerminologySuggestionSheet> {
  late final Map<String, String> _chosen = {...widget.suggestion.suggested};
  bool _saving = false;
  String? _error;

  Future<void> _save(Map<String, String> terminology) async {
    setState(() {
      _saving = true;
      _error = null;
    });
    final error = await ref.read(vocabularyActionsProvider).save(terminology);
    if (!mounted) return;
    if (error != null) {
      setState(() {
        _saving = false;
        _error = error;
      });
      return;
    }
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final suggestion = widget.suggestion;
    final options =
        ref.watch(onboardingTemplatesProvider).value?.terminologyOptions ??
        const <String, List<String>>{};

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
        child: Column(
          key: const Key('terminology-suggestion'),
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('¿Cómo les dicen?', style: theme.textTheme.headlineSmall),
            const SizedBox(height: 4),
            Text(
              'En ${suggestion.programsText} se suele decir '
              '${suggestion.suggestedText}. Elegí las palabras que usan '
              'ustedes: las pantallas van a decir eso.',
            ),
            const SizedBox(height: 16),
            for (final key in suggestion.suggested.keys)
              TermChoices(
                termKey: key,
                options: termOptions(options[key] ?? const [], [
                  suggestion.suggested[key],
                  suggestion.current[key],
                ]),
                selected: _chosen[key],
                onSelected: (word) => setState(() => _chosen[key] = word),
              ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  _error!,
                  style: TextStyle(color: theme.colorScheme.error),
                ),
              ),
            FilledButton(
              key: const Key('terminology-use'),
              onPressed: _saving ? null : () => _save(_chosen),
              child: const Text('Usar estas palabras'),
            ),
            TextButton(
              key: const Key('terminology-keep'),
              onPressed: _saving ? null : () => _save(const {}),
              child: Text('Dejar como estaba (${suggestion.currentText})'),
            ),
            TextButton(
              key: const Key('terminology-later'),
              onPressed: _saving ? null : () => Navigator.pop(context),
              child: const Text('Después'),
            ),
          ],
        ),
      ),
    );
  }
}
