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