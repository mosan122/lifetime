/// Semilla de grupo de contacto (ids estables para Isar).
class ContactGroupSeed {
  const ContactGroupSeed({required this.id, required this.name});

  final String id;
  final String name;
}

/// Grupos predefinidos (familia, amigos, etc.). El usuario puede añadir más.
const List<ContactGroupSeed> kDefaultContactGroupSeeds = [
  ContactGroupSeed(id: 'grp_builtin_family', name: 'Familia'),
  ContactGroupSeed(id: 'grp_builtin_best_friends', name: 'Mejores amigos'),
  ContactGroupSeed(id: 'grp_builtin_friends', name: 'Amigos'),
  ContactGroupSeed(id: 'grp_builtin_work', name: 'Trabajo'),
  ContactGroupSeed(id: 'grp_builtin_school', name: 'Estudios'),
  ContactGroupSeed(id: 'grp_builtin_neighbors', name: 'Vecinos'),
  ContactGroupSeed(id: 'grp_builtin_other', name: 'Otros'),
];
