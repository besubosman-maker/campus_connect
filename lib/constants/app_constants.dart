import 'package:flutter/material.dart';

class AppConstants {
  static const String appName = 'CampusConnect';

  // Ethiopian Currency Constants
  static const String currencyCode = 'ETB';
  static const String currencySymbol = 'ETB ';

  // Ethiopian Payment Methods
  static const String paymentTelebirr = 'Telebirr (ቴሌብር)';
  static const String paymentCBE = 'CBE / CBE Birr (ንግድ ባንክ)';
  static const String paymentCash = 'Cash on Meetup (በእጅ ጥሬ ገንዘብ)';
  static const String paymentBOA = 'Bank of Abyssinia (አቢሲኒያ)';

  static const List<String> ethiopianPaymentMethods = [
    paymentTelebirr,
    paymentCBE,
    paymentCash,
    paymentBOA,
  ];

  // Primary Theme Colors
  static const Color primaryColor = Color(0xFF1E3A8A); // Collegiate Navy
  static const Color secondaryColor = Color(0xFFF59E0B); // Amber Accent
  static const Color backgroundColor = Color(0xFFF8FAFC);
  static const Color cardColor = Colors.white;

  // Marketplace Categories
  static const List<String> categories = [
    'All',
    'Textbooks',
    'Electronics',
    'Furniture',
    'Clothing',
    'School Supplies',
    'Housing',
    'Services',
    'Other',
  ];
}
