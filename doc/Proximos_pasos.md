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
