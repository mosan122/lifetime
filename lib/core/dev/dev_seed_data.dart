import 'dart:io';
import 'dart:math';

import 'package:image/image.dart' as img;
import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../../domain/entities/media_item.dart';
import '../../domain/relationships/relationship_type_codes.dart';
import '../../features/milestones/data/models/local/group_collection.dart';
import '../../features/milestones/data/models/local/milestone_collection.dart';
import '../../features/milestones/data/models/local/media_item_embed.dart';
import '../../features/milestones/data/models/local/person_collection.dart';
import '../../features/milestones/data/models/local/person_group_link_collection.dart';
import '../../features/milestones/data/models/local/relationship_collection.dart';
import '../../features/milestones/data/models/local/saved_location_collection.dart';
import '../../injection_container.dart';
import '../constants/default_contact_groups.dart';
import '../constants/milestone_category_seeds.dart';

/// Resumen del proceso de siembra de datos.
class DevSeedSummary {
  const DevSeedSummary({
    required this.people,
    required this.relationships,
    required this.locations,
    required this.milestones,
    required this.photos,
  });

  final int people;
  final int relationships;
  final int locations;
  final int milestones;
  final int photos;

  @override
  String toString() =>
      '$people personas · $relationships vínculos · $locations lugares · '
      '$milestones hitos · $photos fotos';
}

/// Genera un conjunto de datos de demostración 100% local para ver la app
/// poblada (200 hitos con ~5 fotos cada uno, 150 lugares, 1000 personas con
/// relaciones). Solo para desarrollo (ver `AppFlags.kEnableDevSeed`).
class DevSeedData {
  DevSeedData._();

  static const _uuid = Uuid();
  static const int _peopleCount = 1000;
  static const int _locationCount = 150;
  static const int _milestoneCount = 200;
  static const int _photoPoolSize = 40;
  static const int _avatarPoolSize = 24;

  /// Borra los datos de demostración (mantiene la persona raíz "yo").
  static Future<void> wipeAll() async {
    if (!sl.isRegistered<Isar>()) {
      throw StateError('Isar no está disponible en esta plataforma.');
    }
    final isar = sl<Isar>();
    await isar.writeTxn(() async {
      await isar.milestoneCollections.clear();
      await isar.relationshipCollections.clear();
      await isar.savedLocationCollections.clear();
      await isar.personGroupLinkCollections.clear();
      final removable = await isar.personCollections
          .filter()
          .isMeEqualTo(false)
          .findAll();
      await isar.personCollections
          .deleteAll(removable.map((p) => p.isarId).toList());
    });
  }

  static Future<DevSeedSummary> run({
    void Function(String message)? onProgress,
  }) async {
    if (!sl.isRegistered<Isar>()) {
      throw StateError('Isar no está disponible en esta plataforma.');
    }
    final isar = sl<Isar>();
    final rng = Random(20260614);

    onProgress?.call('Generando imágenes de muestra…');
    final mediaDir = await _seedMediaDir();
    final photoPaths = await _generatePhotoPool(mediaDir, _photoPoolSize);
    final avatarPaths = await _generateAvatarPool(mediaDir, _avatarPoolSize);

    // ── Lugares ───────────────────────────────────────────────────────────
    onProgress?.call('Creando $_locationCount lugares…');
    final locations = _buildLocations(rng);
    await isar.writeTxn(() => isar.savedLocationCollections.putAll(locations));

    // ── Personas ──────────────────────────────────────────────────────────
    onProgress?.call('Creando $_peopleCount personas…');
    final people = _buildPeople(rng, avatarPaths);
    await isar.writeTxn(() => isar.personCollections.putAll(people));

    // Persona raíz como participante frecuente (si existe).
    final root =
        await isar.personCollections.filter().isMeEqualTo(true).findFirst();
    final rootId = root?.id;

    // ── Relaciones (familias) ───────────────────────────────────────────────
    onProgress?.call('Creando vínculos familiares…');
    final relationships = _buildFamilies(people);
    await isar.writeTxn(
      () => isar.relationshipCollections.putAll(relationships),
    );

    // ── Grupos de contacto ─────────────────────────────────────────────────
    onProgress?.call('Asignando grupos a personas…');
    await _seedGroupMemberships(isar, rng, people, rootId: rootId);

    // ── Hitos ────────────────────────────────────────────────────────────
    onProgress?.call('Creando $_milestoneCount hitos con fotos…');
    final peopleIds = people.map((p) => p.id).toList();
    final milestones = _buildMilestones(
      rng: rng,
      locations: locations,
      peopleIds: peopleIds,
      rootId: rootId,
      photoPaths: photoPaths,
    );
    var photoCount = 0;
    for (final m in milestones) {
      photoCount += m.mediaItems.length;
    }
    await isar.writeTxn(() => isar.milestoneCollections.putAll(milestones));

    onProgress?.call('Listo.');
    return DevSeedSummary(
      people: people.length,
      relationships: relationships.length,
      locations: locations.length,
      milestones: milestones.length,
      photos: photoCount,
    );
  }

  // ── Imágenes ──────────────────────────────────────────────────────────────

  static Future<Directory> _seedMediaDir() async {
    final appDir = await getApplicationDocumentsDirectory();
    final dir = Directory('${appDir.path}/seed_media');
    if (!dir.existsSync()) await dir.create(recursive: true);
    return dir;
  }

  static Future<List<String>> _generatePhotoPool(
    Directory dir,
    int count,
  ) async {
    final paths = <String>[];
    final rng = Random(7);
    for (var i = 0; i < count; i++) {
      final path = '${dir.path}/photo_$i.jpg';
      final file = File(path);
      if (!file.existsSync()) {
        final c1 = _palette[i % _palette.length];
        final c2 = _palette[(i * 3 + 5) % _palette.length];
        final image = _gradient(480, 320, c1, c2, rng);
        await file.writeAsBytes(img.encodeJpg(image, quality: 80));
        await Future<void>.delayed(Duration.zero); // ceder el hilo de UI
      }
      paths.add(path);
    }
    return paths;
  }

  static Future<List<String>> _generateAvatarPool(
    Directory dir,
    int count,
  ) async {
    final paths = <String>[];
    final rng = Random(11);
    for (var i = 0; i < count; i++) {
      final path = '${dir.path}/avatar_$i.jpg';
      final file = File(path);
      if (!file.existsSync()) {
        final c1 = _palette[(i * 2) % _palette.length];
        final c2 = _palette[(i * 2 + 1) % _palette.length];
        final image = _gradient(256, 256, c1, c2, rng);
        await file.writeAsBytes(img.encodeJpg(image, quality: 80));
        await Future<void>.delayed(Duration.zero); // ceder el hilo de UI
      }
      paths.add(path);
    }
    return paths;
  }

  static img.Image _gradient(
    int w,
    int h,
    List<int> c1,
    List<int> c2,
    Random rng,
  ) {
    final image = img.Image(width: w, height: h);
    final diagonal = rng.nextBool();
    for (var y = 0; y < h; y++) {
      for (var x = 0; x < w; x++) {
        final t = diagonal ? (x + y) / (w + h - 2) : y / (h - 1);
        final r = (c1[0] + (c2[0] - c1[0]) * t).round().clamp(0, 255);
        final g = (c1[1] + (c2[1] - c1[1]) * t).round().clamp(0, 255);
        final b = (c1[2] + (c2[2] - c1[2]) * t).round().clamp(0, 255);
        image.setPixelRgb(x, y, r, g, b);
      }
    }
    return image;
  }

  static const List<List<int>> _palette = [
    [38, 70, 83], [42, 157, 143], [233, 196, 106], [244, 162, 97],
    [231, 111, 81], [69, 123, 157], [168, 218, 220], [29, 53, 87],
    [106, 153, 78], [188, 108, 37], [123, 44, 191], [60, 110, 113],
    [224, 122, 95], [129, 178, 154], [242, 204, 143], [61, 64, 91],
  ];

  // ── Lugares ────────────────────────────────────────────────────────────────

  static List<SavedLocationCollection> _buildLocations(Random rng) {
    final out = <SavedLocationCollection>[];
    final usedNames = <String>{};
    for (var i = 0; i < _locationCount; i++) {
      final city = _cities[i % _cities.length];
      final suffix = _placeSuffixes[i % _placeSuffixes.length];
      final jitter = (i ~/ _cities.length) + 1;
      final lat = city.lat + (rng.nextDouble() - 0.5) * 0.08 * jitter;
      final lon = city.lon + (rng.nextDouble() - 0.5) * 0.08 * jitter;
      final streetNo = 1 + (i % 240);
      final name = '$suffix · ${city.name} $streetNo';
      assert(usedNames.add(name));
      final address =
          'Calle Demo $streetNo, ${city.name}, ${city.country}';
      out.add(
        SavedLocationCollection()
          ..clientId = _uuid.v4()
          ..name = name
          ..address = address
          ..city = city.name
          ..country = city.country
          ..latitude = double.parse(lat.toStringAsFixed(5))
          ..longitude = double.parse(lon.toStringAsFixed(5)),
      );
    }
    return out;
  }

  static Future<List<PersonGroupLinkCollection>> _seedGroupMemberships(
    Isar isar,
    Random rng,
    List<PersonCollection> people, {
    String? rootId,
  }) async {
    await isar.writeTxn(() async {
      final existing = await isar.groupCollections.where().findAll();
      final haveIds = existing.map((g) => g.id.toLowerCase()).toSet();
      for (final s in kDefaultContactGroupSeeds) {
        if (haveIds.contains(s.id.toLowerCase())) continue;
        await isar.groupCollections.put(
          GroupCollection()
            ..id = s.id
            ..name = s.name
            ..builtIn = true,
        );
        haveIds.add(s.id.toLowerCase());
      }
    });

    final groups = await isar.groupCollections.where().findAll();
    if (groups.isEmpty) return const [];

    final links = <PersonGroupLinkCollection>[];
    final linkKeys = <String>{};

    for (final p in people) {
      final count = 1 + rng.nextInt(3); // 1–3 grupos
      final picked = <String>{};
      while (picked.length < count) {
        picked.add(groups[rng.nextInt(groups.length)].id);
      }
      for (final gid in picked) {
        final key = '${p.id}|$gid';
        if (!linkKeys.add(key)) continue;
        links.add(
          PersonGroupLinkCollection()
            ..linkKey = key
            ..personId = p.id
            ..groupId = gid,
        );
      }
    }

    if (rootId != null && rootId.trim().isNotEmpty) {
      final familyId = kDefaultContactGroupSeeds.first.id;
      final key = '${rootId.trim()}|$familyId';
      if (linkKeys.add(key)) {
        links.add(
          PersonGroupLinkCollection()
            ..linkKey = key
            ..personId = rootId.trim()
            ..groupId = familyId,
        );
      }
    }

    await isar.writeTxn(
      () => isar.personGroupLinkCollections.putAll(links),
    );
    return links;
  }

  // ── Personas ─────────────────────────────────────────────────────────────

  static List<PersonCollection> _buildPeople(
    Random rng,
    List<String> avatarPaths,
  ) {
    final out = <PersonCollection>[];
    final now = DateTime.now();
    for (var i = 0; i < _peopleCount; i++) {
      final first = _firstNames[rng.nextInt(_firstNames.length)];
      final last1 = _lastNames[rng.nextInt(_lastNames.length)];
      final last2 = _lastNames[rng.nextInt(_lastNames.length)];
      final hasPhoto = rng.nextInt(10) < 7; // ~70%
      final age = 1 + rng.nextInt(90);
      out.add(
        PersonCollection()
          ..id = _uuid.v4()
          ..name = first
          ..firstName = first
          ..lastName = '$last1 $last2'
          ..birthDate = DateTime(now.year - age, 1 + rng.nextInt(12),
              1 + rng.nextInt(28))
          ..notes = ''
          ..faceImagePath =
              hasPhoto ? avatarPaths[rng.nextInt(avatarPaths.length)] : null
          ..isSynced = false
          ..isMe = false,
      );
    }
    return out;
  }

  // ── Relaciones (familias de 5: 2 progenitores + 3 hijos) ────────────────────

  static List<RelationshipCollection> _buildFamilies(
    List<PersonCollection> people,
  ) {
    final rels = <RelationshipCollection>[];

    RelationshipCollection row(String a, String b, String type) {
      return RelationshipCollection()
        ..id = _uuid.v4()
        ..personId = a
        ..relatedPersonId = b
        ..relationshipType = type
        ..isCurrent = true
        ..isSynced = false;
    }

    for (var i = 0; i + 4 < people.length; i += 5) {
      final p0 = people[i].id; // progenitor A
      final p1 = people[i + 1].id; // progenitor B
      final kids = [people[i + 2].id, people[i + 3].id, people[i + 4].id];

      // Pareja (simétrico).
      rels.add(row(p0, p1, RelationshipTypeCodes.esParejaDe));
      rels.add(row(p1, p0, RelationshipTypeCodes.esParejaDe));

      for (final c in kids) {
        // hijo de + espejo padre/madre de.
        rels.add(row(c, p0, RelationshipTypeCodes.esHijoDe));
        rels.add(row(p0, c, RelationshipTypeCodes.esPadreDe));
        rels.add(row(c, p1, RelationshipTypeCodes.esHijoDe));
        rels.add(row(p1, c, RelationshipTypeCodes.esMadreDe));
      }

      // Hermanos entre los hijos (simétrico).
      for (var a = 0; a < kids.length; a++) {
        for (var b = a + 1; b < kids.length; b++) {
          rels.add(row(kids[a], kids[b], RelationshipTypeCodes.esHermanoDe));
          rels.add(row(kids[b], kids[a], RelationshipTypeCodes.esHermanoDe));
        }
      }
    }
    return rels;
  }

  // ── Hitos ────────────────────────────────────────────────────────────────

  static List<MilestoneCollection> _buildMilestones({
    required Random rng,
    required List<SavedLocationCollection> locations,
    required List<String> peopleIds,
    required String? rootId,
    required List<String> photoPaths,
  }) {
    final out = <MilestoneCollection>[];
    final now = DateTime.now();
    final categoryIds =
        kMilestoneCategorySeeds.map((c) => c.id).toList(growable: false);

    for (var i = 0; i < _milestoneCount; i++) {
      final loc = locations[rng.nextInt(locations.length)];

      // Fecha entre hace ~30 años y hoy.
      final daysBack = rng.nextInt(365 * 30);
      final eventDate = now.subtract(Duration(days: daysBack));

      // Participantes: 1-6 personas + (a veces) la persona raíz.
      final participantCount = 1 + rng.nextInt(6);
      final participants = <String>{};
      if (rootId != null && rng.nextBool()) participants.add(rootId);
      while (participants.length < participantCount) {
        participants.add(peopleIds[rng.nextInt(peopleIds.length)]);
      }
      final participantList = participants.toList();
      final protagonists = participantList
          .take(1 + rng.nextInt(participantList.length))
          .where((_) => rng.nextInt(3) == 0)
          .toList();

      // Fotos: 3-7 (media ~5).
      final photoCount = 3 + rng.nextInt(5);
      final mediaItems = <MediaItemEmbed>[];
      for (var j = 0; j < photoCount; j++) {
        final path = photoPaths[rng.nextInt(photoPaths.length)];
        mediaItems.add(
          MediaItemEmbed()
            ..localPath = path
            ..thumbnailPath = path
            ..mediaType = MediaType.image
            ..isSynced = false
            ..isDeleted = false,
        );
      }

      final title = '${_titlePrefixes[rng.nextInt(_titlePrefixes.length)]} '
          '${_titleSubjects[rng.nextInt(_titleSubjects.length)]}';
      final desc = _descriptions[rng.nextInt(_descriptions.length)];
      final tagCount = rng.nextInt(4);
      final tags = <String>{};
      while (tags.length < tagCount) {
        tags.add(_tags[rng.nextInt(_tags.length)]);
      }

      out.add(
        MilestoneCollection()
          ..id = _uuid.v4()
          ..userId = rootId ?? 'local-user'
          ..title = title
          ..description = desc
          ..participants = participantList
          ..protagonists = protagonists
          ..tags = tags.toList()
          ..eventDate = eventDate
          ..createdAt = eventDate
          ..savedLocationId = loc.isarId
          ..location = (MilestoneLocationDataEmbed()
            ..name = loc.name
            ..city = loc.city
            ..country = loc.country
            ..latitude = loc.latitude
            ..longitude = loc.longitude)
          ..locationName = loc.name
          ..latitude = loc.latitude
          ..longitude = loc.longitude
          ..categoryId = categoryIds[rng.nextInt(categoryIds.length)]
          ..isPublic = false
          ..syncStatus = SyncStatus.pending
          ..isSynced = false
          ..isDeleted = false
          ..media = []
          ..mediaItems = mediaItems
          ..galleryCoverIndex = 0,
      );
    }
    return out;
  }

  // ── Pools de texto ─────────────────────────────────────────────────────────

  static const _firstNames = [
    'Lucía', 'Hugo', 'Martina', 'Mateo', 'Sofía', 'Daniel', 'María', 'Pablo',
    'Paula', 'Álvaro', 'Julia', 'Adrián', 'Carla', 'Diego', 'Valeria', 'Marcos',
    'Noa', 'Leo', 'Emma', 'Bruno', 'Sara', 'Gael', 'Vega', 'Izan', 'Claudia',
    'Marco', 'Alba', 'Iker', 'Daniela', 'Nicolás', 'Olivia', 'Sergio', 'Ana',
    'David', 'Inés', 'Javier', 'Lola', 'Manuel', 'Jimena', 'Antonio',
  ];

  static const _lastNames = [
    'García', 'Rodríguez', 'González', 'Fernández', 'López', 'Martínez',
    'Sánchez', 'Pérez', 'Gómez', 'Martín', 'Jiménez', 'Ruiz', 'Hernández',
    'Díaz', 'Moreno', 'Muñoz', 'Álvarez', 'Romero', 'Alonso', 'Gutiérrez',
    'Navarro', 'Torres', 'Domínguez', 'Vázquez', 'Ramos', 'Gil', 'Ramírez',
    'Serrano', 'Blanco', 'Molina', 'Morales', 'Suárez', 'Ortega', 'Castro',
  ];

  static const _titlePrefixes = [
    'Verano en', 'Viaje a', 'Cena con', 'Tarde de', 'Mañana en', 'Aniversario en',
    'Cumpleaños en', 'Reencuentro en', 'Excursión a', 'Boda en', 'Concierto en',
    'Graduación en', 'Mudanza a', 'Paseo por', 'Comida en', 'Fiesta en',
  ];

  static const _titleSubjects = [
    'la playa', 'la montaña', 'casa', 'el pueblo', 'la ciudad', 'el campo',
    'el parque', 'la sierra', 'el lago', 'la costa', 'el centro', 'el jardín',
    'la abuela', 'los amigos', 'la familia', 'el río',
  ];

  static const _descriptions = [
    'Un día inolvidable rodeado de las personas que más quiero. La luz era '
        'perfecta y todo salió mejor de lo esperado.',
    'No teníamos plan, pero acabó siendo uno de esos momentos que se quedan '
        'para siempre. Reímos hasta que dolió.',
    'Pequeño gran instante. Lo recordaré por los detalles: la música, el olor '
        'del café y la conversación que no acababa.',
    'Llevábamos tiempo esperando este momento. Por fin sucedió y mereció mucho '
        'la pena cada minuto.',
    'Un encuentro sencillo que se convirtió en celebración. Brindamos por lo '
        'vivido y por lo que viene.',
    'Día de descubrimientos y caminos nuevos. Volví a casa cansado pero con la '
        'sensación de haber ganado un recuerdo.',
  ];

  static const _tags = [
    'verano', 'familia', 'amigos', 'viaje', 'celebración', 'naturaleza',
    'ciudad', 'playa', 'montaña', 'recuerdo', 'aniversario', 'fiesta',
  ];

  static const List<_City> _cities = [
    _City('Madrid', 'España', 40.4168, -3.7038),
    _City('Barcelona', 'España', 41.3851, 2.1734),
    _City('Valencia', 'España', 39.4699, -0.3763),
    _City('Sevilla', 'España', 37.3891, -5.9845),
    _City('Bilbao', 'España', 43.2630, -2.9350),
    _City('Málaga', 'España', 36.7213, -4.4214),
    _City('Lisboa', 'Portugal', 38.7223, -9.1393),
    _City('Oporto', 'Portugal', 41.1579, -8.6291),
    _City('París', 'Francia', 48.8566, 2.3522),
    _City('Lyon', 'Francia', 45.7640, 4.8357),
    _City('Roma', 'Italia', 41.9028, 12.4964),
    _City('Milán', 'Italia', 45.4642, 9.1900),
    _City('Florencia', 'Italia', 43.7696, 11.2558),
    _City('Londres', 'Reino Unido', 51.5074, -0.1278),
    _City('Edimburgo', 'Reino Unido', 55.9533, -3.1883),
    _City('Berlín', 'Alemania', 52.5200, 13.4050),
    _City('Múnich', 'Alemania', 48.1351, 11.5820),
    _City('Ámsterdam', 'Países Bajos', 52.3676, 4.9041),
    _City('Bruselas', 'Bélgica', 50.8503, 4.3517),
    _City('Viena', 'Austria', 48.2082, 16.3738),
    _City('Praga', 'Chequia', 50.0755, 14.4378),
    _City('Atenas', 'Grecia', 37.9838, 23.7275),
    _City('Nueva York', 'EE. UU.', 40.7128, -74.0060),
    _City('San Francisco', 'EE. UU.', 37.7749, -122.4194),
    _City('Ciudad de México', 'México', 19.4326, -99.1332),
    _City('Buenos Aires', 'Argentina', -34.6037, -58.3816),
    _City('Bogotá', 'Colombia', 4.7110, -74.0721),
    _City('Lima', 'Perú', -12.0464, -77.0428),
    _City('Tokio', 'Japón', 35.6762, 139.6503),
    _City('Marrakech', 'Marruecos', 31.6295, -7.9811),
  ];

  static const _placeSuffixes = [
    'Plaza', 'Parque', 'Café', 'Mirador', 'Paseo', 'Playa', 'Mercado',
    'Restaurante', 'Casa', 'Hotel', 'Jardín', 'Puente', 'Faro', 'Estación',
    'Museo',
  ];
}

class _City {
  const _City(this.name, this.country, this.lat, this.lon);
  final String name;
  final String country;
  final double lat;
  final double lon;
}
