/// Lanzada al intentar guardar un lugar con un nombre ya existente.
class DuplicateSavedLocationNameException implements Exception {
  DuplicateSavedLocationNameException(this.existingName);

  final String existingName;

  @override
  String toString() =>
      'Ya existe un lugar guardado con el nombre «$existingName».';
}
