# LifeTime — notas de implementación (continuidad)

Documento para retomar trabajo en otra sesión. Resume cambios estructurales y rutas de código relevantes.

---

## 1. Categorías de hitos (biográficas + seeds)

- **Lista canónica en Dart**: `lib/core/constants/milestone_category_seeds.dart` (`kMilestoneCategorySeeds`).
- **Paleta de iconos + `defaultCategories` derivadas**: `lib/core/constants/milestone_categories.dart` (`kCategoryIconPalette`, incluye `category_filled`, `celebration`, `moving` → `Icons.local_shipping`, etc.).
- **Referencia JSON** (no cargado en runtime): `data/default_milestone_categories.json` (versión 2, categorías biográficas).
- **Isar seed + migración suave**: `lib/features/milestones/data/datasources/isar_category_datasource.dart` — si la BD ya tiene categorías, **inserta solo las que falten** por `id` (p. ej. `boda`) sin borrar datos.
- **Web**: `injection_container.dart` → `_WebCategoryDataSource` añade categorías faltantes igual que en móvil.

---

## 2. Perfil vs. personas (fuente de verdad + UI)

- **Ocultar “yo” en listas de personas**: `lib/core/utils/person_ui_filters.dart` — `withoutLinkedCurrentUser` (excluye `linkedUserId` = usuario Supabase actual).
- **`PeopleCubit.reload()`**: aplica el filtro antes de emitir `PeopleLoaded`.
- **Selector de participantes en hitos**: `milestone_participant_picker_sheet.dart` usa el mismo filtro.
- **Ajustes → cumpleaños**: `settings_page.dart` — cumpleaños de contactos sin la ficha vinculada; **el del usuario** sale desde **`ProfileRepository`** / perfil (`_UpcomingBirthdaysTile` con `Future` cacheado en `StatefulWidget`).
- **Tras guardar “Mi perfil” con foto**: `profile_repository_impl.dart` sincroniza cara en `faces/{personId}.jpg`, upsert `PersonCollection` vinculada, `PeopleFacesRevisionNotifier.bump()`. **DI**: `ProfileRepositoryImpl` recibe también `IsarPersonDataSource`, `UserProfileLocalDataSource`, `PeopleFacesRevisionNotifier` (`injection_container.dart`).

---

## 3. Relaciones entre personas (Isar + UI)

### Modelo y persistencia

- **Isar**: `lib/features/milestones/data/models/local/relationship_collection.dart` + `.g.dart` (generado con `build_runner`).
- **Esquema registrado** en `Isar.open(...)` en `injection_container.dart` (ambas variantes de apertura).
- **Datasource**: `lib/features/milestones/data/datasources/isar_relationship_datasource.dart` (`findInvolvingPerson`, `put`, `deleteById`).
- **Web / sin Isar**: `_WebRelationshipDataSource` en `injection_container.dart` (lista en memoria).
- **Servicio**: `lib/features/milestones/domain/services/relationship_service.dart` — construye filas (`Uuid`), guarda y aplica reciprocidad.

### Tipos y reciprocidad

- **Códigos y etiquetas**: `lib/domain/relationships/relationship_type_codes.dart` — `RelationshipTypeCodes.pickerOrdered` **sin** `es_amigo_de` en nuevas relaciones; filas legacy con `es_amigo_de` se muestran como “Conexión con / Conexión: …”.
- **Planes de espejo**: `lib/domain/relationships/relationship_reciprocity.dart` — `RelationshipMirrorMode` / `planMirrorForType` (padre/madre → hijo; hijo/hija → elegir padre/madre; abuelo/a ↔ nieto/a; hermano/pareja/cónyuge simétrico; `otro` sin espejo; `es_amigo_de` sin espejo automático).

### UI edición de persona

- **`EditPersonPage`**: `TabController`, pestañas **General** / **Relaciones**; en pestaña Relaciones el **AppBar** muestra nombre para mostrar + subtítulo “Relaciones”.
- **`EditPersonRelationsTab`**: `lib/features/settings/presentation/widgets/edit_person_relations_tab.dart` — recibe `subject` + `displayName`; flujo: **foto + buscador** → **Aceptar** → **dos fotos + icono de vínculo** → tipo, fechas, Guardar; listado inferior con `PersonRelationshipsBlock`.
- **Ficha en lista de personas**: `manage_people_page.dart` — bloque `PersonRelationshipsBlock` en la hoja inferior.
- **Resumen de vínculos**: `lib/features/milestones/presentation/widgets/person_relationships_block.dart` — secciones Principales / Otras / Pasadas.

### Pendientes / mejoras posibles

- **Género** en `Person` o perfil para elegir `es_hijo_de` vs `es_hija_de` en espejos (hoy se usa `es_hijo_de` por defecto en plan padre→hijo).
- **Migración Isar** al añadir `RelationshipCollection`: usuarios con BD antigua pueden necesitar reinstalar o política de bump de versión de esquema Isar.
- **Sincronización en la nube** de relaciones: explícitamente no implementada (solo local).

---

## 4. Archivos tocados con frecuencia

| Área | Archivos |
|------|-----------|
| Categorías | `milestone_category_seeds.dart`, `milestone_categories.dart`, `isar_category_datasource.dart`, `data/default_milestone_categories.json` |
| Personas / perfil | `person_ui_filters.dart`, `people_cubit.dart`, `profile_repository_impl.dart`, `injection_container.dart`, `settings_page.dart` |
| Relaciones | `relationship_collection.dart`, `relationship_type_codes.dart`, `relationship_reciprocity.dart`, `isar_relationship_datasource.dart`, `relationship_service.dart`, `edit_person_page.dart`, `edit_person_relations_tab.dart`, `person_relationships_block.dart`, `manage_people_page.dart` |

---

*Última actualización coherente con el estado del repo al redactar este archivo (sesión de relaciones, categorías biográficas, perfil/personas).*
