import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class LocaleProvider extends ChangeNotifier {
  Locale _locale = const Locale('en');

  Locale get locale => _locale;
  bool get isAmharic => _locale.languageCode == 'am';

  LocaleProvider() {
    _loadUserLocale();
  }

  void _loadUserLocale() {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        FirebaseFirestore.instance.collection('users').doc(user.uid).get().then((doc) {
          if (doc.exists) {
            final lang = doc.data()?['language'] as String?;
            if (lang == 'am') {
              _locale = const Locale('am');
              notifyListeners();
            }
          }
        }).catchError((_) {});
      }
    } catch (_) {}
  }

  void toggleLanguage() {
    if (_locale.languageCode == 'en') {
      setLocale(const Locale('am'));
    } else {
      setLocale(const Locale('en'));
    }
  }

  Future<void> setLocale(Locale loc) async {
    _locale = loc;
    notifyListeners();
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
          'language': loc.languageCode,
        });
      }
    } catch (_) {}
  }

  // Translation dictionary
  static final Map<String, Map<String, String>> _translations = {
    'en': {
      'browse': 'Browse',
      'chats': 'Chats',
      'my_listings': 'My Listings',
      'profile': 'Profile',
      'sell_item': 'Sell Item',
      'search_hint': 'Search electronics, home goods, vehicles, fashion...',
      'all_communities': 'All Communities',
      'featured_deals': '🔥 Featured VIP Deals',
      'saved_favorites': 'Saved Favorites',
      'call_seller': 'Call Seller',
      'telegram_chat': 'Telegram',
      'boost_listing': 'Boost Listing 🚀',
      'id_verified': 'ID Verified',
      'verify_id': 'Verify Identity (Kebele / Student ID)',
      'disputes': 'Disputes',
      'orders': 'Orders',
      'super_admin': 'Super Admin Dashboard',
      'dark_mode': 'Dark / Light Mode',
      'logout': 'Log Out',
      'price': 'Price',
      'category': 'Category',
      'status': 'Status',
    },
    'am': {
      'browse': 'ዕቃዎች',
      'chats': 'መልእክቶች',
      'my_listings': 'የኔ ዕቃዎች',
      'profile': 'መለያዬ',
      'sell_item': 'ዕቃ ሽጥ',
      'search_hint': 'ስልኮች፣ የቤት ዕቃዎች፣ ልብሶች እና መኪናዎችን ፈልግ...',
      'all_communities': 'መላው ኢትዮጵያ',
      'featured_deals': '🔥 ተወዳጅ እና ልዩ ዕቃዎች (VIP)',
      'saved_favorites': 'የተወደዱ ዕቃዎች',
      'call_seller': 'ደውል',
      'telegram_chat': 'ቴሌግራም',
      'boost_listing': 'ዕቃውን አስተዋውቅ (Boost) 🚀',
      'id_verified': 'ማንነቱ የተረጋገጠ',
      'verify_id': 'ማንነት አረጋግጥ (የቀበሌ / ተማሪ መታወቂያ)',
      'disputes': 'ክርክሮች',
      'orders': 'ትዕዛዞች',
      'super_admin': 'ሱፐር አድሚን ዳሽቦርድ',
      'dark_mode': 'ዳርክ / ላይት ሞድ',
      'logout': 'ውጣ',
      'price': 'ዋጋ',
      'category': 'ምድብ',
      'status': 'ሁኔታ',
    },
  };

  String tr(String key) {
    final langCode = _locale.languageCode;
    return _translations[langCode]?[key] ?? _translations['en']?[key] ?? key;
  }
}
