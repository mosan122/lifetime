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
    'participants': ['Ana', 'Carlos'],
    'media_assets': [
      {
        'id': 'asset-1',
        'milestone_id': 'ms-1',
        'cloud_file_id': 'drive-abc',
        'thumbnail_url': null,
        'media_type': 'image',
        'metadata': null,
        'created_at': '2026-04-26T10:00:00.000Z',
      }
    ],
    'event_date': '2026-04-26T00:00:00.000Z',
    'location_name': 'Madrid',
    'location_coords': {'type': 'Point', 'coordinates': [-3.7038, 40.4168]},
    'category': 'familia',
    'is_public': false,
    'created_at': '2026-04-26T10:00:00.000Z',
  };

  final tJsonNoCoords = {
    'id': 'ms-2',
    'user_id': 'user-1',
    'title': 'Sin ubicación',
    'description': null,
    'participants': [],
    'media_assets': [],
    'event_date': '2026-04-26T00:00:00.000Z',
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
      expect(model.participants, equals(['Ana', 'Carlos']));
      expect(model.media, hasLength(1));
      expect(model.locationName, equals('Madrid'));
      expect(model.latitude, closeTo(40.4168, 0.0001));
      expect(model.longitude, closeTo(-3.7038, 0.0001));
      expect(model.category, equals('familia'));
      expect(model.isPublic, isFalse);
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
  });

  group('toInsertMap', () {
    test('builds correct insert map with coords', () {
      final map = MilestoneModel.toInsertMap(
        title: 'Mi 30 cumpleaños',
        description: 'Fue un día especial.',
        participants: const ['Ana', 'Carlos'],
        eventDate: DateTime(2026, 4, 26),
        locationName: 'Madrid',
        latitude: 40.4168,
        longitude: -3.7038,
        category: 'familia',
        isPublic: false,
      );

      expect(map['title'], equals('Mi 30 cumpleaños'));
      expect(map['participants'], equals(['Ana', 'Carlos']));
      expect(map['location_coords'], equals('POINT(-3.7038 40.4168)'));
      expect(map.containsKey('id'), isFalse);
      expect(map.containsKey('user_id'), isFalse);
    });

    test('omits location_coords when lat/lng are null', () {
      final map = MilestoneModel.toInsertMap(
        title: 'Test',
        description: null,
        participants: const [],
        eventDate: DateTime(2026, 4, 26),
        locationName: null,
        latitude: null,
        longitude: null,
        category: 'general',
        isPublic: false,
      );

      expect(map.containsKey('location_coords'), isFalse);
    });
  });
}
