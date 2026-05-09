import 'package:isar/isar.dart';

part 'local_user_session_collection.g.dart';

/// Fila singleton (id fija) con el último usuario autenticado verificado.
@Collection()
class LocalUserSessionCollection {
  /// Siempre 1: una sola fila de sesión local.
  Id id = 1;

  late String userId;
  late String email;
  bool isPremiumCached = false;
  bool emailVerified = false;
}
