import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../../features/milestones/data/models/local/person_collection.dart';

/// Nombre legal (nombre + apellidos) si existe.
String personLegalNameLine(PersonCollection p) {
  final parts = [p.firstName, p.lastName]
      .where((s) => (s ?? '').trim().isNotEmpty)
      .map((s) => s!.trim());
  return parts.join(' ');
}

/// Nombre para mostrar en listas (nickname / [PersonCollection.name]).
String personDisplayName(PersonCollection p) {
  final n = p.name.trim();
  return n.isEmpty ? 'Sin nombre' : n;
}

/// Orden: usuario raíz primero, luego alfabético por nombre para mostrar.
int comparePeopleRootFirst(PersonCollection a, PersonCollection b) {
  if (a.isMe != b.isMe) return a.isMe ? -1 : 1;
  return personDisplayName(a)
      .toLowerCase()
      .compareTo(personDisplayName(b).toLowerCase());
}

bool personMatchesQuery(PersonCollection p, String query) {
  final q = query.trim().toLowerCase();
  if (q.isEmpty) return true;
  if (personDisplayName(p).toLowerCase().contains(q)) return true;
  final legal = personLegalNameLine(p).toLowerCase();
  if (legal.contains(q)) return true;
  return false;
}

/// Título de lista: nombre para mostrar + (nombre apellidos) en fuente pequeña.
class PersonListTitle extends StatelessWidget {
  const PersonListTitle({
    super.key,
    required this.person,
    this.highlightRoot = true,
    this.style,
  });

  final PersonCollection person;
  final bool highlightRoot;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final display = personDisplayName(person);
    final legal = personLegalNameLine(person);
    final showLegal =
        legal.isNotEmpty && legal.toLowerCase() != display.toLowerCase();
    final isRoot = person.isMe && highlightRoot;

    final baseStyle = style ??
        theme.textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w700,
          color: isRoot ? AppTheme.navy : null,
        );

    return Row(
      children: [
        Expanded(
          child: Text.rich(
            TextSpan(
              children: [
                TextSpan(text: display, style: baseStyle),
                if (showLegal)
                  TextSpan(
                    text: ' ($legal)',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: Colors.black54,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
              ],
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (isRoot) ...[
          const SizedBox(width: 6),
          const Icon(
            Icons.person_pin_outlined,
            size: 18,
            color: AppTheme.navy,
          ),
        ],
      ],
    );
  }
}
