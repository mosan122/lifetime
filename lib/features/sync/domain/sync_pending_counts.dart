/// Elementos pendientes de sincronizar con la nube (Supabase + Drive).
class SyncPendingCounts {
  const SyncPendingCounts({
    this.milestones = 0,
    this.people = 0,
    this.locations = 0,
    this.categories = 0,
    this.relationships = 0,
    this.groups = 0,
    this.mediaItems = 0,
  });

  final int milestones;
  final int people;
  final int locations;
  final int categories;
  final int relationships;
  final int groups;
  /// Fotos y vídeos locales pendientes de subir a Drive.
  final int mediaItems;

  int get total =>
      milestones +
      people +
      locations +
      categories +
      relationships +
      groups +
      mediaItems;

  bool get isEmpty => total == 0;

  /// Filas para la UI «Pendientes de sincronizar» (solo entradas con count > 0).
  List<({String label, int count})> get pendingLines {
    final out = <({String label, int count})>[];
    void add(String label, int n) {
      if (n > 0) out.add((label: label, count: n));
    }

    add('hitos', milestones);
    add('personas', people);
    add('lugares', locations);
    add('características', categories);
    add('relaciones', relationships);
    add('grupos', groups);
    add('imágenes y vídeos', mediaItems);
    return out;
  }
}
