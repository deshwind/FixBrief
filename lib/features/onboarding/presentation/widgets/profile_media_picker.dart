import 'dart:async';

import 'package:fixbrief/features/onboarding/domain/entities/profile_media.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mime/mime.dart';

class ProfileMediaPicker extends StatelessWidget {
  const ProfileMediaPicker({
    required this.label,
    required this.media,
    required this.onSelected,
    super.key,
  });

  final String label;
  final ProfileMedia? media;
  final ValueChanged<ProfileMedia> onSelected;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label:
          '$label. ${media == null ? 'No image selected' : 'Image selected'}',
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => unawaited(_pickImage(context)),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 31,
                backgroundImage: media == null
                    ? null
                    : MemoryImage(media!.bytes),
                child: media == null
                    ? const Icon(Icons.add_a_photo_outlined)
                    : null,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: Theme.of(context).textTheme.titleSmall),
                    const SizedBox(height: 3),
                    Text(
                      media?.fileName ??
                          'Choose a JPG, PNG, HEIC, or WebP image',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickImage(BuildContext context) async {
    try {
      final image = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 1600,
        imageQuality: 88,
      );
      if (image == null) {
        return;
      }
      final bytes = await image.readAsBytes();
      final mimeType =
          lookupMimeType(image.name, headerBytes: bytes.take(16).toList()) ??
          'image/jpeg';
      if (!mimeType.startsWith('image/')) {
        if (context.mounted) {
          _showError(context, 'Choose a supported image file.');
        }
        return;
      }
      if (bytes.lengthInBytes > 8 * 1024 * 1024) {
        if (context.mounted) {
          _showError(context, 'Choose an image smaller than 8 MB.');
        }
        return;
      }
      onSelected(
        ProfileMedia(bytes: bytes, fileName: image.name, mimeType: mimeType),
      );
    } on PlatformException {
      if (context.mounted) {
        _showError(
          context,
          'Photos are unavailable. Check the app permission and try again.',
        );
      }
    }
  }

  static void _showError(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}
