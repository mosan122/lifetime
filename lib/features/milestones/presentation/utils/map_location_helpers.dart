import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

/// Mueve el mapa de forma segura: si el [MapController] aún no está enlazado a
/// un `FlutterMap` renderizado (lanza "rendered at least once"), reintenta tras
/// el siguiente frame en lugar de abortar la operación.
void _moveSafely(MapController controller, LatLng point, double zoom) {
  double resolveZoom() {
    try {
      final current = controller.camera.zoom;
      return current < zoom ? zoom : current;
    } catch (_) {
      return zoom;
    }
  }

  try {
    controller.move(point, resolveZoom());
  } catch (_) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      try {
        controller.move(point, resolveZoom());
      } catch (_) {
        // El mapa sigue sin estar listo; se ignora (no es crítico).
      }
    });
  }
}

/// Centra [controller] en la posición GPS actual del dispositivo.
Future<LatLng?> centerMapOnCurrentLocation(
  BuildContext context,
  MapController controller, {
  double zoom = 16,
}) async {
  try {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Activa la ubicación del dispositivo en Ajustes.'),
          ),
        );
      }
      return null;
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Permiso de ubicación denegado.'),
          ),
        );
      }
      return null;
    }
    if (permission == LocationPermission.deniedForever) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'Ubicación bloqueada. Actívala en Ajustes de la app.',
            ),
            action: SnackBarAction(
              label: 'Ajustes',
              onPressed: Geolocator.openAppSettings,
            ),
          ),
        );
      }
      return null;
    }

    final pos = await Geolocator.getCurrentPosition(
      locationSettings: LocationSettings(
        accuracy: LocationAccuracy.medium,
        timeLimit: const Duration(seconds: 15),
      ),
    );

    final point = LatLng(pos.latitude, pos.longitude);
    _moveSafely(controller, point, zoom);
    return point;
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'No se pudo obtener tu posición: ${e is Exception ? e.toString().replaceFirst('Exception: ', '') : 'inténtalo de nuevo'}',
          ),
        ),
      );
    }
    return null;
  }
}
