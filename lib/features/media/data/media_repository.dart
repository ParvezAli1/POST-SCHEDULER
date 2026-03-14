import 'package:flutter/foundation.dart';

import '../../../core/models/media_item.dart';

class MediaRepository {
  MediaRepository() {
    mediaNotifier = ValueNotifier<List<MediaItem>>(_seedMedia());
  }

  late final ValueNotifier<List<MediaItem>> mediaNotifier;

  void addPlaceholder() {
    final next = MediaItem(
      id: 'media_${DateTime.now().millisecondsSinceEpoch}',
      name: 'Upload_${mediaNotifier.value.length + 1}.jpg',
      type: MediaType.image,
      sizeInMb: 3.4,
    );

    mediaNotifier.value = [...mediaNotifier.value, next];
  }

  List<MediaItem> _seedMedia() {
    return [
      MediaItem(
        id: 'media_001',
        name: 'Launch_hero.png',
        type: MediaType.image,
        sizeInMb: 4.2,
      ),
      MediaItem(
        id: 'media_002',
        name: 'Product_walkthrough.mp4',
        type: MediaType.video,
        sizeInMb: 48.6,
      ),
      MediaItem(
        id: 'media_003',
        name: 'Behind_scenes.jpg',
        type: MediaType.image,
        sizeInMb: 2.1,
      ),
    ];
  }
}
