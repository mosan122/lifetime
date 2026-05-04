# LifeTime - Proyecto de Bitácora Digital

## Visión del Proyecto
LifeTime es una "cápsula del tiempo" que permite registrar hitos de vida (fotos, vídeos, relatos) utilizando el almacenamiento personal del usuario (Google Drive/OneDrive) y una capa de IA biógrafa.

## Stack Tecnológico
- **Frontend:** Flutter (Mobile iOS/Android)
- **Backend:** Supabase (Postgres + Edge Functions)
- **Almacenamiento:** Google Drive API / Microsoft Graph API (OAuth2)
- **IA:** OpenAI GPT-4o / Gemini Flash (Narrativa y Análisis)

## Estructura del Proyecto
- `/lib`: Código fuente Flutter (Clean Architecture)
- `/supabase`: Configuración de base de datos y Edge Functions
- `/assets`: Recursos visuales (minimalistas)
- `.claude/agents`: Definiciones de sub-agentes especializados

## Reglas de Routing de Agentes
1. **Frontend Specialist:** Usar para UI/UX en Flutter, animaciones y diseño minimalista.
2. **Cloud Storage Specialist:** Usar para integraciones con Google Drive, OneDrive y gestión de OAuth2.
3. **The Biographer (IA Agent):** Usar para lógica de prompts de IA, análisis de fotos y redacción de hitos.
4. **Database Guardian:** Usar para esquemas de Supabase, RLS y migraciones SQL.

## Guías de Estilo
- **Diseño:** Minimalismo atemporal (Colores: Crema #F5F5DC, Azul Marino #000080).
- **Código:** SOLID, Clean Architecture, inyección de dependencias.

## Contexto técnico reciente (hitos, Drive, personas)

### Google Drive y sincronización
- Raíz de la app en Drive: carpeta **`LifeTime`** (sin `LifeTime_App`).
- Fotos de **personas** en `LifeTime/People`.
- Medios de hitos en `LifeTime/Media/YYYY/MM/DD`.
- No crear carpeta en Drive si el usuario **no es premium**; la subida en creación de hito debe respetar `PremiumService.isPremium` (no asumir carpeta creada).

### Android: medios locales
- Carpeta pública tipo “galería de app” + notificación al sistema vía **`MediaScanner`** (`MainActivity.kt` canal + `local_media_store_io.dart`).

### Portada en galería del hito
- Elegir **portada** solo en **edición** del hito, no en la pantalla de detalle.
- `galleryCoverIndex` fluye por repositorio, `UpdateMilestoneUseCase`, `EditMilestoneCubit` y UI (pin en sección de medios al editar).

### Participantes del hito (crear / editar)
- **No** se añaden participantes automáticamente por escribir `@` en nota o descripción (ni en UI ni al guardar: `MilestoneRepositoryImpl` solo persiste los `participantIds` explícitos).
- El icono **person_add** junto a las caras abre **`showMilestoneParticipantPickerSheet`** (`milestone_participant_picker_sheet.dart`): lista de contactos no aún en el hito + botón **Crear persona nueva** (Isar + `Uuid`).

### Varias fotos / rendimiento
- Previews con `cacheWidth` / `cacheHeight` acotados; `imageQuality: 72` en multi-pick; importación por lotes con **barra de progreso** y controles deshabilitados mientras importa.

### Gestión de personas (global)
- **Icono** `Icons.groups_outlined` en el `AppBar` del **timeline** (`timeline_page.dart`) abre **`ManagePeoplePage`** con `PeopleCubit` (misma ruta que Ajustes → Gestionar personas: nombres, foto de perfil, borrar foto).
- En **crear/editar hito** (`add_milestone_page.dart`) los participantes se eligen solo con la hoja anterior; foto de perfil por participante sigue en el formulario.

### Pendiente / mejoras posibles
- Opcional: al renombrar una persona globalmente, reescribir `@menciones` en hitos existentes (no implementado).