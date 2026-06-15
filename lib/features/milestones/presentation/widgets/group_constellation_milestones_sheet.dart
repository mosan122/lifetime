import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../data/models/local/milestone_collection.dart';
import '../pages/milestone_detail_page.dart';

Future<void> showGroupConstellationMilestonesSheet(
  BuildContext context, {
  required String groupName,
  required List<MilestoneCollection> milestones,
}) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: AppTheme.cream,
    isScrollControlled: true,
    showDragHandle: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (sheetContext) {
      final theme = Theme.of(sheetContext);
      final bottom = MediaQuery.paddingOf(sheetContext).bottom;
      final maxH = MediaQuery.sizeOf(sheetContext).height * 0.75;

      return ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxH),
        child: Padding(
          padding: EdgeInsets.fromLTRB(20, 4, 20, 12 + bottom),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Hitos · $groupName',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppTheme.navy,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                milestones.isEmpty
                    ? 'Ningún hito con participantes de este círculo.'
                    : '${milestones.length} hito${milestones.length == 1 ? '' : 's'} con integrantes del grupo',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: Colors.black54,
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: milestones.isEmpty
                    ? Center(
                        child: Text(
                          'Cuando registres hitos con personas de este grupo, aparecerán aquí.',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: Colors.black54,
                          ),
                        ),
                      )
                    : ListView.separated(
                        itemCount: milestones.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final m = milestones[index];
                          final date = m.eventDate;
                          final dateLabel =
                              '${date.day.toString().padLeft(2, '0')}/'
                              '${date.month.toString().padLeft(2, '0')}/'
                              '${date.year}';

                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(
                              m.title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Text(dateLabel),
                            trailing: const Icon(
                              Icons.chevron_right,
                              color: AppTheme.navy,
                            ),
                            onTap: () {
                              Navigator.pop(sheetContext);
                              Navigator.push(
                                context,
                                MaterialPageRoute<void>(
                                  builder: (_) => MilestoneDetailPage(
                                    milestone: m.toDomain(),
                                  ),
                                ),
                              );
                            },
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      );
    },
  );
}
