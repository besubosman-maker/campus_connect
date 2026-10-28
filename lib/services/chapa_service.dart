import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import '../models/order_model.dart';
import '../models/user_model.dart';

class ChapaInitializationResult {
  final bool success;
  final String? checkoutUrl;
  final String? txRef;
  final String? errorMessage;

  ChapaInitializationResult({
    required this.success,
    this.checkoutUrl,
    this.txRef,
    this.errorMessage,
  });
}

class ChapaVerificationResult {
  final bool verified;
  final String status;
  final String? paymentMethod;
  final double? amount;
  final String? message;

  ChapaVerificationResult({
    required this.verified,
    required this.status,
    this.paymentMethod,
    this.amount,
    this.message,
  });
}

class ChapaService {
  /// Default Chapa Test Secret Key (Replace with your own live/test key from dashboard.chapa.co)
  /// Format: CHASECK_TEST-xxxxxxxxxxxxxxxxxxxx
  static const String defaultTestKey = 'CHASECK_TEST-38rV4f56G7h8J9k0L1m2N3p4Q5r6S7t8';

  final String secretKey;

  ChapaService({String? customSecretKey})
      : secretKey = customSecretKey ?? defaultTestKey;

  static const String _baseUrl = 'https://api.chapa.co/v1';

  /// Initialize an automated Chapa payment session for an order.
  /// Generates a unique transaction reference and returns the official Chapa checkout URL.
  Future<ChapaInitializationResult> initializePayment({
    required OrderModel order,
    required UserModel buyer,
  }) async {
    final txRef = 'chapa_${order.id.substring(0, order.id.length > 8 ? 8 : order.id.length)}_${DateTime.now().millisecondsSinceEpoch}';
    final names = buyer.name.trim().split(' ');
    final firstName = names.isNotEmpty ? names.first : 'Customer';
    final lastName = names.length > 1 ? names.sublist(1).join(' ') : 'Ethiopia';
    final phone = buyer.phoneNumber != null && buyer.phoneNumber!.trim().isNotEmpty
        ? buyer.phoneNumber!.trim()
        : '0911000000';

    final payload = {
      'amount': order.listingPrice.toStringAsFixed(2),
      'currency': 'ETB',
      'email': buyer.email.isNotEmpty ? buyer.email : 'buyer@campusconnect.et',
      'first_name': firstName,
      'last_name': lastName,
      'phone_number': phone,
      'tx_ref': txRef,
      'callback_url': 'https://api.chapa.co/v1/transaction/verify/$txRef',
      'return_url': 'https://chapa.co',
      'customization': {
        'title': 'CampusConnect Marketplace',
        'description': 'Payment for "${order.listingTitle}" (ETB ${order.listingPrice.toStringAsFixed(2)})',
      },
    };

    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/transaction/initialize'),
        headers: {
          'Authorization': 'Bearer $secretKey',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(payload),
      );

      final data = jsonDecode(response.body) as Map<String, dynamic>? ?? {};

      if (response.statusCode == 200 && data['status'] == 'success') {
        final checkoutUrl = data['data']?['checkout_url'] as String?;
        return ChapaInitializationResult(
          success: true,
          checkoutUrl: checkoutUrl,
          txRef: txRef,
        );
      } else {
        final errorMsg = data['message'] as String? ?? 'Chapa initialization failed (${response.statusCode})';
        debugPrint('Chapa init error: $errorMsg');
        return ChapaInitializationResult(
          success: false,
          txRef: txRef,
          errorMessage: errorMsg,
        );
      }
    } catch (e) {
      debugPrint('Chapa HTTP error: $e');
      return ChapaInitializationResult(
        success: false,
        txRef: txRef,
        errorMessage: 'Network error connecting to Chapa: $e',
      );
    }
  }

  /// Verify a payment with Chapa's official verification endpoint.
  Future<ChapaVerificationResult> verifyPayment(String txRef) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/transaction/verify/$txRef'),
        headers: {
          'Authorization': 'Bearer $secretKey',
          'Content-Type': 'application/json',
        },
      );

      final data = jsonDecode(response.body) as Map<String, dynamic>? ?? {};

      if (response.statusCode == 200 && data['status'] == 'success') {
        final transactionData = data['data'] as Map<String, dynamic>? ?? {};
        final paymentStatus = (transactionData['status'] as String? ?? '').toLowerCase();
        final method = transactionData['method'] as String? ?? 'Chapa Gateway';
        final amount = (transactionData['amount'] as num?)?.toDouble();

        final isSuccess = paymentStatus == 'success';

        return ChapaVerificationResult(
          verified: isSuccess,
          status: paymentStatus,
          paymentMethod: method,
          amount: amount,
          message: isSuccess
              ? 'Payment successfully verified via Chapa ($method)!'
              : 'Payment status: $paymentStatus',
        );
      } else {
        final msg = data['message'] as String? ?? 'Transaction verification pending or not found';
        return ChapaVerificationResult(
          verified: false,
          status: 'pending',
          message: msg,
        );
      }
    } catch (e) {
      debugPrint('Chapa verify error: $e');
      return ChapaVerificationResult(
        verified: false,
        status: 'error',
        message: 'Could not verify payment: $e',
      );
    }
  }

  /// Open the Chapa hosted checkout URL in-app or in the system browser.
  static Future<bool> openCheckout(String checkoutUrl) async {
    final uri = Uri.parse(checkoutUrl);
    try {
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.inAppBrowserView,
      );
      if (launched) return true;

      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      debugPrint('Could not launch Chapa checkout URL: $e');
      return await launchUrl(uri, mode: LaunchMode.platformDefault);
    }
  }
}
