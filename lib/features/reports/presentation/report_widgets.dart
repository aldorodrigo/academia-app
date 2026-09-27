import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/utils/format.dart';
import '../../../core/utils/launcher.dart';
import '../data/models.dart';

/// Botones de descarga (PDF y Excel) de un informe.
class DownloadButtons extends ConsumerWidget {
  const DownloadButtons(this.links, {super.key});

  final ReportLinks links;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final open = ref.read(urlLauncherProvider);
    return Wrap(
      spacing: 8,
      children: [
        if (links.pdf != null)
          OutlinedButton.icon(
            icon: const Icon(Icons.picture_as_pdf_outlined),
            label: const Text('PDF'),
            onPressed: () => open(Uri.parse(links.pdf!)),
          ),
        if (links.xlsx != null)
          OutlinedButton.icon(
            icon: const Icon(Icons.table_chart_outlined),
            label: const Text('Excel'),
            onPressed: () => open(Uri.parse(links.xlsx!)),
          ),
      ],
    );
  }
}

/// Fila "etiqueta ........ ₲ monto".
class AmountRow extends StatelessWidget {
  const AmountRow(
    this.label,
    this.amount, {
    super.key,
    this.bold = false,
    this.color,
  });

  final String label;
  final int amount;
  final bool bold;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final base = bold
        ? Theme.of(context).textTheme.titleSmall
        : Theme.of(context).textTheme.bodyMedium;
    final style = base?.copyWith(color: color);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(child: Text(label, style: style)),
          Text(formatMoney(amount), style: style),
        ],
      ),
    );
  }
}

class ReportSection extends StatelessWidget {
  const ReportSection(this.title, {super.key, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          ...children,
        ],
      ),
    ),
  );
}

/// Carga / error / datos de un informe, con "tirar para actualizar".
class ReportBody<T> extends StatelessWidget {
  const ReportBody({
    super.key,
    required this.value,
    required this.onRefresh,
    required this.builder,
  });

  final AsyncValue<T> value;
  final Future<void> Function() onRefresh;
  final List<Widget> Function(T data) builder;

  @override
  Widget build(BuildContext context) => value.when(
    loading: () => const Center(child: CircularProgressIndicator()),
    error: (error, _) => Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(apiErrorMessage(error), textAlign: TextAlign.center),
      ),
    ),
    data: (data) => RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: builder(data),
      ),
    ),
  );
}
