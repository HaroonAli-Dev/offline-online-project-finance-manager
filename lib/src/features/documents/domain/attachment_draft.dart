import '../data/attachment_picker_service.dart';

class AttachmentInput {
  const AttachmentInput({
    required this.category,
    this.description,
    this.latitude,
    this.longitude,
  });

  final String category;
  final String? description;
  final double? latitude;
  final double? longitude;
}

class AttachmentDraft {
  const AttachmentDraft({required this.file, required this.input});

  final PickedFile file;
  final AttachmentInput input;
}
