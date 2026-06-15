import 'dart:convert';
import 'dart:io';

import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

import '../../../../core/constants/milestone_category_seeds.dart';
import '../../../../core/failures/failure.dart';
import '../../../../core/usecases/usecase.dart';
import '../../../../core/utils/bitacora_backup_json.dart';
import '../../../../domain/entities/milestone.dart';
import '../../../../domain/repositories/milestone_repository.dart';
import '../../data/datasources/isar_category_datasource.dart';
import '../../data/datasources/isar_person_datasource.dart';
import '../../data/datasources/isar_relationship_datasource.dart';
import '../../data/datasources/isar_saved_location_datasource.dart';
import '../../data/datasources/person_group_local_datasource.dart';

class ExportResult extends Equatable {
  final String json;
  final String markdown;

  const ExportResult({required this.json, required this.markdown});

  @override
  List<Object> get props => [json, markdown];
}

class ExportBitacoraUseCase implements UseCase<ExportResult, NoParams> {
  ExportBitacoraUseCase(
    this._repository,
    this._personDs,
    this._categoryDs,
    this._savedLocationDs,
    this._relationshipDs,
    this._personGroupDs,
  );

  final MilestoneRepository _repository;
  final IsarPersonDataSource _personDs;
  final IsarCategoryDataSource _categoryDs;
  final IsarSavedLocationDataSource _savedLocationDs;
  final IsarRelationshipDataSource _relationshipDs;
  final PersonGroupLocalDataSource _personGroupDs;

  static Set<String> get _defaultCategoryIdsLower =>
      {for (final s in kMilestoneCategorySeeds) s.id.toLowerCase()};

  @override
  Future<Either<Failure, ExportResult>> call(NoParams _) async {
    final milestonesResult = await _repository.getMilestones();
    return await milestonesResult.fold<Future<Either<Failure, ExportResult>>>(
      (f) async => Left(f),
      (milestones) async {
        final peopleRows = await _personDs.fetchAll();
        final groups = await _personGroupDs.fetchAllGroupsOrdered();
        final links = await _personGroupDs.fetchAllLinks();
        final allCategories = await _categoryDs.fetchAll();
        final locs = await _savedLocationDs.fetchAll();
        final rels = await _relationshipDs.fetchAll();
        final personIdToGroupIds = await _personGroupDs.buildPersonIdToGroupIds();

        final peopleMaps = <Map<String, dynamic>>[];
        for (final c in peopleRows) {
          final row = <String, dynamic>{
            'id': c.id,
            'name': c.name,
            'first_name': c.firstName,
            'last_name': c.lastName,
            'birth_date': c.birthDate?.toUtc().toIso8601String(),
            'notes': c.notes,
            'linked_user_email': c.linkedUserEmail,
            'linked_user_id': c.linkedUserId,
            'face_image_path': c.faceImagePath,
            'drive_face_file_id': c.driveFaceFileId,
          };
          final gids = personIdToGroupIds[c.id];
          if (gids != null && gids.isNotEmpty) {
            row['group_ids'] = List<String>.from(gids);
          }
          try {
            final fp = c.faceImagePath?.trim();
            if (fp != null && fp.isNotEmpty) {
              final file = File(fp);
              if (file.existsSync()) {
                final bytes = await file.readAsBytes();
                if (bytes.isNotEmpty) {
                  row['face_portrait_base64'] = base64Encode(bytes);
                }
              }
            }
          } catch (_) {
            // Sin retrato embebido si no hay soporte de fichero local (p. ej. web).
          }
          peopleMaps.add(row);
        }

        final defaultIds = _defaultCategoryIdsLower;
        final customCategoryMaps = <Map<String, dynamic>>[];
        for (final c in allCategories) {
          if (defaultIds.contains(c.id.toLowerCase())) continue;
          customCategoryMaps.add({
            'id': c.id,
            'name': c.name,
            'icon_name': c.iconName,
            'color_value': c.colorValue,
          });
        }

        final savedLocationMaps = <Map<String, dynamic>>[];
        for (final loc in locs) {
          savedLocationMaps.add({
            'ref': 'sl_${loc.isarId}',
            'client_id': loc.clientId,
            'source_isar_id': loc.isarId,
            'name': loc.name,
            'city': loc.city,
            'country': loc.country,
            'latitude': loc.latitude,
            'longitude': loc.longitude,
          });
        }

        final groupMaps = <Map<String, dynamic>>[];
        for (final g in groups) {
          groupMaps.add({
            'id': g.id,
            'name': g.name,
            'built_in': g.builtIn,
          });
        }

        final linkMaps = <Map<String, dynamic>>[];
        for (final l in links) {
          linkMaps.add({
            'person_id': l.personId,
            'group_id': l.groupId,
          });
        }

        final relationshipMaps = <Map<String, dynamic>>[];
        for (final r in rels) {
          relationshipMaps.add({
            'id': r.id,
            'person_id': r.personId,
            'related_person_id': r.relatedPersonId,
            'relationship_type': r.relationshipType,
            'start_date': r.startDate?.toUtc().toIso8601String(),
            'end_date': r.endDate?.toUtc().toIso8601String(),
            'is_current': r.isCurrent,
          });
        }

        final bundles = BitacoraExportBundles(
          people: peopleMaps,
          customCategories: customCategoryMaps,
          savedLocations: savedLocationMaps,
          groups: groupMaps,
          personGroupLinks: linkMaps,
          relationships: relationshipMaps,
        );

        return Right(
          ExportResult(
            json: BitacoraBackupJson.encode(milestones, bundles),
            markdown: toMarkdown(milestones),
          ),
        );
      },
    );
  }

  static String toMarkdown(List<Milestone> milestones) {
    final now = DateTime.now();
    final exportDateIso =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    final exportDateDisplay =
        '${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year}';
    final count = milestones.length;

    final buf = StringBuffer();

    buf.writeln('---');
    buf.writeln('app: LifeTime');
    buf.writeln('export_date: $exportDateIso');
    buf.writeln('total: $count');
    buf.writeln('---');
    buf.writeln();

    buf.writeln('# Mi Bitácora — LifeTime');
    buf.writeln(
        'Exportada el $exportDateDisplay · $count hito${count == 1 ? '' : 's'}');
    buf.writeln();

    for (final m in milestones) {
      buf.writeln('---');
      buf.writeln();

      final d = m.eventDate;
      final dateStr =
          '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

      buf.writeln('## ${m.title}');
      buf.writeln('📅 $dateStr  ');

      if (m.latitude != null && m.longitude != null) {
        final locName = m.locationName != null ? '${m.locationName} ' : '';
        buf.writeln('📍 $locName(${m.latitude}, ${m.longitude})  ');
      }

      if (m.participantIds.isNotEmpty) {
        buf.writeln('👥 ${m.participantIds.join(', ')}  ');
      }

      if (m.tags.isNotEmpty) {
        buf.writeln('🏷 ${m.tags.map((t) => '#$t').join(' ')}  ');
      }

      if (m.driveFileId != null) {
        buf.writeln(
            '📷 [Ver foto](https://drive.google.com/open?id=${m.driveFileId})  ');
      }

      buf.writeln();

      if (m.description != null && m.description!.isNotEmpty) {
        buf.writeln(m.description!);
        buf.writeln();
      }
    }

    return buf.toString();
  }
}
