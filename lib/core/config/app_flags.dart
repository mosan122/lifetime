/// Banderas globales de configuración de la app.
///
/// Permiten activar/desactivar grandes bloques de funcionalidad sin borrar
/// el código existente. Útil para compilar un MVP 100% local ("Local-First").
class AppFlags {
  const AppFlags._();

  /// Cuando es `false`, se desactiva toda la infraestructura de nube
  /// (Supabase + Google Drive): sincronización, indicadores de estado de
  /// sincronización y enrutamiento por sesión de Supabase.
  ///
  /// El arranque pasa a ser local: se consulta Isar para decidir entre el
  /// onboarding local y la pantalla principal.
  static const bool kIsCloudEnabled = false;

  /// Muestra herramientas de desarrollo (p. ej. generar datos de demostración
  /// en Ajustes). Debe quedar en `false` para builds de producción.
  static const bool kEnableDevSeed = true;
}
