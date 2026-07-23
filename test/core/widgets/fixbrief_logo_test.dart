import 'package:fixbrief/core/widgets/fixbrief_logo.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('renders the canonical logo with accessible semantics', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: FixBriefLogo(size: 72))),
    );

    expect(find.byType(FixBriefLogo), findsOneWidget);
    expect(find.bySemanticsLabel('FixBrief logo'), findsOneWidget);

    final image = tester.widget<Image>(find.byType(Image));
    expect(image.width, 72);
    expect(image.height, 72);
    expect((image.image as AssetImage).assetName, FixBriefLogo.assetPath);
  });
}
