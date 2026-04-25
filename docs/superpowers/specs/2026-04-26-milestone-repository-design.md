# Milestone Repository — Diseño

**Fecha:** 2026-04-26
**Scope:** Capa de datos para Milestones: entidad de dominio, interfaz del repositorio, datasource remoto e implementación del repositorio.
**Enfoque elegido:** Clean Architecture — Datasource + Repository (Opción B).

---

## 1. Estructura de archivos

```
lib/
├── domain/
│   ├── entities/
│   │   ├── milestone.dart
│   │   └── media_asset_entity.dart
│   ├── repositories/
│   │   └── milestone_repository.dart
│   └── failures/
│       └── failure.dart
├── data/
│   ├── models/
│   │   ├── milestone_model.dart
│   │   └── media_asset_model.dart
│   ├── datasources/
│   │   └── milestone_remote_datasource.dart
│   └── repositories/
│       └── milestone_repository_impl.dart
```

---

## 2. Entidades de dominio

### `Milestone`

| Campo | Tipo Dart | Origen |
|---|---|---|
| `id` | `String` | Supabase `gen_random_uuid()` |
| `userId` | `String` | Auth session |
| `title` | `String` | Edge Function response |
| `description` | `String?` | Edge Function response (`narrative`) |
| `participants` | `List<String>` | Entrada del usuario (nombres/IDs) |
| `media` | `List<MediaAssetEntity>` | Join con `media_assets` o carga posterior |
| `eventDate` | `DateTime` | Parámetro de entrada |
| `locationName` | `String?` | Parámetro de entrada |
| `latitude` | `double?` | Parámetro de entrada (WKT en DB) |
| `longitude` | `double?` | Parámetro de entrada (WKT en DB) |
| `category` | `String` | Parámetro de entrada (default `'general'`) |
| `isPublic` | `bool` | Parámetro de entrada (default `false`) |
| `createdAt` | `DateTime` | Supabase `NOW()` |

### `MediaAssetEntity`

| Campo | Tipo Dart | Origen |
|---|---|---|
| `id` | `String` | Supabase |
| `milestoneId` | `String` | FK a `milestones` |
| `cloudFileId` | `String` | ID de Google Drive / OneDrive |
| `thumbnailUrl` | `String?` | URL pública o firmada |
| `mediaType` | `String` | `'image'`, `'video'`, `'audio'` |
| `metadata` | `Map<String, dynamic>?` | Datos EXIF, dimensiones, etc. |
| `createdAt` | `DateTime` | Supabase |

### Nota de schema: `participants`

La columna `participants TEXT[]` debe añadirse a la tabla `milestones`. Migración SQL necesaria:

```sql
ALTER TABLE milestones ADD COLUMN participants TEXT[] DEFAULT '{}';
```

---

## 3. Interfaz del repositorio (domain layer)

```dart
abstract class MilestoneRepository {
  Future<Either<Failure, Milestone>> createMilestone({
    required String userNote,
    required DateTime eventDate,
    String? locationName,
    double? latitude,
    double? longitude,
    String category = 'general',
    List<String> participants = const [],
    bool isPublic = false,
  });

  Future<Either<Failure, List<Milestone>>> getMilestones();
  Future<Either<Failure, Milestone>> getMilestoneById(String id);
}
```

La interfaz no importa nada de Supabase. Depende únicamente de `Failure` y `Milestone` (domain).

---

## 4. Contrato del datasource remoto

### Métodos

| Método | Responsabilidad |
|---|---|
| `callBiographerNarrative(String note, DateTime date, String? location)` | `POST /functions/v1/biographer-narrative` → `{title, narrative}` |
| `insertMilestone(MilestoneModel model)` | `INSERT INTO milestones` → fila completa |
| `fetchMilestones(String userId)` | `SELECT` con join a `media_assets` |
| `fetchMilestoneById(String id)` | `SELECT` por id con join a `media_assets` |

### Contrato Edge Function

**Request:**
```json
{
  "metadata": { "date": "ISO8601", "location": "nombre_lugar_o_null" },
  "userNote": "texto libre del usuario"
}
```

**Response:**
```json
{
  "title": "Título generado por Gemini",
  "narrative": "Relato generado por Gemini"
}
```

### Coordenadas geográficas

Si `latitude` y `longitude` están presentes, se construye la cadena WKT:
```
POINT(longitude latitude)
```
PostgREST acepta este formato directamente para columnas `GEOGRAPHY(POINT)`.

---

## 5. Flujo de `createMilestone`

```
UI / Use Case
    │
    ▼
MilestoneRepositoryImpl.createMilestone(...)
    │
    ├─1─▶ datasource.callBiographerNarrative(userNote, eventDate, locationName)
    │         POST /functions/v1/biographer-narrative
    │         ← { title, narrative }
    │
    ├─2─▶ Construye MilestoneModel:
    │         title       ← de Edge Function
    │         description ← narrative de Edge Function
    │         location_coords ← "POINT(lng lat)" si lat/lng presentes
    │         participants, category, isPublic ← parámetros de entrada
    │
    ├─3─▶ datasource.insertMilestone(model)
    │         INSERT INTO milestones → Supabase devuelve fila completa
    │
    └─4─▶ MilestoneModel.toEntity() → Milestone
              Either.right(milestone)
```

---

## 6. Manejo de errores

| Excepción capturada | `Failure` devuelto |
|---|---|
| `AuthException` (Supabase) | `AuthFailure` |
| `PostgrestException` | `DatabaseFailure(message)` |
| `HttpException` / timeout (Edge Function) | `NetworkFailure` |
| Respuesta Edge Function sin `title` o `narrative` | `BiographerFailure` |

Todos los errores se capturan en `MilestoneRepositoryImpl` y se devuelven como `Either.left(failure)`. El datasource lanza excepciones; el repositorio las convierte.

---

## 7. Dependencias Flutter necesarias

```yaml
dependencies:
  supabase_flutter: ^2.x
  dartz: ^0.10.x        # Either / Option
  equatable: ^2.x       # Value equality en entidades
```

---

## 8. Decisiones de diseño

- **`media` en `createMilestone`:** devuelve lista vacía. Los `MediaAsset` se crean en un flujo separado (upload a Drive/OneDrive → insert en `media_assets`).
- **`participants`:** `List<String>` para nombres o IDs simples. Puede evolucionar a `List<PersonEntity>` sin cambiar la interfaz del repositorio.
- **Auth:** el `userId` se obtiene de `supabase.auth.currentUser!.id` dentro del datasource. El repositorio no gestiona sesiones.
- **No Use Cases en este scope:** el repositorio es la unidad pedida. Los Use Cases se añaden cuando la presentación lo requiera.
