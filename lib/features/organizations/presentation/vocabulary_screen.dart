import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/api_client.dart';
import '../../onboarding/data/onboarding_controller.dart';
import '../data/vocabulary_controller.dart';
import 'term_choices.dart';
import '../../../core/vocabulary/vocabulary.dart';

/// "Cómo les dicen" (desde "Mi cuenta", quien configura la organización):
/// las palabras que usan las pantallas de la app y del panel.
class VocabularyScreen extends ConsumerStatefulWidget {
  const VocabularyScreen({super.key});

  @override
  ConsumerState<VocabularyScreen> createState() => _VocabularyScreenState();
}

class _VocabularyScreenState extends ConsumerState<VocabularyScreen> {
  bool _saving = false;

  void _back() => context.canPop() ? context.pop() : context.go('/cuenta');

  Future<void> _save() async {
    setState(() => _saving = true);
    final error = await ref.read(vocabularyProvider.notifier).save();
    if (!mounted) return;
    setState(() => _saving = false);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(error ?? 'Listo: las pantallas ya dicen así.')),
      );
    if (error == null) _back();
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(vocabularyProvider);
    final options =
        ref.watch(onboardingTemplatesProvider).value?.terminologyOptions ??
        const <String, List<String>>{};
    final controller = ref.read(vocabularyProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Cómo les dicen'),
        leading: BackButton(onPressed: _back),
      ),
      body: SafeArea(
        child: async.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => Center(child: Text(apiErrorMessage(error))),
          data: (draft) => Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  const Text(
                    'Las pantallas de la app y del panel van a usar estas '
                    'palabras. Elegí una o escribí la que usan ustedes.',
                  ),
                  const SizedBox(height: 16),
                  for (final key in vocabularyKeys) ...[
                    TermChoices(
                      termKey: key,
                      options: options[key] ?? const [],
                      selected: draft[key],
                      onSelected: (word) => controller.set(key, word),
                    ),
                    if (personVocabularyKeys.contains(key))
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: TextFormField(
                          key: Key('feminine-$key'),
                          initialValue: draft[feminineKey(key)],
                          maxLength: 30,
                          decoration: InputDecoration(
                            labelText: 'Si es mujer (opcional)',
                            hintText: feminineOf(draft[key] ?? ''),
                            helperText:
                                'Vacío: "${feminineOf(draft[key] ?? '')}".',
                          ),
                          onChanged: (word) =>
                              controller.setFeminine(key, word),
                        ),
                      ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: FilledButton(
            key: const Key('vocabulary-save'),
            onPressed: _saving || !async.hasValue ? null : _save,
            child: const Text('Guardar'),
          ),
        ),
      ),
    );
  }
}
