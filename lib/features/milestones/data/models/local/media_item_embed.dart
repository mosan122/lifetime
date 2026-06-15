import 'package:isar/isar.dart';

import '../../../../../domain/entities/media_item.dart';

part 'media_item_embed.g.dart';

@Embedded()
class MediaItemEmbed {
  late String localPath;
  late String thumbnailPath;

  @Enumerated(EnumType.name)
  late MediaType mediaType;

  String? driveFileId;
  bool isSynced = false;
  bool isDeleted = false;

  static MediaItemEmbed fromDomain(MediaItem item) {
    return MediaItemEmbed()
      ..localPath = item.localPath
      ..thumbnailPath = item.thumbnailPath
      ..mediaType = item.mediaType
      ..driveFileId = item.driveFileId
      ..isSynced = item.isSynced
      ..isDeleted = item.isDeleted;
  }

  MediaItem toDomain() {
    return MediaItem(
      localPath: localPath,
      thumbnailPath: thumbnailPath,
      mediaType: mediaType,
      driveFileId: driveFileId,
      isSynced: isSynced,
      isDeleted: isDeleted,
    );
  }
}

