import 'package:supabase_flutter/supabase_flutter.dart';

import '../../features/milestones/data/models/local/person_collection.dart';

/// Quita la ficha Isar vinculada a la cuenta actual (`linkedUserId`).
/// Nombre, foto y cumple del titular se gestionan en **Mi perfil**, no en Personas.
List<PersonCollection> withoutLinkedCurrentUser(
  List<PersonCollection> people,
) {
  final id = (Supabase.instance.client.auth.currentUser?.id ?? '').trim();
  if (id.isEmpty) return List<PersonCollection>.from(people);
  return people
      .where((p) => (p.linkedUserId ?? '').trim() != id)
      .toList();
}
