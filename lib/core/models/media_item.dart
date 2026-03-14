enum MediaType { image, video }

class MediaItem {
  MediaItem({
    required this.id,
    required this.name,
    required this.type,
    required this.sizeInMb,
  });

  final String id;
  final String name;
  final MediaType type;
  final double sizeInMb;
}
