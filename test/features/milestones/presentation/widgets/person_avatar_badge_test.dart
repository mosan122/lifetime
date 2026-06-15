import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifetime/features/milestones/presentation/widgets/person_avatar_badge.dart';

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  testWidgets('muestra badge + cuando faceImagePath es null', (tester) async {
    var tapped = false;
    await tester.pumpWidget(_wrap(
      PersonAvatarBadge(
        faceImagePath: null,
        personName: 'Ana',
        onAssignPhoto: () => tapped = true,
      ),
    ));

    expect(find.byIcon(Icons.add), findsOneWidget);

    await tester.tap(find.byIcon(Icons.add));
    expect(tapped, isTrue);
  });

  testWidgets('no muestra badge cuando el archivo existe', (tester) async {
    final tmpFile = File('${Directory.systemTemp.path}/test_face.jpg')
      ..writeAsBytesSync([1, 2, 3]);
    addTearDown(() => tmpFile.deleteSync());

    await tester.pumpWidget(_wrap(
      PersonAvatarBadge(
        faceImagePath: tmpFile.path,
        personName: 'Juan',
        onAssignPhoto: () {},
      ),
    ));

    expect(find.byIcon(Icons.add), findsNothing);
  });

  testWidgets('muestra el nombre de la persona', (tester) async {
    await tester.pumpWidget(_wrap(
      PersonAvatarBadge(
        faceImagePath: null,
        personName: 'María',
        onAssignPhoto: () {},
      ),
    ));

    expect(find.text('María'), findsOneWidget);
  });
}
