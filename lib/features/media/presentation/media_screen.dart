import 'package:flutter/material.dart';

import '../../../app/services.dart';
import '../../../core/models/media_item.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/section_card.dart';

class MediaScreen extends StatelessWidget {
  const MediaScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final mediaRepository = AppServices.mediaRepository;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Media Library'),
        actions: [
          IconButton(
            icon: const Icon(Icons.cloud_upload_outlined),
            onPressed: mediaRepository.addPlaceholder,
          ),
        ],
      ),
      body: ListView(
        children: [
          SectionCard(
            title: 'Recent uploads',
            trailing: TextButton(
              onPressed: mediaRepository.addPlaceholder,
              child: const Text('Upload'),
            ),
            child: ValueListenableBuilder(
              valueListenable: mediaRepository.mediaNotifier,
              builder: (context, media, _) {
                if (media.isEmpty) {
                  return const EmptyState(
                    title: 'No uploads yet',
                    subtitle: 'Add a placeholder media file to preview posts.',
                  );
                }

                return Column(
                  children: [
                    for (final item in media)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(
                          item.type == MediaType.image
                              ? Icons.image_outlined
                              : Icons.videocam_outlined,
                        ),
                        title: Text(item.name),
                        subtitle: Text(
                          '${item.sizeInMb.toStringAsFixed(1)} MB',
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
          SectionCard(
            title: 'Suggested sizes',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text('Instagram: 1080x1350 (portrait) or 1080x1080'),
                SizedBox(height: 6),
                Text('Facebook: 1200x630 for link previews'),
                SizedBox(height: 6),
                Text('LinkedIn: 1200x628 for updates'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
