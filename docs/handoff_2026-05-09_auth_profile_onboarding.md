# Handoff para Claude / continuación — Auth, perfil y onboarding (mayo 2026)

Este documento resume lo implementado y lo que debe saber quien retome el trabajo. Complementa `CLAUDE.md` en la raíz del repo.

## Commit de referencia

- **`69aec3e`** — `feat(auth, profile): Supabase, onboarding y participantes en hitos`
- **No entraron en ese commit** (siguen cambios locales si aplica):
  - `.claude/settings.local.json`
  - Submódulo **`LifeTimeApp`** (marcado como modificado / contenido sin trackear dentro del submódulo)

## Qué se hizo (resumen funcional)

### Autenticación (Supabase + Flutter)

- Flujo **email/contraseña** (registro, verificación, login) y preparación para **OAuth** (Google/Apple) vía `AuthService` y `AuthRepositoryImpl`.
- **Conflicto de nombres `AuthUser`**: el dominio define `lib/features/auth/domain/entities/auth_user.dart`. En imports de `package:supabase_flutter/supabase_flutter.dart` usar **`hide AuthUser`** (y en el cubit también **`hide AuthState`** si se usa el de `gotrue` con prefijo `gotrue.AuthState`).
- **Persistencia local de sesión**: Isar (`LocalUserSessionCollection` / `auth_local_persistence.dart`) para reanudar sesión verificada sin red cuando proceda.
- **Deep linking** para auth: `AndroidManifest.xml`, `ios/Runner/Info.plist`, `lib/core/config/supabase_auth_config.dart` (`kSupabaseAuthRedirectUrl`) y `Supabase.initialize` con opciones de cliente OAuth según lo acordado en el proyecto.
- **UI**: `AuthPage`, `LoginPage`, `RegisterPage`, `VerificationPendingPage`, `AuthGate`, validadores en `auth_validators.dart`.
- **Cubit**: `AuthCubit` escucha `onAuthStateChange`, sincroniza con `ProfileRepository`, actualiza `PremiumService`, cache de sesión y flag **`needsOnboarding`**.
- **`saveUserProfile`**: resultado del repositorio se desempaca con **`failSide` / `okSide`** para que `UserProfileDetails` no sea nullable al llamar a `put` y `emit`.

### Perfil y onboarding

- Entidad **`UserProfileDetails`** sustituye el antiguo `Profile` eliminado del dominio de perfil.
- **Remoto**: `ProfileRemoteDataSource` — `profiles` con `display_name`, `first_name`, `last_name`, `birth_date`, `avatar_url`, `last_connection`, etc.
- **Local (Isar)**: `UserProfileLocalDataSource` + `UserProfileCollection` para cache y onboarding offline.
- **Pantallas**: `OnboardingPage`, `ProfilePage`, formulario compartido `UserProfileForm`, prefill OAuth en `onboarding_prefill.dart`.

### Supabase (migraciones en repo)

Aplicar en el proyecto remoto si no estaban ya ejecutadas:

- **`supabase/migrations/20260509120000_profile_onboarding_fields.sql`** — columnas `display_name`, `first_name`, `last_name`, `birth_date`, `last_connection` en `public.profiles`.
- **`supabase/migrations/20260509120100_storage_avatars_bucket.sql`** — bucket `avatars` (revisar **RLS/policies** en producción si la subida de avatar falla).

### Hitos y personas

- **`participantIds`** explícitos en dominio/repositorio; **no** se infieren participantes desde `@` en texto al guardar (sigue la regla del proyecto en `CLAUDE.md`).
- UI: selector de participantes, caras, timeline con acceso a gestión de personas, hojas rápidas de creación de persona donde se añadieron.

### Ajustes

- **`settings_page.dart`**: import de **`manage_locations_page.dart`** para `ManageLocationsPage` (antes fallaba compilación por símbolo no importado).

### Dependencias y plataforma

- `sign_in_with_apple` (y lockfile); `macos/Flutter/GeneratedPluginRegistrant.swift` actualizado.
- **`auth_repository_impl.dart`**: devolver **`Right<Failure, AuthUser>(user)`** donde el tipo lo exija; **`AuthFailure(e.message ?? '', e.code)`** si `message` es nullable.

## Archivos clave (navegación rápida)

| Área | Rutas |
|------|--------|
| Auth | `lib/features/auth/` (data/services, repositories, presentation/bloc, pages, widgets/auth_gate) |
| Config redirect | `lib/core/config/supabase_auth_config.dart` |
| Perfil | `lib/features/profile/` (datasources, repositories, presentation) |
| DI | `lib/injection_container.dart` |
| Entrada app | `lib/main.dart` |
| Migraciones | `supabase/migrations/20260509120000_*.sql`, `20260509120100_*.sql` |

## Pendientes / mejoras (no bloqueantes)

- Opcional: al **renombrar una persona globalmente**, reescribir `@menciones` en hitos existentes (no implementado; mencionado en `CLAUDE.md`).
- Revisar **políticas RLS** del bucket `avatars` y URLs públicas vs signed según diseño de privacidad.
- Submódulo **`LifeTimeApp`**: decidir si commitear cambios internos y actualizar puntero del padre.

## Cómo retomar

1. Leer **`CLAUDE.md`** (reglas de producto: Drive, premium, participantes, diálogos de nombre, etc.).
2. `git log -1` y comparar con remoto; `git status` por si quedó trabajo fuera del commit `69aec3e`.
3. Tras cambiar esquemas Isar: **`dart run build_runner build --delete-conflicting-outputs`** en los paquetes que usen codegen.
4. Tras cambiar SQL: aplicar migraciones en Supabase (Dashboard o CLI).

---

*Generado para continuidad entre sesiones; actualizar este archivo si el estado del repo diverge.*
