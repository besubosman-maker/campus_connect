import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:campus_connect/constants/app_constants.dart';
import 'package:campus_connect/models/listing_model.dart';
import 'package:campus_connect/models/user_model.dart';
import 'package:campus_connect/models/offer_model.dart';
import 'package:campus_connect/models/listing_question_model.dart';
import 'package:campus_connect/models/item_request_model.dart';
import 'package:campus_connect/models/message_model.dart';
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

  test('OfferModel computes status states correctly', () {
    final offer = OfferModel(
      id: 'offer-1',
      listingId: 'listing-1',
      listingTitle: 'Calculus 9th Edition',
      listingPrice: 1000,
      buyerId: 'buyer-1',
      buyerName: 'Abebe',
      buyerEmail: 'abebe@campus.et',
      sellerId: 'seller-1',
      sellerName: 'Kebede',
      offerAmount: 800,
      status: 'pending',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    expect(offer.isPending, isTrue);
    expect(offer.isAccepted, isFalse);
    expect(offer.offerAmount, 800);
  });

  test('ListingQuestionModel recognizes answered questions', () {
    final question = ListingQuestionModel(
      id: 'q-1',
      listingId: 'listing-1',
      askerId: 'buyer-1',
      askerName: 'Sara',
      question: 'Is battery health above 85%?',
      sellerId: 'seller-1',
      answer: 'Yes, it is 91%',
      createdAt: DateTime.now(),
    );

    expect(question.isAnswered, isTrue);
    expect(question.answer, contains('91%'));
  });

  test('ItemRequestModel recognizes open requests and budget', () {
    final request = ItemRequestModel(
      id: 'req-1',
      userId: 'user-1',
      userName: 'Dawit',
      userEmail: 'dawit@campus.et',
      title: 'Dorm Kettle',
      description: 'Need a boiling kettle for Block 24',
      category: 'Dorm & Room Essentials',
      budgetETB: 650,
      campusLocation: 'Block 24',
      createdAt: DateTime.now(),
    );

    expect(request.isOpen, isTrue);
    expect(request.budgetETB, 650);
  });

  test('MessageModel supports image and voice media types', () {
    final voiceMsg = MessageModel(
      id: 'm-1',
      senderId: 'user-1',
      text: 'ዋጋ ይቀነሳል?',
      sentAt: DateTime.now(),
      type: 'voice',
      durationSeconds: 6,
    );

    expect(voiceMsg.isVoice, isTrue);
    expect(voiceMsg.isImage, isFalse);
    expect(voiceMsg.durationSeconds, 6);

    final imageMsg = MessageModel(
      id: 'm-2',
      senderId: 'user-1',
      text: 'Front view photo',
      sentAt: DateTime.now(),
      type: 'image',
      mediaUrl: 'data:image/jpeg;base64,...',
    );

    expect(imageMsg.isImage, isTrue);
    expect(imageMsg.isVoice, isFalse);
  });
}
