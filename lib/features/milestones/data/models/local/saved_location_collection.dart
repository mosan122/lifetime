import 'package:isar/isar.dart';

part 'saved_location_collection.g.dart';

@Collection()
class SavedLocationCollection {
  Id isarId = Isar.autoIncrement;

  late String name;
  String? city;
  String? country;
  double? latitude;
  double? longitude;
}

