import 'package:flutter/material.dart';

import '../../../../core/services/storage_usage_service.dart';
import '../../../../core/theme/app_theme.dart';

/// Muestra cuánto almacenamiento consume la app: total, imágenes, vídeos y datos.
class StorageUsagePage extends StatefulWidget {
  const StorageUsagePage({super.key});

  @override
  State<StorageUsagePage> createState() => _StorageUsagePageState();
}

class _StorageUsagePageState extends State<StorageUsagePage> {
  final _service = StorageUsageService();
  late Future<StorageUsage> _future;

  @override
  void initState() {
    super.initState();
    _future = _service.compute();
  }

  void _refresh() => setState(() => _future = _service.compute());

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.cream,
      appBar: AppBar(
        title: const Text('Almacenamiento'),
        actions: [
          IconButton(
            tooltip: 'Actualizar',
            icon: const Icon(Icons.refresh),
            onPressed: _refresh,
          ),
        ],
      ),
      body: FutureBuilder<StorageUsage>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final usage = snapshot.data ?? StorageUsage.empty;
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
            children: [
              _TotalCard(usage: usage),
              const SizedBox(height: 20),
              _UsageBar(usage: usage),
              const SizedBox(height: 24),
              _UsageRow(
                color: _imageColor,
                icon: Icons.photo_outlined,
                label: 'Imágenes',
                bytes: usage.imageBytes,
                count: usage.imageCount,
                countNoun: 'archivo',
              ),
              _UsageRow(
                color: _videoColor,
                icon: Icons.movie_outlined,
                label: 'Vídeos',
                bytes: usage.videoBytes,
                count: usage.videoCount,
                countNoun: 'archivo',
              ),
              _UsageRow(
                color: _dataColor,
                icon: Icons.storage_outlined,
                label: 'Datos y caché',
                bytes: usage.dataBytes,
                count: usage.otherCount,
                countNoun: 'archivo',
              ),
              const SizedBox(height: 24),
              Text(
                'Incluye fotos, vídeos y miniaturas guardados en el dispositivo, '
                'la base de datos local y otros archivos de la app. No refleja el '
                'espacio ocupado en la nube.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.black54,
                    ),
              ),
            ],
          );
        },
      ),
    );
  }
}

const _imageColor = Color(0xFF2A9D8F);
const _videoColor = Color(0xFFE76F51);
const _dataColor = Color(0xFF457B9D);

class _TotalCard extends StatelessWidget {
  const _TotalCard({required this.usage});
  final StorageUsage usage;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
      decoration: BoxDecoration(
        color: AppTheme.navy,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Text(
            'Espacio usado por la app',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: AppTheme.cream.withValues(alpha: 0.85),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            formatBytes(usage.totalBytes),
            style: theme.textTheme.displaySmall?.copyWith(
              color: AppTheme.cream,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _UsageBar extends StatelessWidget {
  const _UsageBar({required this.usage});
  final StorageUsage usage;

  @override
  Widget build(BuildContext context) {
    final total = usage.totalBytes;
    if (total <= 0) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Container(
          height: 14,
          color: Colors.black.withValues(alpha: 0.06),
        ),
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(
        height: 14,
        child: Row(
          children: [
            if (usage.imageBytes > 0)
              Expanded(
                flex: usage.imageBytes,
                child: const ColoredBox(color: _imageColor),
              ),
            if (usage.videoBytes > 0)
              Expanded(
                flex: usage.videoBytes,
                child: const ColoredBox(color: _videoColor),
              ),
            if (usage.dataBytes > 0)
              Expanded(
                flex: usage.dataBytes,
                child: const ColoredBox(color: _dataColor),
              ),
          ],
        ),
      ),
    );
  }
}

class _UsageRow extends StatelessWidget {
  const _UsageRow({
    required this.color,
    required this.icon,
    required this.label,
    required this.bytes,
    required this.count,
    required this.countNoun,
  });

  final Color color;
  final IconData icon;
  final String label;
  final int bytes;
  final int count;
  final String countNoun;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppTheme.navy,
                  ),
                ),
                Text(
                  '$count $countNoun${count == 1 ? '' : 's'}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.black54,
                  ),
                ),
              ],
            ),
          ),
          Text(
            formatBytes(bytes),
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: AppTheme.navy,
            ),
          ),
        ],
      ),
    );
  }
}
