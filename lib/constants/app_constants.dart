import 'package:flutter/material.dart';

class AppConstants {
  static const String appName = 'CampusConnect';
  static const String appTagline = 'Ethiopia Community Marketplace';

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
  static const Color primaryColor = Color(0xFF1E3A8A); // Royal Navy
  static const Color secondaryColor = Color(0xFFF59E0B); // Amber Accent
  static const Color backgroundColor = Color(0xFFF8FAFC);
  static const Color cardColor = Colors.white;

  // Ethiopian Community Locations
  static const List<String> communityLocations = [
    'Addis Ababa - Bole',
    'Addis Ababa - CMC / Ayat',
    'Addis Ababa - Piassa / Arada',
    'Addis Ababa - Kazanchis',
    'Addis Ababa - Sarbet / Mekanisa',
    'Addis Ababa - Megenagna',
    'Addis Ababa - Lebu / Jemo',
    'Addis Ababa - 4 Kilo / 5 Kilo / 6 Kilo',
    'Hawassa',
    'Adama (Nazret)',
    'Bahir Dar',
    'Dire Dawa',
    'Jimma',
    'Mekelle',
    'Bishoftu (Debre Zeyit)',
    'Gondar',
    'University / College Campus',
    'Other Community',
  ];

  // All-Community Marketplace Categories
  static const List<String> categories = [
    'All',
    'Electronics & Phones',
    'Home & Furniture',
    'Fashion & Clothing',
    'Vehicles & Auto',
    'Property & Rentals',
    'Services & Skills',
    'Books & Education',
    'Jobs & Gigs',
    'Free & Donations',
    'Other',
  ];
}
