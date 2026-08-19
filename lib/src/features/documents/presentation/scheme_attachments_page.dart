import 'package:flutter/material.dart';

import '../../schemes/domain/scheme_model.dart';
import 'attachments_panel.dart';

/// Full-screen page showing all attachments for a single scheme.
/// Opened from the scheme card three-dot menu → "View Attachments".
class SchemeAttachmentsPage extends StatelessWidget {
  const SchemeAttachmentsPage({required this.scheme, super.key});

  final SchemeModel scheme;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Attachments', style: TextStyle(fontSize: 18)),
            Text(
              '${scheme.schemeCode} — ${scheme.name}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurface
                    .withValues(alpha: 0.7),
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: AttachmentsPanel(entityType: 'scheme', entityId: scheme.id),
      ),
    );
  }
}
