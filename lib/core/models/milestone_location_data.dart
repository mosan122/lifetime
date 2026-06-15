import 'package:equatable/equatable.dart';

class MilestoneLocationData extends Equatable {
  final String name;
  final String? city;
  final String? country;
  final double? latitude;
  final double? longitude;

  const MilestoneLocationData({
    required this.name,
    this.city,
    this.country,
    this.latitude,
    this.longitude,
  });

  @override
  List<Object?> get props => [name, city, country, latitude, longitude];
}

