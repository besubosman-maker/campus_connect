import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:campus_connect/constants/app_constants.dart';
import 'package:campus_connect/models/listing_model.dart';
import 'package:campus_connect/models/user_model.dart';
import 'package:campus_connect/providers/locale_provider.dart';
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

  test('UserModel recognizes super_admin role and ID verification status', () {
    final superUser = UserModel(
      uid: 'super-123',
      name: 'Besufikad Osman',
      email: 'besubosman@gmail.com',
      joinedAt: DateTime.now(),
      role: 'super_admin',
      idVerificationStatus: 'verified',
    );

    expect(superUser.isSuperAdmin, isTrue);
    expect(superUser.isAdmin, isTrue);
    expect(superUser.isIdVerified, isTrue);

    final normalUser = UserModel(
      uid: 'user-456',
      name: 'Community Buyer',
      email: 'buyer@test.et',
      joinedAt: DateTime.now(),
      role: 'user',
      idVerificationStatus: 'pending',
    );

    expect(normalUser.isSuperAdmin, isFalse);
    expect(normalUser.isAdmin, isFalse);
    expect(normalUser.isIdVerified, isFalse);
  });

  test('ListingModel recognizes active VIP boost', () {
    final boostedItem = ListingModel(
      id: 'boost-1',
      sellerId: 'user-1',
      title: 'iPhone 15 Pro Max',
      description: 'Clean phone',
      price: 95000,
      category: 'Electronics & Phones',
      images: [],
      createdAt: DateTime.now(),
      searchKeywords: [],
      isFeatured: true,
      featuredUntil: DateTime.now().add(const Duration(days: 3)),
    );

    expect(boostedItem.isBoostedActive, isTrue);

    final expiredItem = ListingModel(
      id: 'boost-2',
      sellerId: 'user-1',
      title: 'Old Table',
      description: 'Used',
      price: 1500,
      category: 'Home & Furniture',
      images: [],
      createdAt: DateTime.now(),
      searchKeywords: [],
      isFeatured: true,
      featuredUntil: DateTime.now().subtract(const Duration(days: 1)),
    );

    expect(expiredItem.isBoostedActive, isFalse);
  });

  test('LocaleProvider translates correctly between English and Amharic', () {
    final provider = LocaleProvider();
    expect(provider.tr('browse'), 'Browse');
    expect(provider.tr('sell_item'), 'Sell Item');

    provider.setLocale(const Locale('am'));
    expect(provider.isAmharic, isTrue);
    expect(provider.tr('browse'), 'ዕቃዎች');
    expect(provider.tr('sell_item'), 'ዕቃ ሽጥ');
  });

  test('ThemeProvider provides lightTheme and darkTheme configurations', () {
    expect(ThemeProvider.lightTheme.brightness, Brightness.light);
    expect(ThemeProvider.darkTheme.brightness, Brightness.dark);
    expect(ThemeProvider.darkTheme.scaffoldBackgroundColor, const Color(0xFF0F172A));
  });
}
