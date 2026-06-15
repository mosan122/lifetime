import 'package:flutter_test/flutter_test.dart';
import 'package:lifetime/data/models/milestone_model.dart';
import 'package:lifetime/domain/entities/milestone.dart';

void main() {
  // GeoJSON: PostgREST devuelve GEOGRAPHY como {"type":"Point","coordinates":[lng, lat]}
  final tJsonWithCoords = {
    'id': 'ms-1',
    'user_id': 'user-1',
    'title': 'Mi 30 cumpleaños',
    'description': 'Fue un día especial.',
    'participant_ids': ['p-ana', 'p-carlos'],
    'milestone_date': '2026-04-26T00:00:00.000Z',
    'location_name': 'Madrid',
    'location_coords': {'type': 'Point', 'coordinates': [-3.7038, 40.4168]},
    'category': 'familia',
    'is_public': false,
    'created_at': '2026-04-26T10:00:00.000Z',
    'drive_file_id': 'drive-abc-123',
  };

  final tJsonNoCoords = {
    'id': 'ms-2',
    'user_id': 'user-1',
    'title': 'Sin ubicación',
    'description': null,
    'participant_ids': <String>[],
    'milestone_date': '2026-04-26T00:00:00.000Z',
    'location_name': null,
    'location_coords': null,
    'category': 'general',
    'is_public': false,
    'created_at': '2026-04-26T10:00:00.000Z',
  };

  group('fromJson', () {
    test('parses all fields correctly', () {
      final model = MilestoneModel.fromJson(tJsonWithCoords);

      expect(model.id, equals('ms-1'));
      expect(model.userId, equals('user-1'));
      expect(model.title, equals('Mi 30 cumpleaños'));
      expect(model.description, equals('Fue un día especial.'));
      expect(model.participantIds, equals(['p-ana', 'p-carlos']));
      expect(model.participants, equals(['p-ana', 'p-carlos']));
      expect(model.media, isEmpty);
      expect(model.locationName, equals('Madrid'));
      expect(model.latitude, closeTo(40.4168, 0.0001));
      expect(model.longitude, closeTo(-3.7038, 0.0001));
      expect(model.categoryId, equals('familia'));
      expect(model.isPublic, isFalse);
      expect(model.driveFileId, equals('drive-abc-123'));
    });

    test('parses drive_file_id as null when absent', () {
      final model = MilestoneModel.fromJson(tJsonNoCoords);
      expect(model.driveFileId, isNull);
    });

    test('parses GeoJSON coordinates into lat/lng', () {
      final model = MilestoneModel.fromJson(tJsonWithCoords);
      expect(model.latitude, closeTo(40.4168, 0.0001));
      expect(model.longitude, closeTo(-3.7038, 0.0001));
    });

    test('handles null location_coords', () {
      final model = MilestoneModel.fromJson(tJsonNoCoords);
      expect(model.latitude, isNull);
      expect(model.longitude, isNull);
    });

    test('is a Milestone entity', () {
      expect(MilestoneModel.fromJson(tJsonWithCoords), isA<Milestone>());
    });

    test('preserves custom category client_id (UUID)', () {
      const customId = 'a1b2c3d4-e5f6-4789-a012-3456789abcde';
      final model = MilestoneModel.fromJson({
        ...tJsonWithCoords,
        'category': customId,
      });
      expect(model.categoryId, customId);
    });

    test('maps legacy category label general to otros', () {
      final model = MilestoneModel.fromJson(tJsonNoCoords);
      expect(model.categoryId, 'otros');
    });
  });

  group('toInsertMap', () {
    test('builds correct insert map with coords', () {
      final map = MilestoneModel.toInsertMap(
        title: 'Mi 30 cumpleaños',
        description: 'Fue un día especial.',
        participantIds: const ['p-ana', 'p-carlos'],
        eventDate: DateTime(2026, 4, 26),
        locationName: 'Madrid',
        latitude: 40.4168,
        longitude: -3.7038,
        categoryId: 'familia',
        isPublic: false,
      );

      expect(map['title'], equals('Mi 30 cumpleaños'));
      expect(map['participant_ids'], equals(['p-ana', 'p-carlos']));
      expect(map.containsKey('participants'), isFalse);
      expect(map['latitude'], 40.4168);
      expect(map['longitude'], -3.7038);
      expect(map.containsKey('id'), isFalse);
      expect(map.containsKey('user_id'), isFalse);
    });

    test('omits latitude/longitude when lat/lng are null', () {
      final map = MilestoneModel.toInsertMap(
        title: 'Test',
        description: null,
        eventDate: DateTime(2026, 4, 26),
        locationName: null,
        latitude: null,
        longitude: null,
        categoryId: 'general',
        isPublic: false,
      );

      expect(map.containsKey('latitude'), isFalse);
      expect(map.containsKey('longitude'), isFalse);
    });

    test('includes milestone_date for Supabase', () {
      final map = MilestoneModel.toInsertMap(
        title: 'T',
        description: null,
        eventDate: DateTime.utc(2026, 4, 26),
        locationName: null,
        latitude: null,
        longitude: null,
        categoryId: 'general',
        isPublic: false,
      );

      expect(map['milestone_date'], isNotNull);
      expect(map.containsKey('event_date'), isFalse);
    });

    test('stores latitude and longitude as separate columns', () {
      final map = MilestoneModel.toInsertMap(
        title: 'T',
        description: null,
        eventDate: DateTime(2026, 4, 26),
        locationName: null,
        latitude: 40.4168,
        longitude: -3.7038,
        categoryId: 'general',
        isPublic: false,
      );

      expect(map['latitude'], 40.4168);
      expect(map['longitude'], -3.7038);
    });

    test('omits lat/lng when only one coordinate is provided', () {
      final mapLatOnly = MilestoneModel.toInsertMap(
        title: 'T',
        description: null,
        eventDate: DateTime(2026, 4, 26),
        locationName: null,
        latitude: 40.4168,
        longitude: null,
        categoryId: 'general',
        isPublic: false,
      );
      final mapLngOnly = MilestoneModel.toInsertMap(
        title: 'T',
        description: null,
        eventDate: DateTime(2026, 4, 26),
        locationName: null,
        latitude: null,
        longitude: -3.7038,
        categoryId: 'general',
        isPublic: false,
      );

      expect(mapLatOnly.containsKey('latitude'), isFalse);
      expect(mapLngOnly.containsKey('longitude'), isFalse);
    });
  });

  group('lat/lng round-trip', () {
    test('toInsertMap matches fromJson latitude/longitude columns', () {
      const lat = 40.4168;
      const lng = -3.7038;

      final model = MilestoneModel.fromJson({
        'id': 'ms-rt',
        'user_id': 'u-1',
        'title': 'Round-trip',
        'participant_ids': <String>[],
        'milestone_date': '2026-04-26T00:00:00.000Z',
        'category': 'general',
        'is_public': false,
        'created_at': '2026-04-26T10:00:00.000Z',
        'latitude': lat,
        'longitude': lng,
      });

      expect(model.latitude, equals(lat));
      expect(model.longitude, equals(lng));
    });
  });
}
