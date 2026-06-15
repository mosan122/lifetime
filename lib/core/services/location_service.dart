import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';

class LocationData extends Equatable {
  final double latitude;
  final double longitude;
  final String? placeName;

  const LocationData({
    required this.latitude,
    required this.longitude,
    this.placeName,
  });

  @override
  List<Object?> get props => [latitude, longitude, placeName];
}

abstract class LocationService {
  Future<LocationData?> fetchLocation();
}

class LocationServiceImpl implements LocationService {
  @override
  Future<LocationData?> fetchLocation() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return null;

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return null;
      }

      // Fast path: last known position is instant and costs no battery.
      Position? position = await Geolocator.getLastKnownPosition();

      // Slow path: low-accuracy fix with timeout so we never block the UI long.
      position ??= await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.low,
        ),
      ).timeout(const Duration(seconds: 8));

      final placeName = await _reverseGeocode(position.latitude, position.longitude);

      return LocationData(
        latitude: position.latitude,
        longitude: position.longitude,
        placeName: placeName,
      );
    } catch (_) {
      return null;
    }
  }

  Future<String?> _reverseGeocode(double lat, double lng) async {
    try {
      final marks = await placemarkFromCoordinates(lat, lng)
          .timeout(const Duration(seconds: 5));
      if (marks.isEmpty) return null;

      final m = marks.first;
      final parts = [m.locality, m.administrativeArea]
          .whereType<String>()
          .where((s) => s.isNotEmpty)
          .toList();
      if (parts.isEmpty && (m.country?.isNotEmpty ?? false)) {
        parts.add(m.country!);
      }
      final result = parts.take(2).join(', ');
      return result.isEmpty ? null : result;
    } catch (_) {
      return null;
    }
  }
}
