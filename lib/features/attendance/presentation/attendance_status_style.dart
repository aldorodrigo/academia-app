import 'package:flutter/material.dart';

import '../data/models.dart';

/// Ícono y color de cada marca (siempre ícono + texto, no solo color).
extension AttendanceStatusStyle on AttendanceStatus {
  IconData get icon => switch (this) {
    AttendanceStatus.present => Icons.check_circle,
    AttendanceStatus.absent => Icons.cancel,
    AttendanceStatus.justified => Icons.info,
  };

  Color color(ColorScheme scheme) => switch (this) {
    AttendanceStatus.present => const Color(0xFF059669),
    AttendanceStatus.absent => scheme.error,
    AttendanceStatus.justified => const Color(0xFFB45309),
  };
}

/// Marca compacta: ícono y texto con el color de la marca.
class AttendanceStatusLabel extends StatelessWidget {
  const AttendanceStatusLabel(this.status, {super.key});

  final AttendanceStatus? status;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final status = this.status;
    if (status == null) {
      return Text(
        'Sin tomar',
        style: TextStyle(color: scheme.onSurfaceVariant),
      );
    }
    final color = status.color(scheme);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(status.icon, color: color, size: 20),
        const SizedBox(width: 4),
        Text(
          status.label,
          style: TextStyle(color: color, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}

/// Chip de clase suspendida.
class SuspendedChip extends StatelessWidget {
  const SuspendedChip({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Chip(
      avatar: Icon(Icons.block, size: 18, color: scheme.error),
      label: const Text('Suspendida'),
      visualDensity: VisualDensity.compact,
    );
  }
}
