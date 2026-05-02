import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifetime/features/milestones/data/models/local/media_item_embed.dart';
import 'package:lifetime/domain/entities/media_item.dart';
import 'package:lifetime/features/milestones/presentation/widgets/face_source_bottom_sheet.dart';

MediaItemEmbed _makeImageItem(String path) {
  return MediaItemEmbed()
    ..localPath = path
    ..thumbnailPath = path
    ..mediaType = MediaType.image;
}

MediaItemEmbed _makeVideoItem(String path) {
  return MediaItemEmbed()
    ..localPath = path
    ..thumbnailPath = path
    ..mediaType = MediaType.video;
}

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  testWidgets('siempre muestra botones Cámara y Galería', (tester) async {
    await tester.pumpWidget(_wrap(
      Builder(builder: (ctx) {
        return ElevatedButton(
          onPressed: () => showFaceSourceBottomSheet(context: ctx),
          child: const Text('open'),
        );
      }),
    ));

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('Cámara'), findsOneWidget);
    expect(find.text('Galería'), findsOneWidget);
  });

  testWidgets('muestra sección de hito cuando se pasan mediaItems con imágenes',
      (tester) async {
    final items = [_makeImageItem('/path/a.jpg'), _makeImageItem('/path/b.jpg')];

    await tester.pumpWidget(_wrap(
      Builder(builder: (ctx) {
        return ElevatedButton(
          onPressed: () =>
              showFaceSourceBottomSheet(context: ctx, milestoneMediaItems: items),
          child: const Text('open'),
        );
      }),
    ));

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('Imágenes del hito'), findsOneWidget);
  });

  testWidgets('no muestra sección de hito cuando solo hay vídeos', (tester) async {
    final items = [_makeVideoItem('/path/v.mp4')];

    await tester.pumpWidget(_wrap(
      Builder(builder: (ctx) {
        return ElevatedButton(
          onPressed: () =>
              showFaceSourceBottomSheet(context: ctx, milestoneMediaItems: items),
          child: const Text('open'),
        );
      }),
    ));

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('Imágenes del hito'), findsNothing);
  });

  testWidgets('no muestra sección de hito cuando milestoneMediaItems es null',
      (tester) async {
    await tester.pumpWidget(_wrap(
      Builder(builder: (ctx) {
        return ElevatedButton(
          onPressed: () => showFaceSourceBottomSheet(context: ctx),
          child: const Text('open'),
        );
      }),
    ));

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('Imágenes del hito'), findsNothing);
  });
}
