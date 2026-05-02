import 'dart:convert';

import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

import '../../../../core/failures/failure.dart';
import '../../../../core/usecases/usecase.dart';
import '../../../../domain/entities/milestone.dart';
import '../../../../domain/repositories/milestone_repository.dart';

class ExportResult extends Equatable {
  final String json;
  final String markdown;

  const ExportResult({required this.json, required this.markdown});

  @override
  List<Object> get props => [json, markdown];
}

class ExportBitacoraUseCase implements UseCase<ExportResult, NoParams> {
  final MilestoneRepository repository;

  const ExportBitacoraUseCase(this.repository);

  @override
  Future<Either<Failure, ExportResult>> call(NoParams _) async {
    return (await repository.getMilestones()).map(
      (milestones) => ExportResult(
        json: toJson(milestones),
        markdown: toMarkdown(milestones),
      ),
    );
  }

  static String toJson(List<Milestone> milestones) {
    final now = DateTime.now().toUtc();
    final data = {
      'exported_at': now.toIso8601String(),
      'version': '1.0',
      'total': milestones.length,
      'milestones': milestones.map((m) {
        final d = m.eventDate;
        return {
          'id': m.id,
          'title': m.title,
          'description': m.description,
          'event_date':
              '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}',
          'category_id': m.categoryId,
          'location': (m.latitude != null && m.longitude != null)
              ? {
                  'name': m.locationName,
                  'latitude': m.latitude,
                  'longitude': m.longitude,
                }
              : null,
          'participants': m.participants,
          'drive_file_id': m.driveFileId,
          'created_at': m.createdAt.toUtc().toIso8601String(),
        };
      }).toList(),
    };
    return const JsonEncoder.withIndent('  ').convert(data);
  }

  static String toMarkdown(List<Milestone> milestones) {
    final now = DateTime.now();
    final exportDateIso =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    final exportDateDisplay =
        '${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year}';
    final count = milestones.length;

    final buf = StringBuffer();

    // YAML frontmatter (Obsidian-compatible)
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

      if (m.participants.isNotEmpty) {
        buf.writeln('👥 ${m.participants.join(', ')}  ');
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
