import 'package:flutter/material.dart';

import 'attachments_panel.dart';

/// Reusable attachment screen for any locally stored entity.
class EntityAttachmentsPage extends StatelessWidget {
  const EntityAttachmentsPage({
    required this.entityType,
    required this.entityId,
    required this.title,
    super.key,
  });

  final String entityType;
  final String entityId;
  final String title;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text('Attachments: $title')),
    body: SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: AttachmentsPanel(entityType: entityType, entityId: entityId),
    ),
  );
}
