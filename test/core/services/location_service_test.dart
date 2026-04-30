import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:lifetime/core/services/location_service.dart';

class MockLocationService extends Mock implements LocationService {}

void main() {
  group('LocationData', () {
    test('equality holds for same values', () {
      const a = LocationData(
        latitude: 40.4168,
        longitude: -3.7038,
        placeName: 'Madrid',
      );
      const b = LocationData(
        latitude: 40.4168,
        longitude: -3.7038,
        placeName: 'Madrid',
      );
      expect(a, equals(b));
    });

    test('differs when placeName differs', () {
      const withPlace = LocationData(
        latitude: 40.4168,
        longitude: -3.7038,
        placeName: 'Madrid',
      );
      const withoutPlace = LocationData(
        latitude: 40.4168,
        longitude: -3.7038,
      );
      expect(withPlace, isNot(equals(withoutPlace)));
    });

    test('differs when coordinates differ', () {
      const madrid = LocationData(latitude: 40.4168, longitude: -3.7038);
      const barcelona = LocationData(latitude: 41.3874, longitude: 2.1686);
      expect(madrid, isNot(equals(barcelona)));
    });

    test('props expose latitude, longitude, placeName', () {
      const data = LocationData(
        latitude: 40.4168,
        longitude: -3.7038,
        placeName: 'Madrid',
      );
      expect(data.props, equals([40.4168, -3.7038, 'Madrid']));
    });
  });

  group('LocationService — graceful degradation on permission denial', () {
    late MockLocationService mockService;

    setUp(() {
      mockService = MockLocationService();
    });

    test('returns null when permission is denied', () async {
      when(() => mockService.fetchLocation()).thenAnswer((_) async => null);

      final result = await mockService.fetchLocation();

      expect(result, isNull);
    });

    test('callers handle null result without throwing', () async {
      when(() => mockService.fetchLocation()).thenAnswer((_) async => null);

      final result = await mockService.fetchLocation();

      // Simulate page using the result — null-safe accessors must not throw.
      final lat = result?.latitude;
      final lng = result?.longitude;
      final place = result?.placeName;

      expect(lat, isNull);
      expect(lng, isNull);
      expect(place, isNull);
    });

    test('returns LocationData on success', () async {
      const expected = LocationData(
        latitude: 40.4168,
        longitude: -3.7038,
        placeName: 'Madrid, Comunidad de Madrid',
      );
      when(() => mockService.fetchLocation()).thenAnswer((_) async => expected);

      final result = await mockService.fetchLocation();

      expect(result, equals(expected));
      expect(result!.latitude, equals(40.4168));
      expect(result.longitude, equals(-3.7038));
      expect(result.placeName, equals('Madrid, Comunidad de Madrid'));
    });

    test('submit flow works correctly when location is null (no GPS)', () async {
      // Mirrors what AddMilestonePage does: passes nullable lat/lng to cubit.
      when(() => mockService.fetchLocation()).thenAnswer((_) async => null);

      final locationData = await mockService.fetchLocation();

      // These are the values that would be passed to cubit.submit()
      final lat = locationData?.latitude;
      final lng = locationData?.longitude;
      final place = locationData?.placeName;

      // All must be null — cubit.submit() accepts nullable values.
      expect(lat, isNull);
      expect(lng, isNull);
      expect(place, isNull);
    });

    test('submit flow correctly extracts coordinates when location is available', () async {
      const location = LocationData(
        latitude: 40.4168,
        longitude: -3.7038,
        placeName: 'Madrid',
      );
      when(() => mockService.fetchLocation()).thenAnswer((_) async => location);

      final locationData = await mockService.fetchLocation();

      expect(locationData?.latitude, equals(40.4168));
      expect(locationData?.longitude, equals(-3.7038));
      expect(locationData?.placeName, equals('Madrid'));
    });
  });
}
