/// Formatea una fecha para mostrar en tarjetas y vistas de detalle de hito.
///
/// Ejemplo: `05 / 06 / 2024`
String formatEventDate(DateTime date) =>
    '${date.day.toString().padLeft(2, '0')} / '
    '${date.month.toString().padLeft(2, '0')} / '
    '${date.year}';
