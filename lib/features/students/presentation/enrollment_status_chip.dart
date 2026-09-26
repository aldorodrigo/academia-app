import 'package:flutter/material.dart';

import '../data/models.dart';

class EnrollmentStatusChip extends StatelessWidget {
  const EnrollmentStatusChip(this.status, {super.key});

  final EnrollmentStatus status;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (background, foreground) = switch (status) {
      EnrollmentStatus.active || EnrollmentStatus.scholarship => (
        scheme.primaryContainer,
        scheme.onPrimaryContainer,
      ),
      EnrollmentStatus.pending => (
        scheme.tertiaryContainer,
        scheme.onTertiaryContainer,
      ),
      EnrollmentStatus.suspended || EnrollmentStatus.withdrawn => (
        scheme.errorContainer,
        scheme.onErrorContainer,
      ),
    };

    return Chip(
      label: Text(status.label),
      labelStyle: TextStyle(color: foreground),
      backgroundColor: background,
      side: BorderSide.none,
      visualDensity: VisualDensity.compact,
    );
  }
}
