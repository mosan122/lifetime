import 'package:equatable/equatable.dart';

enum MediaType { image, video }

class MediaItem extends Equatable {
  final String localPath;
  final String thumbnailPath;
  final MediaType mediaType;
  final String? driveFileId;
  final bool isSynced;

  const MediaItem({
    required this.localPath,
    required this.thumbnailPath,
    required this.mediaType,
    this.driveFileId,
    this.isSynced = false,
  });

  @override
  List<Object?> get props =>
      [localPath, thumbnailPath, mediaType, driveFileId, isSynced];
}

