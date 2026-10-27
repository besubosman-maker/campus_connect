import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:campus_connect/constants/app_constants.dart';
import 'package:campus_connect/widgets/rating_stars.dart';

void main() {
  testWidgets('RatingStars displays correct rating and count', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: RatingStars(
            rating: 4.5,
            count: 12,
          ),
        ),
      ),
    );

    // Verify rating text and review count are rendered
    expect(find.text('4.5'), findsOneWidget);
    expect(find.text('(12)'), findsOneWidget);
  });

  test('AppConstants categories includes expected community categories', () {
    expect(AppConstants.categories, contains('Electronics & Phones'));
    expect(AppConstants.categories, contains('Home & Furniture'));
    expect(AppConstants.categories, contains('Books & Education'));
    expect(AppConstants.categories, contains('Vehicles & Auto'));
  });
}
