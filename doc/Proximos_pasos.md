Verificar cómo se guardan los archivos de media: imagenes, Videos y miniaturas. tanto en local como en la nube.
Existe una par… *(texto pendiente)*

---

## Registro de trabajo (referencia)

### Drive y premium
- Raíz **`LifeTime`** en Google Drive; personas `LifeTime/People`; medios `LifeTime/Media/YYYY/MM/DD`.
- No crear carpeta en Drive si no hay **premium** (`PremiumService.isPremium`).

### Android
- **MediaScanner** + canal en **`MainActivity.kt`**; **`local_media_store_io.dart`** para exponer medios en galería del sistema.

### Hitos UI
- **Portada de galería** solo en **edición** del hito (`galleryCoverIndex` en cubit/repositorio).
- **Participantes**: solo desde icono **person_add** → hoja **`milestone_participant_picker_sheet`** (elegir contacto o **crear nueva**). No sync automático desde `@` en la nota/descripción.
- **Repositorio**: `participantIds` solo explícitos (sin merge por menciones al guardar).

### Personas (global)
- **Timeline** → icono grupos → **`ManagePeoplePage`** (como Ajustes).
- **FAB** y estado vacío con botón para primera persona.

### Diálogo nombre (crash Android)
- Archivo **`person_name_alert_dialog.dart`**: controller en estado del diálogo; unfocus + `finishAutofillContext` + pop en post-frame; `autofillHints: []`; `barrierDismissible: false`; `useRootNavigator` desde bottom sheet.

### Tests
- **`milestone_repository_impl_test`**: `categoryId`, `participantIds`, expectativas de título por descripción y de `update` con dominio `Milestone`.

### Repo Git
- Commit reciente en **`main`** con el conjunto de cambios (excluyendo `.claude/settings.local.json`, submódulo **LifeTimeApp** sin consolidar, carpeta **`doc/`** sin trackear salvo este archivo si se añade).

---

## Últimos cambios (timeline, categorías, lugares)

### Timeline agrupado por año
- Reemplazado `ListView` por `CustomScrollView` con `SliverPersistentHeader` (cabeceras sticky por año) y `SliverList` (lazy).
- Cabecera de año limpia, con fondo suave (`surfaceContainerHighest`) y año en negrita.
- FAB pequeño (`calendar_month_outlined`) que abre un índice de años; al tocar un año hace scroll automático a la cabecera de ese año.

### Categorías dinámicas
- `CategoryCollection` en Isar: `id` (string estable), `name`, `iconCode`, `colorValue`.
- `IsarCategoryDataSource.ensureSeeded()` inicializa la colección desde `defaultCategories` si está vacía (incluido fallback web).
- `ManageCategoriesPage`: crear/editar/borrar categorías (nombre libre, icono y color).
- `AddMilestonePage` carga las categorías desde Isar (`_loadCategories` + `_CategorySelector`); ya no usa directamente la lista fija de constantes.
- `_CategoryChip` en `timeline_page.dart` consulta primero Isar y, si no encuentra, cae en `defaultCategories` como fallback para compatibilidad.

### Lugares guardados y “mis lugares”
- Nueva colección Isar `SavedLocationCollection` con `name`, `city`, `country`, `latitude`, `longitude` + `IsarSavedLocationDataSource` (y versión web en memoria).
- `ManageLocationsPage` en Ajustes → “Lugares”: lista de sitios guardados con opción de renombrar o borrar; estado vacío con copy explicando el flujo.
- `SettingsPage`: “Gestionar personas” pasa a llamarse “Personas” y se añaden “Lugares” y “Categorías” en la sección **Tus datos**.

### Campo Lugar en Add/Edit Milestone
- El `TextField` de Lugar es el nombre principal (personalizable) del sitio (ej. “Casa de los tíos”).
- Al seleccionar una ubicación desde buscador/mapa:
  - Si el campo está vacío → se rellena con el nombre devuelto por el servicio.
  - Si ya tiene texto → se conserva el texto y solo se actualizan los metadatos (`city`, `country`, `latitude`, `longitude`) en `MilestoneLocationData`.
- En la UI (tarjetas y timeline) se usa el formato `Nombre • Ciudad, País` (`locationName` + `locationCity`/`locationCountry`).
- `_PlacePickerSheet`:
  - Sección **“Mis lugares”** (desde `SavedLocationCollection`) y **“Sitios recientes”** (desde `IsarMilestoneDataSource.fetchRecentLocations`).
  - Al tocar un lugar de cualquiera de las dos secciones se devuelve un `MilestoneLocationData` completo al formulario.
- En Add/Edit aparece un toggle **“Guardar en mis lugares”** cuando hay un lugar seleccionado:
  - Si el guardado/edición del hito termina en éxito y el toggle está activo, se persiste un `SavedLocationCollection` con el nombre (personalizado) y sus metadatos.

---

## Debug / estado actual (Isar codegen, proxy, categorías dinámicas)

### Problema: faltaban `.g.dart` de Isar
- Aparecieron errores tipo:
  - `saved_location_collection.g.dart` no existe
  - `SavedLocationCollectionSchema` no definido
  - `_isar.savedLocationCollections` no existe
  - `category_collection.g.dart` desincronizado con el modelo
- Causa: `build_runner` no estaba generando (y además `flutter pub get` se quedaba colgado).

### Fix: `flutter pub get` colgado por proxy local
- `flutter pub get` fallaba con `ClientException ... address = 127.0.0.1` (proxy apuntando a localhost).
- Solución: limpiar variables de entorno de proxy (`HTTP_PROXY`, `HTTPS_PROXY`, `ALL_PROXY`, `NO_PROXY`) y reintentar.
- Tras esto, `flutter pub get` volvió a descargar paquetes correctamente.

### Codegen: `build_runner` volvió a funcionar
- Ejecutado `dart run build_runner build --delete-conflicting-outputs`.
- Generó de nuevo los `.g.dart` y esquemas de Isar (incluido `SavedLocationCollection`).

### Nuevo bloqueo: Release build y tree-shake de iconos
- `flutter build apk` en Release falló con:
  - “This application cannot tree shake icons fonts. It has non-constant instances of IconData…”
- Motivo: usar `IconData(codePoint, fontFamily: 'MaterialIcons')` (dinámico) para representar iconos guardados como `iconCode`.

### Decisión acordada
- Para mantener Release builds y tree-shake, las categorías dinámicas deben guardar el icono como **`iconName`** (string) y mapearlo a un set cerrado de `IconData` constantes en UI.
- Estado: se aceptó el cambio (“ok”) y el siguiente paso es migrar `CategoryCollection` a `iconName` y ajustar seed/UI/selector/timeline.
