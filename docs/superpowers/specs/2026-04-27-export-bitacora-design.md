# Export Bitácora — Design Spec
Date: 2026-04-27

## Goal
Allow users to export their entire life journal in open formats (JSON for machines, Markdown for humans) and share it via any platform app (email, Telegram, Files).

## Architecture

### Use Case: `ExportBitacoraUseCase`
- Location: `lib/features/milestones/domain/usecases/export_bitacora_usecase.dart`
- Implements `UseCase<ExportResult, NoParams>`
- Calls `MilestoneRepository.getMilestones()` once, maps result to `ExportResult`
- Two **static** formatters — pure functions, zero DI, directly unit-testable:
  - `toJson(List<Milestone>) → String` — pretty-printed JSON v1.0 with metadata
  - `toMarkdown(List<Milestone>) → String` — Obsidian-compatible with YAML frontmatter and Drive links

### Value Object: `ExportResult`
```dart
class ExportResult extends Equatable {
  final String json;
  final String markdown;
}
```

### Cubit: `ExportCubit`
- Location: `lib/features/settings/presentation/bloc/export_cubit.dart`
- States: `ExportIdle → ExportLoading → ExportReady(result) | ExportError(message)`
- Does NOT touch `share_plus` — sharing is a UI side-effect

### UI: `SettingsPage`
- Location: `lib/features/settings/presentation/pages/settings_page.dart`
- Reachable via gear icon in `TimelinePage` AppBar
- **Datos section:** Export tile → triggers cubit → `ExportReady` opens format bottom sheet
  - Format sheet: JSON tile + Markdown tile → `Share.shareXFiles([XFile.fromData(...)])`
  - Filename pattern: `lifetime-bitacora-YYYY-MM-DD.{json|md}`
- **Cuenta section:** Sign-out tile → `AlertDialog` confirmation → `AuthCubit.signOut()` → pop

## JSON Format (v1.0)
```json
{
  "exported_at": "2026-04-27T09:00:00.000Z",
  "version": "1.0",
  "total": 2,
  "milestones": [{
    "id": "...", "title": "...", "description": "...",
    "event_date": "2026-04-26",
    "category": "familia",
    "location": { "name": "Madrid", "latitude": 40.4168, "longitude": -3.7038 },
    "participants": ["Ana"],
    "drive_file_id": "...",
    "created_at": "..."
  }]
}
```
`location` is `null` when both `latitude` and `longitude` are null.

## Markdown Format
```markdown
---
app: LifeTime
export_date: 2026-04-27
total: 2
---

# Mi Bitácora — LifeTime
Exportada el 27/04/2026 · 2 hitos

---

## Mi 30 cumpleaños
📅 26/04/2026 · familia
📍 Madrid (40.4168, -3.7038)
👥 Ana, Luis
📷 [Ver foto](https://drive.google.com/open?id=...)

Fue un día especial...
```
- Location block omitted when no coordinates
- Participants line omitted when empty
- Drive link omitted when `driveFileId` is null

## Sign-Out Flow
Confirmation dialog with "Cancelar" / "Cerrar sesión" buttons.
On confirm: `AuthCubit.signOut()` + `Navigator.pop(context)`.
Copy reads: "¿Desconectar tu Bitácora de Google Drive? Tus hitos no se borrarán."

## Tests
- `export_bitacora_usecase_test.dart` — 35 tests covering toJson, toMarkdown, call, error propagation, ExportResult equality
- `export_cubit_test.dart` — 11 tests covering all states, error paths, equality

Total added: 43 tests → suite total: 206.
