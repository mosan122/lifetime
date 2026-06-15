import '../../domain/entities/milestone.dart';

/// Construye la etiqueta de ubicación compacta para mostrar en tarjetas y
/// tarjetas de vista previa del mapa.
///
/// Ejemplo: "Parque del Retiro • Madrid, España"
String locationInlineLabel(Milestone m) {
  final name = (m.locationName ?? '').trim();
  if (name.isEmpty) return '';
  final parts = <String>[
    if ((m.locationCity ?? '').trim().isNotEmpty) m.locationCity!.trim(),
    if ((m.locationCountry ?? '').trim().isNotEmpty) m.locationCountry!.trim(),
  ];
  if (parts.isEmpty) return name;
  return '$name • ${parts.join(', ')}';
}

/// Calcula el centroide geográfico de una lista de hitos con coordenadas.
///
/// Devuelve `(lat, lng)` como record para que cada capa de mapa construya
/// su propio tipo `LatLng` (latlong2 o google_maps_flutter).
///
/// Precondición: todos los elementos tienen [Milestone.latitude] y
/// [Milestone.longitude] no nulos.
(double lat, double lng) milestonesCentroid(List<Milestone> milestones) {
  assert(milestones.isNotEmpty, 'milestonesCentroid requiere lista no vacía');
  final avgLat =
      milestones.map((m) => m.latitude!).reduce((a, b) => a + b) /
          milestones.length;
  final avgLng =
      milestones.map((m) => m.longitude!).reduce((a, b) => a + b) /
          milestones.length;
  return (avgLat, avgLng);
}
