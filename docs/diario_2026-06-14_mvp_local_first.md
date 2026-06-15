# Diario de implementación — MVP 100% local ("Local-First")

- **Fecha:** 14 de junio de 2026
- **Objetivo:** Compilar un MVP local desactivando temporalmente Supabase y Google Drive **sin borrar** el código existente, mediante una bandera global.
- **Estado:** Completado (4 pasos).

---

## Paso 1 — Feature Flag global

### `lib/core/config/app_flags.dart` (nuevo)
Constante única que gobierna toda la infraestructura de nube:

```dart
class AppFlags {
  const AppFlags._();
  static const bool kIsCloudEnabled = false;
}
```

### Guardas de sincronización
Se añadió `if (!AppFlags.kIsCloudEnabled) return;` al inicio de los métodos
principales de sincronización (el código de nube se conserva intacto, solo se
cortocircuita en frío):

- **`lib/features/sync/data/services/sync_service.dart`**
  - `syncIfNeededForTimelineOpen()` → `return;`
  - `syncData()` y `syncMetadata()` → devuelven `SyncRunResult(skipped: true, ...)`
    con motivo "La sincronización en la nube está desactivada."
- **`lib/core/services/cloud_sync_service.dart`**
  - `syncMediaDeferred()`, `syncMediaNow()`, `purgeDeletedFromDrive()`,
    `syncIfNeeded()`, `restoreMilestoneMediaFromDrive()`, `restoreMissingFaces()`,
    `deleteDriveFace()` → `return;` (o resultado vacío) cuando la nube está apagada.
- **`lib/features/sync/schedule_cloud_sync.dart`**
  - `onPremiumSessionStarted()` y `scheduleCloudDataSync()` → `return;`

### Indicadores ocultos con la misma bandera
- **`lib/features/milestones/presentation/widgets/timeline_sync_status_indicator.dart`**
  - `TimelineSyncStatusIndicator.build` y `TimelineSyncMediaProgressBar.build`
    devuelven `const SizedBox.shrink()` si `!kIsCloudEnabled` (desaparecen del AppBar).
- **`lib/features/premium/presentation/pages/premium_dashboard_view.dart`**
  - El botón "Sincronizar ahora" queda envuelto en `if (AppFlags.kIsCloudEnabled) ...[ ... ]`.

---

## Paso 2 — Modelo Isar (nodo raíz)

### `lib/features/milestones/data/models/local/person_collection.dart`
- Nuevo campo: `bool isMe = false;` (nodo "yo", dueño del dispositivo; solo debe
  haber una persona con `isMe == true`).
- Propagado en `copyScalars()` para no perder el flag al copiar.
- Se regeneraron los artefactos de Isar con `build_runner` (`person_collection.g.dart`).

### `lib/features/milestones/data/datasources/isar_person_datasource.dart`
- Nuevo método en la interfaz e implementación:

```dart
@override
Future<PersonCollection?> getRootUser() async {
  final all = await fetchAll();
  return all.where((p) => p.isMe).firstOrNull;
}
```

- En `upsert()` se preserva el flag raíz: `c.isMe = c.isMe || existing.isMe;`
  (evita perder "yo" al actualizar la persona existente).

---

## Paso 3 — Pantalla de Onboarding local

### `lib/features/profile/presentation/pages/local_onboarding_view.dart` (nueva)
Vista limpia que sustituye al login clásico en modo local:

- Texto de privacidad: *"Tus datos se quedan en tu dispositivo…"*.
- Campo **Nombre** (obligatorio, con `validator`).
- Selector de **Fecha de nacimiento** (`showDatePicker`, locale `es_ES`).
- Botón **"Comenzar"**: crea la persona en Isar con `id` (Uuid v4),
  `isMe = true`, `isSynced = false` y redirige a `TimelinePage` con
  `pushReplacement`. Estado de guardado (`_saving`) con spinner y manejo de error.
- Estética minimalista (crema/azul marino, `AppTheme`).

---

## Paso 4 — Refactorización del arranque/enrutamiento

### `lib/main.dart`
- En modo local **no se escucha** al `AuthCubit` de Supabase:

```dart
if (AppFlags.kIsCloudEnabled) {
  c.listenToSupabaseAuth();
  c.checkCurrentUser();
}
...
home: AppFlags.kIsCloudEnabled ? const AuthGate() : const LocalBootGate(),
```

### `lib/features/profile/presentation/pages/local_boot_gate.dart` (nueva)
- `FutureBuilder` sobre `IsarPersonDataSource.getRootUser()`:
  - mientras carga → spinner;
  - si `null` → `LocalOnboardingView`;
  - si existe → `TimelinePage`.

### `lib/features/milestones/presentation/bloc/relationship_tree_cubit.dart`
- Nuevo `centerOnRootUser()`: centra el árbol en el usuario raíz (`getRootUser()`),
  con _fallback_ a la primera persona si aún no existe. Usado por el árbol de
  relaciones para tomar el ID del nodo "yo" como centro por defecto.

---

## Notas y pendientes

- Toda la lógica de nube (Supabase + Drive) **se conserva**; reactivar es tan
  simple como poner `kIsCloudEnabled = true`.
- Pendiente opcional: cuando se reactive la nube, decidir cómo enlazar el nodo
  raíz local (`isMe`) con la cuenta de Supabase (`linkedUserId`).
- Verificar tras `build_runner` que no quedan `.g.part` huérfanos en `.dart_tool`.

---

# Sesión 2 (14 jun 2026, tarde) — Ajustes de UX: hito, personas, relaciones y lugares

Conjunto de cambios para refinar el modo local: ficha del hito, onboarding,
relaciones/parentescos, desbloqueo de funciones premium y gestión de lugares.

## 1. Detalle de hito (`milestones/presentation/pages/milestone_detail_page.dart`)
- La **ubicación** se muestra ahora **antes del título**, justo bajo la fila de
  categoría/fecha (`_buildBody`: el bloque `_MilestoneLocationRow` se movió
  delante del `Text(title)`).
- El **botón de editar** (icono lápiz en el `SliverAppBar`) ya existía y se
  mantiene; abre `AddMilestonePage(initial: _milestone)`.

## 2. Onboarding local (`profile/presentation/pages/local_onboarding_view.dart`)
- Reescrito para capturar **Nombre** (obligatorio), **Apellidos**, **Fecha de
  nacimiento** y **Foto** (cámara/galería + recorte vía `FaceCropperService` y
  `showFaceSourceBottomSheet`).
- Al pulsar **Comenzar** persiste en la ficha del nodo raíz: `name` (nombre +
  apellidos), `firstName`, `lastName`, `birthDate`, `isMe = true`,
  `isSynced = false`; si hay foto, `saveForPerson(personId, file)` rellena
  `faceImagePath`. Import añadido: `core/failures/failure.dart` (para
  `FaceCropCancelledFailure`).

## 3. Relaciones: tipos nuevos + inversa automática
- **`domain/relationships/relationship_type_codes.dart`**: añadidos
  `esTioDe`, `esTiaDe`, `esSobrinoDe`, `esSobrinaDe` (en `pickerOrdered`,
  `labelEs` e `inverseLabelForViewer`).
- **`relationship_reciprocity.dart`**: tío/tía → `singleMirror` a `esSobrinoDe`;
  sobrino/sobrina → `chooseMirrorType` `[esTioDe, esTiaDe]`.
- **`relationship_tree_kinship.dart`**: tíos/sobrinos devuelven `skip` (no
  encajan en el layout radial de 4 cuadrantes; sí aparecen en la lista).
- **`settings/presentation/widgets/edit_person_relations_tab.dart`**:
  `_saveBond` ahora crea **siempre la fila inversa sin diálogos** (para
  `chooseMirrorType` toma `mirrorTypeChoices.first`). Las filas espejo se
  deduplican en la lista (`PersonRelationshipsBlock`) y el árbol lee ambas
  direcciones de una sola fila.

## 4. Quitar texto de verificación de cuenta (`settings/presentation/pages/edit_person_page.dart`)
- Eliminado el `helperText` "La verificación con cuenta LifeTime…" y todo el
  bloque premium de **vincular/verificar email**. El email queda como campo de
  contacto opcional. Eliminados estado/método sin uso (`_verifying`,
  `_verifiedUserId`, `_verifyError`, `_verifyEmail`) e import de
  `PremiumService`; `linkedUserId` solo se conserva si el email no cambia.

## 5. Desbloqueos premium
- **Árbol genealógico** (`milestones/presentation/pages/relationship_tree_view.dart`):
  quitado el `PremiumGatePlaceholder`; siempre renderiza `RelationshipTreeCanvas`.
- **Botón de árbol** en `edit_person_relations_tab.dart`: siempre visible
  (quitado `if (premium)`).
- **Mapa de relaciones** (`settings/presentation/widgets/manage_people_relations_tab.dart`):
  quitado el gate premium; el centro por defecto pasa a ser
  `getRootUser()` (con _fallback_ a la persona vinculada a Supabase).
- **Constelación de grupos** (`milestones/presentation/pages/group_constellation_view.dart`):
  quitado el gate premium; siempre renderiza el lienzo.

## 6. Lugares (`settings/presentation/pages/manage_locations_page.dart`)
- **Lista**: sin icono de ubicación y **sin coordenadas** (solo nombre · ciudad ·
  país); cada fila es pulsable y abre el detalle (`chevron_right`).
- **`SavedLocationDetailPage`** (nueva): `flutter_map` centrado en el lugar con
  marcador, panel con nombre/ciudad/país **y coordenadas**, y acciones
  **Editar** (reutiliza `_LocationEditorSheet`: renombrar + mover el punto) y
  **Borrar** (con comprobación de hitos asociados).
- **`SavedLocationsMapPage`** (nueva): vista con **todos** los lugares sobre un
  mapa; marcadores con nombre que abren el detalle. Accesible desde el icono
  `map_outlined` del `AppBar` de Lugares.

## Verificación
- `flutter analyze lib`: el único **error** introducido (import faltante en el
  onboarding) quedó corregido. El resto son **advertencias/infos preexistentes**
  ajenas a estos cambios.

## Decisión de diseño asumida
- En vínculos con inversa ambigua (p. ej. *hijo de* → padre/madre, *sobrino de*
  → tío/tía) se elige por defecto la **primera opción** (padre/abuelo/tío) para
  cumplir el requisito de "no preguntar". Alternativa posible: no almacenar fila
  espejo y dejar que el árbol/listas interpreten la única fila en ambos sentidos.

---

# Sesión 3 (14 jun 2026, tarde) — Datos de demostración (seeder)

Generador local de datos para ver la app poblada (solo desarrollo).

## Flag y archivo
- **`core/config/app_flags.dart`**: nuevo `kEnableDevSeed = true` (poner a `false`
  en producción).
- **`core/dev/dev_seed_data.dart`** (nuevo): clase `DevSeedData`.
  - `run()`: **1000 personas** (nombre, apellidos, fecha de nacimiento y foto en
    ~70%), **vínculos familiares** (familias de 5: pareja + 3 hijos con *hijo/
    padre/madre de* y *hermano de*, incluyendo filas inversas), **150 lugares**
    (30 ciudades reales con coordenadas + jitter) y **200 hitos** con **3–7 fotos**
    (media ≈ 5), fecha repartida en ~30 años, categoría/lugar/participantes/tags.
  - `wipeAll()`: borra hitos, lugares, personas (excepto `isMe`) y vínculos.
  - Escrituras en transacciones masivas (`putAll`) directamente sobre Isar.
  - **Imágenes generadas** (degradados JPEG, paleta reutilizable) en
    `app_docs/seed_media/`: **fotos 480×320 px** y **avatares 256×256 px**,
    calidad 80. Se generan en un *pool* (~40 fotos, ~24 avatares) y se
    **reutilizan** por referencia desde hitos/personas (no se crean miles de
    archivos). Se cede el hilo de UI (`Future.delayed(Duration.zero)`) entre
    imágenes para evitar jank.
- **`settings/presentation/pages/settings_page.dart`**: nueva sección
  **"Desarrollo"** (visible solo con el flag) con *Generar datos de demostración*
  (diálogo de confirmación + progreso) y *Borrar datos de demostración*.

Notas: los hitos usan como `userId` el del usuario raíz local (el timeline no
filtra por usuario en modo local). `flutter analyze` del seeder: sin errores.

---

# Sesión 4 (14 jun 2026, tarde) — Correcciones (relaciones, árbol, mapa)

## 1. Gate premium en la ficha de persona
- **`settings/presentation/widgets/person_detail_relationship_tree.dart`**:
  eliminado el `PremiumGatePlaceholder` ("El mapa de relaciones está disponible
  con Premium"); el grafo se muestra siempre.

## 2. Tíos/sobrinos en el árbol genealógico
- **`domain/relationships/relationship_tree_kinship.dart`**: `quadrantForRow` ya
  no devuelve `skip` para tío/tía/sobrino/sobrina:
  - **Tío/Tía** → cuadrante de progenitores (o de hijos si el viewer es el tío).
  - **Sobrino/Sobrina** → cuadrante de hijos (o progenitores si el viewer es el
    sobrino). Añadidas etiquetas cortas "Tío/a" y "Sobrino/a".

## 3. Borrado de la relación recíproca
- **`milestones/presentation/widgets/person_relationships_block.dart`**:
  `_confirmDelete` busca la fila inversa (`RelationshipService.findInverseRow`
  sobre `findInvolvingPerson`) y la borra junto con la original. Texto del
  diálogo actualizado.

## 4. Error del mapa "rendered at least once" al pulsar mi posición
- **`milestones/presentation/utils/map_location_helpers.dart`**: nuevo
  `_moveSafely`. `centerMapOnCurrentLocation` ya no lee `controller.camera` de
  forma insegura: usa el zoom por defecto si la cámara no está disponible y, si
  `move` falla por mapa no renderizado, **reintenta tras el siguiente frame** en
  vez de abortar mostrando "No se pudo obtener tu posición…".

`flutter analyze` de los archivos modificados: sin errores.
