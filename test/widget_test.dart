import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cap/main.dart';

void main() {
  testWidgets('App launches smoke test', (WidgetTester tester) async {

    await tester.pumpWidget(const CAPApp());

    expect(find.byType(MaterialApp), findsWidgets);
  });
}
