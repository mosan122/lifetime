import 'package:isar/isar.dart';

part 'saved_location_collection.g.dart';

@Collection()
class SavedLocationCollection {
  Id isarId = Isar.autoIncrement;

  /// Id estable para sync Supabase (`saved_locations.client_id`).
  @Index(unique: true)
  late String clientId;

  late String name;
  String? city;
  String? country;
  double? latitude;
  double? longitude;
}

