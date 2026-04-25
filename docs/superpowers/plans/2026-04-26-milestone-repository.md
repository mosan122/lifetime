# Milestone Repository Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implementar la capa de datos de Milestones en Flutter: entidades de dominio, interfaz del repositorio, datasource remoto (Edge Function + Supabase) e implementación del repositorio con manejo de errores mediante `Either`.

**Architecture:** Clean Architecture con tres capas separadas — `domain` (entidades + interfaz abstracta), `data/models` (mapeo JSON), `data/datasources` (transporte HTTP/Supabase) y `data/repositories` (orquestación + conversión de errores). La capa de dominio no importa nada de Supabase.

**Tech Stack:** Flutter >=3.10 · Dart 3 · supabase_flutter ^2.5.0 · dartz ^0.10.1 · equatable ^2.0.5 · mocktail ^0.3.0 (dev)

---

## Mapa de archivos

| Archivo | Responsabilidad |
|---|---|
| `pubspec.yaml` | Dependencias del proyecto |
| `lib/core/failures/failure.dart` | Clases base de errores del dominio |
| `lib/domain/entities/media_asset_entity.dart` | Entidad pura MediaAsset |
| `lib/domain/entities/milestone.dart` | Entidad pura Milestone |
| `lib/domain/repositories/milestone_repository.dart` | Interfaz abstracta del repositorio |
| `lib/data/models/media_asset_model.dart` | Mapeo JSON ↔ MediaAssetEntity |
| `lib/data/models/milestone_model.dart` | Mapeo JSON ↔ Milestone + WKT geography |
| `lib/data/datasources/milestone_remote_datasource.dart` | Interfaz + impl: Edge Function y Supabase |
| `lib/data/repositories/milestone_repository_impl.dart` | Orquesta datasource, convierte errores a Failure |
| `supabase/migrations/20260426_add_participants.sql` | ALTER TABLE milestones ADD COLUMN participants |
| `test/domain/entities/media_asset_entity_test.dart` | Tests Equatable de MediaAssetEntity |
| `test/domain/entities/milestone_test.dart` | Tests Equatable de Milestone |
| `test/data/models/media_asset_model_test.dart` | Tests fromJson de MediaAssetModel |
| `test/data/models/milestone_model_test.dart` | Tests fromJson/toInsertMap de MilestoneModel |
| `test/data/repositories/milestone_repository_impl_test.dart` | Tests del repositorio con datasource mockeado |

---

## Task 1: pubspec.yaml

**Files:**
- Create: `pubspec.yaml`

- [ ] **Step 1: Crear pubspec.yaml**

```yaml
name: lifetime
description: A digital time capsule for life milestones.
publish_to: 'none'
version: 1.0.0+1

environment:
  sdk: '>=3.0.0 <4.0.0'
  flutter: ">=3.10.0"

dependencies:
  flutter:
    sdk: flutter
  supabase_flutter: ^2.5.0
  dartz: ^0.10.1
  equatable: ^2.0.5

dev_dependencies:
  flutter_test:
    sdk: flutter
  mocktail: ^0.3.0
  flutter_lints: ^3.0.0
```

- [ ] **Step 2: Instalar dependencias**

```bash
flutter pub get
```

Expected: `Resolving dependencies... Got dependencies!`

- [ ] **Step 3: Commit**

```bash
git add pubspec.yaml pubspec.lock
git commit -m "chore: add Flutter dependencies for Milestone feature"
```

---

## Task 2: Failure classes

**Files:**
- Create: `lib/core/failures/failure.dart`

- [ ] **Step 1: Crear failure.dart**

```dart
import 'package:equatable/equatable.dart';

abstract class Failure extends Equatable {
  final String message;
  const Failure(this.message);

  @override
  List<Object> get props => [message];
}

class AuthFailure extends Failure {
  const AuthFailure([String message = 'Authentication error']) : super(message);
}

class DatabaseFailure extends Failure {
  const DatabaseFailure(String message) : super(message);
}

class NetworkFailure extends Failure {
  const NetworkFailure([String message = 'Network error']) : super(message);
}

class BiographerFailure extends Failure {
  const BiographerFailure([String message = 'Biographer service error'])
      : super(message);
}
```

- [ ] **Step 2: Commit**

```bash
git add lib/core/failures/failure.dart
git commit -m "feat: add domain Failure classes"
```

---

## Task 3: MediaAssetEntity

**Files:**
- Create: `lib/domain/entities/media_asset_entity.dart`
- Create: `test/domain/entities/media_asset_entity_test.dart`

- [ ] **Step 1: Escribir el test que falla**

```dart
// test/domain/entities/media_asset_entity_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:lifetime/domain/entities/media_asset_entity.dart';

void main() {
  final createdAt = DateTime(2026, 4, 26);

  MediaAssetEntity makeEntity({String id = 'asset-1'}) => MediaAssetEntity(
        id: id,
        milestoneId: 'ms-1',
        cloudFileId: 'drive-abc123',
        thumbnailUrl: 'https://example.com/thumb.jpg',
        mediaType: 'image',
        metadata: {'width': 1920, 'height': 1080},
        createdAt: createdAt,
      );

  test('two instances with same props are equal', () {
    expect(makeEntity(), equals(makeEntity()));
  });

  test('instances with different id are not equal', () {
    expect(makeEntity(id: 'asset-1'), isNot(equals(makeEntity(id: 'asset-2'))));
  });

  test('props list contains all fields', () {
    final entity = makeEntity();
    expect(entity.props, hasLength(7));
  });
}
```

- [ ] **Step 2: Ejecutar para verificar que falla**

```bash
flutter test test/domain/entities/media_asset_entity_test.dart
```

Expected: `Error: Target of URI doesn't exist 'package:lifetime/domain/entities/media_asset_entity.dart'`

- [ ] **Step 3: Implementar la entidad**

```dart
// lib/domain/entities/media_asset_entity.dart
import 'package:equatable/equatable.dart';

class MediaAssetEntity extends Equatable {
  final String id;
  final String milestoneId;
  final String cloudFileId;
  final String? thumbnailUrl;
  final String mediaType;
  final Map<String, dynamic>? metadata;
  final DateTime createdAt;

  const MediaAssetEntity({
    required this.id,
    required this.milestoneId,
    required this.cloudFileId,
    this.thumbnailUrl,
    required this.mediaType,
    this.metadata,
    required this.createdAt,
  });

  @override
  List<Object?> get props =>
      [id, milestoneId, cloudFileId, thumbnailUrl, mediaType, metadata, createdAt];
}
```

- [ ] **Step 4: Ejecutar para verificar que pasan**

```bash
flutter test test/domain/entities/media_asset_entity_test.dart
```

Expected: `All tests passed!`

- [ ] **Step 5: Commit**

```bash
git add lib/domain/entities/media_asset_entity.dart test/domain/entities/media_asset_entity_test.dart
git commit -m "feat: add MediaAssetEntity domain entity"
```

---

## Task 4: Milestone entity

**Files:**
- Create: `lib/domain/entities/milestone.dart`
- Create: `test/domain/entities/milestone_test.dart`

- [ ] **Step 1: Escribir el test que falla**

```dart
// test/domain/entities/milestone_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:lifetime/domain/entities/milestone.dart';
import 'package:lifetime/domain/entities/media_asset_entity.dart';

void main() {
  final eventDate = DateTime(2026, 4, 26);
  final createdAt = DateTime(2026, 4, 26, 10, 0);
  final tMedia = MediaAssetEntity(
    id: 'asset-1',
    milestoneId: 'ms-1',
    cloudFileId: 'drive-abc',
    mediaType: 'image',
    createdAt: createdAt,
  );

  Milestone makeMilestone({String id = 'ms-1'}) => Milestone(
        id: id,
        userId: 'user-1',
        title: 'Mi 30 cumpleaños',
        description: 'Fue un día especial.',
        participants: const ['Ana', 'Carlos'],
        media: [tMedia],
        eventDate: eventDate,
        locationName: 'Madrid',
        latitude: 40.4168,
        longitude: -3.7038,
        category: 'familia',
        isPublic: false,
        createdAt: createdAt,
      );

  test('two instances with same props are equal', () {
    expect(makeMilestone(), equals(makeMilestone()));
  });

  test('instances with different id are not equal', () {
    expect(makeMilestone(id: 'ms-1'), isNot(equals(makeMilestone(id: 'ms-2'))));
  });

  test('default category is general', () {
    final m = Milestone(
      id: 'ms-1',
      userId: 'user-1',
      title: 'Test',
      eventDate: eventDate,
      createdAt: createdAt,
    );
    expect(m.category, equals('general'));
  });

  test('default isPublic is false', () {
    final m = Milestone(
      id: 'ms-1',
      userId: 'user-1',
      title: 'Test',
      eventDate: eventDate,
      createdAt: createdAt,
    );
    expect(m.isPublic, isFalse);
  });

  test('props list contains all 13 fields', () {
    expect(makeMilestone().props, hasLength(13));
  });
}
```

- [ ] **Step 2: Ejecutar para verificar que falla**

```bash
flutter test test/domain/entities/milestone_test.dart
```

Expected: `Error: Target of URI doesn't exist 'package:lifetime/domain/entities/milestone.dart'`

- [ ] **Step 3: Implementar la entidad**

```dart
// lib/domain/entities/milestone.dart
import 'package:equatable/equatable.dart';
import 'media_asset_entity.dart';

class Milestone extends Equatable {
  final String id;
  final String userId;
  final String title;
  final String? description;
  final List<String> participants;
  final List<MediaAssetEntity> media;
  final DateTime eventDate;
  final String? locationName;
  final double? latitude;
  final double? longitude;
  final String category;
  final bool isPublic;
  final DateTime createdAt;

  const Milestone({
    required this.id,
    required this.userId,
    required this.title,
    this.description,
    this.participants = const [],
    this.media = const [],
    required this.eventDate,
    this.locationName,
    this.latitude,
    this.longitude,
    this.category = 'general',
    this.isPublic = false,
    required this.createdAt,
  });

  @override
  List<Object?> get props => [
        id, userId, title, description, participants, media,
        eventDate, locationName, latitude, longitude,
        category, isPublic, createdAt,
      ];
}
```

- [ ] **Step 4: Ejecutar para verificar que pasan**

```bash
flutter test test/domain/entities/milestone_test.dart
```

Expected: `All tests passed!`

- [ ] **Step 5: Commit**

```bash
git add lib/domain/entities/milestone.dart test/domain/entities/milestone_test.dart
git commit -m "feat: add Milestone domain entity with participants and media"
```

---

## Task 5: MilestoneRepository interface

**Files:**
- Create: `lib/domain/repositories/milestone_repository.dart`

No test directo — la interfaz abstracta se verifica implícitamente al testear el impl en Task 9.

- [ ] **Step 1: Crear la interfaz**

```dart
// lib/domain/repositories/milestone_repository.dart
import 'package:dartz/dartz.dart';
import '../entities/milestone.dart';
import '../../core/failures/failure.dart';

abstract class MilestoneRepository {
  Future<Either<Failure, Milestone>> createMilestone({
    required String userNote,
    required DateTime eventDate,
    String? locationName,
    double? latitude,
    double? longitude,
    String category = 'general',
    List<String> participants = const [],
    bool isPublic = false,
  });

  Future<Either<Failure, List<Milestone>>> getMilestones();

  Future<Either<Failure, Milestone>> getMilestoneById(String id);
}
```

- [ ] **Step 2: Verificar que el proyecto compila**

```bash
flutter analyze lib/domain/
```

Expected: `No issues found!`

- [ ] **Step 3: Commit**

```bash
git add lib/domain/repositories/milestone_repository.dart
git commit -m "feat: add MilestoneRepository abstract interface"
```

---

## Task 6: MediaAssetModel

**Files:**
- Create: `lib/data/models/media_asset_model.dart`
- Create: `test/data/models/media_asset_model_test.dart`

- [ ] **Step 1: Escribir el test que falla**

```dart
// test/data/models/media_asset_model_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:lifetime/data/models/media_asset_model.dart';
import 'package:lifetime/domain/entities/media_asset_entity.dart';

void main() {
  final tJson = {
    'id': 'asset-1',
    'milestone_id': 'ms-1',
    'cloud_file_id': 'drive-abc123',
    'thumbnail_url': 'https://example.com/thumb.jpg',
    'media_type': 'image',
    'metadata': {'width': 1920, 'height': 1080},
    'created_at': '2026-04-26T10:00:00.000Z',
  };

  test('fromJson creates correct MediaAssetModel', () {
    final model = MediaAssetModel.fromJson(tJson);

    expect(model.id, equals('asset-1'));
    expect(model.milestoneId, equals('ms-1'));
    expect(model.cloudFileId, equals('drive-abc123'));
    expect(model.thumbnailUrl, equals('https://example.com/thumb.jpg'));
    expect(model.mediaType, equals('image'));
    expect(model.metadata, equals({'width': 1920, 'height': 1080}));
    expect(model.createdAt, equals(DateTime.parse('2026-04-26T10:00:00.000Z')));
  });

  test('fromJson handles null thumbnailUrl and metadata', () {
    final json = Map<String, dynamic>.from(tJson)
      ..remove('thumbnail_url')
      ..remove('metadata');

    final model = MediaAssetModel.fromJson(json);

    expect(model.thumbnailUrl, isNull);
    expect(model.metadata, isNull);
  });

  test('is a MediaAssetEntity', () {
    expect(MediaAssetModel.fromJson(tJson), isA<MediaAssetEntity>());
  });
}
```

- [ ] **Step 2: Ejecutar para verificar que falla**

```bash
flutter test test/data/models/media_asset_model_test.dart
```

Expected: `Error: Target of URI doesn't exist 'package:lifetime/data/models/media_asset_model.dart'`

- [ ] **Step 3: Implementar el modelo**

```dart
// lib/data/models/media_asset_model.dart
import '../../domain/entities/media_asset_entity.dart';

class MediaAssetModel extends MediaAssetEntity {
  const MediaAssetModel({
    required super.id,
    required super.milestoneId,
    required super.cloudFileId,
    super.thumbnailUrl,
    required super.mediaType,
    super.metadata,
    required super.createdAt,
  });

  factory MediaAssetModel.fromJson(Map<String, dynamic> json) {
    return MediaAssetModel(
      id: json['id'] as String,
      milestoneId: json['milestone_id'] as String,
      cloudFileId: json['cloud_file_id'] as String,
      thumbnailUrl: json['thumbnail_url'] as String?,
      mediaType: json['media_type'] as String,
      metadata: json['metadata'] as Map<String, dynamic>?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}
```

- [ ] **Step 4: Ejecutar para verificar que pasan**

```bash
flutter test test/data/models/media_asset_model_test.dart
```

Expected: `All tests passed!`

- [ ] **Step 5: Commit**

```bash
git add lib/data/models/media_asset_model.dart test/data/models/media_asset_model_test.dart
git commit -m "feat: add MediaAssetModel with fromJson"
```

---

## Task 7: MilestoneModel

**Files:**
- Create: `lib/data/models/milestone_model.dart`
- Create: `test/data/models/milestone_model_test.dart`

- [ ] **Step 1: Escribir el test que falla**

```dart
// test/data/models/milestone_model_test.dart
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
```

- [ ] **Step 2: Ejecutar para verificar que falla**

```bash
flutter test test/data/models/milestone_model_test.dart
```

Expected: `Error: Target of URI doesn't exist 'package:lifetime/data/models/milestone_model.dart'`

- [ ] **Step 3: Implementar el modelo**

```dart
// lib/data/models/milestone_model.dart
import '../../domain/entities/milestone.dart';
import 'media_asset_model.dart';

class MilestoneModel extends Milestone {
  const MilestoneModel({
    required super.id,
    required super.userId,
    required super.title,
    super.description,
    super.participants = const [],
    super.media = const [],
    required super.eventDate,
    super.locationName,
    super.latitude,
    super.longitude,
    super.category = 'general',
    super.isPublic = false,
    required super.createdAt,
  });

  factory MilestoneModel.fromJson(Map<String, dynamic> json) {
    double? latitude;
    double? longitude;

    final coords = json['location_coords'];
    if (coords is Map) {
      // PostgREST devuelve GEOGRAPHY como GeoJSON: {"type":"Point","coordinates":[lng, lat]}
      final coordinates = coords['coordinates'] as List;
      longitude = (coordinates[0] as num).toDouble();
      latitude = (coordinates[1] as num).toDouble();
    }

    return MilestoneModel(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      title: json['title'] as String,
      description: json['description'] as String?,
      participants: List<String>.from(json['participants'] as List? ?? []),
      media: (json['media_assets'] as List? ?? [])
          .map((e) => MediaAssetModel.fromJson(e as Map<String, dynamic>))
          .toList(),
      eventDate: DateTime.parse(json['event_date'] as String),
      locationName: json['location_name'] as String?,
      latitude: latitude,
      longitude: longitude,
      category: json['category'] as String? ?? 'general',
      isPublic: json['is_public'] as bool? ?? false,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  // Método estático para construir el payload de inserción.
  // No incluye 'id', 'user_id' ni 'created_at' — los genera Supabase.
  static Map<String, dynamic> toInsertMap({
    required String title,
    required String? description,
    required List<String> participants,
    required DateTime eventDate,
    required String? locationName,
    required double? latitude,
    required double? longitude,
    required String category,
    required bool isPublic,
  }) {
    final map = <String, dynamic>{
      'title': title,
      'description': description,
      'participants': participants,
      'event_date': eventDate.toIso8601String(),
      'location_name': locationName,
      'category': category,
      'is_public': isPublic,
    };
    if (latitude != null && longitude != null) {
      map['location_coords'] = 'POINT($longitude $latitude)';
    }
    return map;
  }
}
```

- [ ] **Step 4: Ejecutar para verificar que pasan**

```bash
flutter test test/data/models/milestone_model_test.dart
```

Expected: `All tests passed!`

- [ ] **Step 5: Commit**

```bash
git add lib/data/models/milestone_model.dart test/data/models/milestone_model_test.dart
git commit -m "feat: add MilestoneModel with fromJson and toInsertMap (WKT geography)"
```

---

## Task 8: MilestoneRemoteDataSource

**Files:**
- Create: `lib/data/datasources/milestone_remote_datasource.dart`

Esta implementación llama a la Edge Function y a Supabase. Se testa implícitamente vía integración con Supabase local — no requiere unit test en este scope.

- [ ] **Step 1: Crear interfaz e implementación**

```dart
// lib/data/datasources/milestone_remote_datasource.dart
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/milestone_model.dart';

typedef BiographerResult = ({String title, String narrative});

abstract class MilestoneRemoteDataSource {
  Future<BiographerResult> callBiographerNarrative({
    required String userNote,
    required DateTime date,
    String? location,
  });

  Future<MilestoneModel> insertMilestone(Map<String, dynamic> data);
  Future<List<MilestoneModel>> fetchMilestones();
  Future<MilestoneModel> fetchMilestoneById(String id);
}

class MilestoneRemoteDataSourceImpl implements MilestoneRemoteDataSource {
  final SupabaseClient _supabase;

  const MilestoneRemoteDataSourceImpl(this._supabase);

  @override
  Future<BiographerResult> callBiographerNarrative({
    required String userNote,
    required DateTime date,
    String? location,
  }) async {
    final response = await _supabase.functions.invoke(
      'biographer-narrative',
      body: {
        'metadata': {
          'date': date.toIso8601String(),
          if (location != null) 'location': location,
        },
        'userNote': userNote,
      },
    );

    final data = response.data as Map<String, dynamic>;
    final title = data['title'] as String?;
    final narrative = data['narrative'] as String?;

    if (title == null || narrative == null) {
      throw const FormatException('Missing title or narrative in biographer response');
    }

    return (title: title, narrative: narrative);
  }

  @override
  Future<MilestoneModel> insertMilestone(Map<String, dynamic> data) async {
    final userId = _supabase.auth.currentUser!.id;
    final response = await _supabase
        .from('milestones')
        .insert({...data, 'user_id': userId})
        .select('*, media_assets(*)')
        .single();
    return MilestoneModel.fromJson(response);
  }

  @override
  Future<List<MilestoneModel>> fetchMilestones() async {
    final userId = _supabase.auth.currentUser!.id;
    final response = await _supabase
        .from('milestones')
        .select('*, media_assets(*)')
        .eq('user_id', userId)
        .order('event_date', ascending: false);
    return (response as List)
        .map((e) => MilestoneModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<MilestoneModel> fetchMilestoneById(String id) async {
    final response = await _supabase
        .from('milestones')
        .select('*, media_assets(*)')
        .eq('id', id)
        .single();
    return MilestoneModel.fromJson(response);
  }
}
```

- [ ] **Step 2: Verificar que compila**

```bash
flutter analyze lib/data/datasources/
```

Expected: `No issues found!`

- [ ] **Step 3: Commit**

```bash
git add lib/data/datasources/milestone_remote_datasource.dart
git commit -m "feat: add MilestoneRemoteDataSource interface and Supabase implementation"
```

---

## Task 9: MilestoneRepositoryImpl

**Files:**
- Create: `lib/data/repositories/milestone_repository_impl.dart`
- Create: `test/data/repositories/milestone_repository_impl_test.dart`

- [ ] **Step 1: Escribir el test que falla**

```dart
// test/data/repositories/milestone_repository_impl_test.dart
import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:lifetime/core/failures/failure.dart';
import 'package:lifetime/data/datasources/milestone_remote_datasource.dart';
import 'package:lifetime/data/models/milestone_model.dart';
import 'package:lifetime/data/repositories/milestone_repository_impl.dart';

class MockMilestoneRemoteDataSource extends Mock
    implements MilestoneRemoteDataSource {}

void main() {
  late MockMilestoneRemoteDataSource mockDatasource;
  late MilestoneRepositoryImpl repository;

  final tDate = DateTime(2026, 4, 26);
  const tUserNote = 'Celebré mi 30 cumpleaños con amigos.';
  const tLocationName = 'Madrid';

  final tBiographerResult =
      (title: 'Mi 30 cumpleaños', narrative: 'Fue un día especial.');

  final tMilestoneModel = MilestoneModel(
    id: 'ms-1',
    userId: 'user-1',
    title: 'Mi 30 cumpleaños',
    description: 'Fue un día especial.',
    participants: const ['Ana'],
    media: const [],
    eventDate: DateTime(2026, 4, 26),
    locationName: 'Madrid',
    latitude: 40.4168,
    longitude: -3.7038,
    category: 'familia',
    isPublic: false,
    createdAt: DateTime(2026, 4, 26, 10),
  );

  setUp(() {
    mockDatasource = MockMilestoneRemoteDataSource();
    repository = MilestoneRepositoryImpl(mockDatasource);
  });

  group('createMilestone', () {
    void stubBiographerSuccess() {
      when(() => mockDatasource.callBiographerNarrative(
            userNote: any(named: 'userNote'),
            date: any(named: 'date'),
            location: any(named: 'location'),
          )).thenAnswer((_) async => tBiographerResult);
    }

    test('returns Right(Milestone) on full success', () async {
      stubBiographerSuccess();
      when(() => mockDatasource.insertMilestone(any()))
          .thenAnswer((_) async => tMilestoneModel);

      final result = await repository.createMilestone(
        userNote: tUserNote,
        eventDate: tDate,
        locationName: tLocationName,
        latitude: 40.4168,
        longitude: -3.7038,
        category: 'familia',
        participants: ['Ana'],
      );

      expect(result, Right(tMilestoneModel));
    });

    test('insert map includes POINT WKT when lat/lng provided', () async {
      stubBiographerSuccess();
      Map<String, dynamic>? capturedData;
      when(() => mockDatasource.insertMilestone(any())).thenAnswer((inv) async {
        capturedData = inv.positionalArguments[0] as Map<String, dynamic>;
        return tMilestoneModel;
      });

      await repository.createMilestone(
        userNote: tUserNote,
        eventDate: tDate,
        latitude: 40.4168,
        longitude: -3.7038,
      );

      expect(capturedData!['location_coords'], equals('POINT(-3.7038 40.4168)'));
    });

    test('insert map omits location_coords when lat/lng are null', () async {
      stubBiographerSuccess();
      Map<String, dynamic>? capturedData;
      when(() => mockDatasource.insertMilestone(any())).thenAnswer((inv) async {
        capturedData = inv.positionalArguments[0] as Map<String, dynamic>;
        return tMilestoneModel;
      });

      await repository.createMilestone(
        userNote: tUserNote,
        eventDate: tDate,
      );

      expect(capturedData!.containsKey('location_coords'), isFalse);
    });

    test('returns Left(AuthFailure) when AuthException is thrown', () async {
      when(() => mockDatasource.callBiographerNarrative(
            userNote: any(named: 'userNote'),
            date: any(named: 'date'),
            location: any(named: 'location'),
          )).thenThrow(const AuthException('Not authenticated'));

      final result = await repository.createMilestone(
        userNote: tUserNote,
        eventDate: tDate,
      );

      expect(result.isLeft(), isTrue);
      result.fold(
        (f) => expect(f, isA<AuthFailure>()),
        (_) => fail('Expected Left'),
      );
    });

    test('returns Left(DatabaseFailure) when PostgrestException is thrown on insert', () async {
      stubBiographerSuccess();
      when(() => mockDatasource.insertMilestone(any())).thenThrow(
        PostgrestException(message: 'duplicate key', code: '23505'),
      );

      final result = await repository.createMilestone(
        userNote: tUserNote,
        eventDate: tDate,
      );

      expect(result.isLeft(), isTrue);
      result.fold(
        (f) => expect(f, isA<DatabaseFailure>()),
        (_) => fail('Expected Left'),
      );
    });

    test('returns Left(BiographerFailure) when FormatException is thrown', () async {
      when(() => mockDatasource.callBiographerNarrative(
            userNote: any(named: 'userNote'),
            date: any(named: 'date'),
            location: any(named: 'location'),
          )).thenThrow(const FormatException('Missing narrative'));

      final result = await repository.createMilestone(
        userNote: tUserNote,
        eventDate: tDate,
      );

      expect(result, const Left(BiographerFailure()));
    });
  });

  group('getMilestones', () {
    test('returns Right(List<Milestone>) on success', () async {
      when(() => mockDatasource.fetchMilestones())
          .thenAnswer((_) async => [tMilestoneModel]);

      final result = await repository.getMilestones();

      expect(result, Right([tMilestoneModel]));
    });

    test('returns Left(DatabaseFailure) when PostgrestException is thrown', () async {
      when(() => mockDatasource.fetchMilestones()).thenThrow(
        PostgrestException(message: 'connection error', code: '08000'),
      );

      final result = await repository.getMilestones();

      result.fold(
        (f) => expect(f, isA<DatabaseFailure>()),
        (_) => fail('Expected Left'),
      );
    });
  });

  group('getMilestoneById', () {
    test('returns Right(Milestone) on success', () async {
      when(() => mockDatasource.fetchMilestoneById('ms-1'))
          .thenAnswer((_) async => tMilestoneModel);

      final result = await repository.getMilestoneById('ms-1');

      expect(result, Right(tMilestoneModel));
    });

    test('returns Left(DatabaseFailure) when PostgrestException is thrown', () async {
      when(() => mockDatasource.fetchMilestoneById(any())).thenThrow(
        PostgrestException(message: 'not found', code: 'PGRST116'),
      );

      final result = await repository.getMilestoneById('ms-999');

      result.fold(
        (f) => expect(f, isA<DatabaseFailure>()),
        (_) => fail('Expected Left'),
      );
    });
  });
}
```

- [ ] **Step 2: Ejecutar para verificar que falla**

```bash
flutter test test/data/repositories/milestone_repository_impl_test.dart
```

Expected: `Error: Target of URI doesn't exist 'package:lifetime/data/repositories/milestone_repository_impl.dart'`

- [ ] **Step 3: Implementar el repositorio**

```dart
// lib/data/repositories/milestone_repository_impl.dart
import 'package:dartz/dartz.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/failures/failure.dart';
import '../../domain/entities/milestone.dart';
import '../../domain/repositories/milestone_repository.dart';
import '../datasources/milestone_remote_datasource.dart';
import '../models/milestone_model.dart';

class MilestoneRepositoryImpl implements MilestoneRepository {
  final MilestoneRemoteDataSource _datasource;

  const MilestoneRepositoryImpl(this._datasource);

  @override
  Future<Either<Failure, Milestone>> createMilestone({
    required String userNote,
    required DateTime eventDate,
    String? locationName,
    double? latitude,
    double? longitude,
    String category = 'general',
    List<String> participants = const [],
    bool isPublic = false,
  }) async {
    try {
      final result = await _datasource.callBiographerNarrative(
        userNote: userNote,
        date: eventDate,
        location: locationName,
      );

      final insertData = MilestoneModel.toInsertMap(
        title: result.title,
        description: result.narrative,
        participants: participants,
        eventDate: eventDate,
        locationName: locationName,
        latitude: latitude,
        longitude: longitude,
        category: category,
        isPublic: isPublic,
      );

      final model = await _datasource.insertMilestone(insertData);
      return Right(model);
    } on AuthException {
      return const Left(AuthFailure());
    } on PostgrestException catch (e) {
      return Left(DatabaseFailure(e.message));
    } on FunctionException catch (e) {
      return Left(NetworkFailure(e.details?.toString() ?? 'Edge Function error'));
    } on FormatException {
      return const Left(BiographerFailure());
    } catch (e) {
      return Left(NetworkFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<Milestone>>> getMilestones() async {
    try {
      final models = await _datasource.fetchMilestones();
      return Right(models);
    } on AuthException {
      return const Left(AuthFailure());
    } on PostgrestException catch (e) {
      return Left(DatabaseFailure(e.message));
    } catch (e) {
      return Left(NetworkFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, Milestone>> getMilestoneById(String id) async {
    try {
      final model = await _datasource.fetchMilestoneById(id);
      return Right(model);
    } on AuthException {
      return const Left(AuthFailure());
    } on PostgrestException catch (e) {
      return Left(DatabaseFailure(e.message));
    } catch (e) {
      return Left(NetworkFailure(e.toString()));
    }
  }
}
```

- [ ] **Step 4: Ejecutar para verificar que pasan todos los tests**

```bash
flutter test test/data/repositories/milestone_repository_impl_test.dart
```

Expected: `All tests passed! (10 tests)`

- [ ] **Step 5: Ejecutar la suite completa**

```bash
flutter test
```

Expected: `All tests passed!`

- [ ] **Step 6: Commit**

```bash
git add lib/data/repositories/milestone_repository_impl.dart test/data/repositories/milestone_repository_impl_test.dart
git commit -m "feat: add MilestoneRepositoryImpl with error mapping to domain Failures"
```

---

## Task 10: Migración SQL — columna participants

**Files:**
- Create: `supabase/migrations/20260426000000_add_participants_to_milestones.sql`

- [ ] **Step 1: Crear el archivo de migración**

```sql
-- supabase/migrations/20260426000000_add_participants_to_milestones.sql
ALTER TABLE milestones
  ADD COLUMN IF NOT EXISTS participants TEXT[] DEFAULT '{}';
```

- [ ] **Step 2: Aplicar la migración (requiere Supabase CLI vinculado)**

```bash
supabase db push
```

Expected: `Applying migration 20260426000000_add_participants_to_milestones.sql... done`

- [ ] **Step 3: Commit**

```bash
git add supabase/migrations/20260426000000_add_participants_to_milestones.sql
git commit -m "feat(db): add participants TEXT[] column to milestones table"
```

---

## Auto-revisión del plan

**Spec coverage:**
- Sección 2 (Entidades): Tasks 3 y 4 ✅
- Sección 3 (Interfaz): Task 5 ✅
- Sección 4 (Datasource): Task 8 ✅
- Sección 5 (Flujo createMilestone): Task 9 ✅
- Sección 6 (Errores): Task 9 ✅
- Sección 7 (Dependencias): Task 1 ✅
- Nota de schema participants: Task 10 ✅

**Placeholder scan:** Sin TBD ni "implement later". Cada step tiene código completo.

**Type consistency:** `BiographerResult` definido en Task 8 y usado en Task 9. `MilestoneModel.toInsertMap` definido en Task 7 y usado en Task 9. `MediaAssetModel.fromJson` definido en Task 6 y usado en Task 7. Consistente.
