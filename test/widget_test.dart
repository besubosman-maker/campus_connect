import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:campus_connect/constants/app_constants.dart';
import 'package:campus_connect/models/user_model.dart';
import 'package:campus_connect/providers/theme_provider.dart';
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

  test('AppConstants payment methods includes Chapa API', () {
    expect(AppConstants.ethiopianPaymentMethods, contains(AppConstants.paymentChapa));
    expect(AppConstants.ethiopianPaymentMethods, contains(AppConstants.paymentTelebirr));
    expect(AppConstants.ethiopianPaymentMethods, contains(AppConstants.paymentCBE));
  });

  test('UserModel recognizes super_admin role and admin permissions', () {
    final superUser = UserModel(
      uid: 'super-123',
      name: 'Besufikad Osman',
      email: 'besubosman@gmail.com',
      joinedAt: DateTime.now(),
      role: 'super_admin',
    );

    expect(superUser.isSuperAdmin, isTrue);
    expect(superUser.isAdmin, isTrue);

    final normalUser = UserModel(
      uid: 'user-456',
      name: 'Community Buyer',
      email: 'buyer@test.et',
      joinedAt: DateTime.now(),
      role: 'user',
    );

    expect(normalUser.isSuperAdmin, isFalse);
    expect(normalUser.isAdmin, isFalse);
  });

  test('ThemeProvider provides lightTheme and darkTheme configurations', () {
    expect(ThemeProvider.lightTheme.brightness, Brightness.light);
    expect(ThemeProvider.darkTheme.brightness, Brightness.dark);
    expect(ThemeProvider.darkTheme.scaffoldBackgroundColor, const Color(0xFF0F172A));
  });
}
