import 'package:isar/isar.dart';

part 'saved_location_collection.g.dart';

@Collection()
class SavedLocationCollection {
  Id isarId = Isar.autoIncrement;

  /// Id estable para sync Supabase (`saved_locations.client_id`).
  @Index(unique: true)
  String clientId = '';

  late String name;

  /// Dirección postal completa (p. ej. de geocodificación inversa).
  String? address;

  String? city;
  String? country;
  double? latitude;
  double? longitude;
}

