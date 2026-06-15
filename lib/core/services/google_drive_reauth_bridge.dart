/// Puente para notificar a [AuthCubit] sin dependencia circular con Drive.
class GoogleDriveReauthBridge {
  void Function()? onReauthRequired;

  void requestReauth() => onReauthRequired?.call();
}
