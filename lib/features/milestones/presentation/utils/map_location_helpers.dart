import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

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
    final targetZoom =
        controller.camera.zoom < zoom ? zoom : controller.camera.zoom;
    controller.move(point, targetZoom);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (controller.camera.center != point) {
        controller.move(point, targetZoom);
      }
    });
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
