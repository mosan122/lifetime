import 'package:flutter/foundation.dart';

/// Se incrementa tras cada [PeopleCubit.reload] para que pantallas como el
/// timeline vuelvan a leer personas desde Isar (p. ej. nueva foto con la misma ruta).
class PeopleFacesRevisionNotifier extends ValueNotifier<int> {
  PeopleFacesRevisionNotifier() : super(0);

  void bump() => value++;
}
