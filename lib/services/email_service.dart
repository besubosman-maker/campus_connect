import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

class EmailService {
  static String? _encodeQueryParameters(Map<String, String> params) {
    return params.entries
        .map((MapEntry<String, String> e) =>
            '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}')
        .join('&');
  }

  /// Opens the student's native email application (Gmail, Outlook, Samsung Email)
  /// with a pre-formatted subject and body addressed to the seller.
  static Future<bool> launchEmailApp({
    required String recipientEmail,
    required String subject,
    required String body,
  }) async {
    final Uri emailLaunchUri = Uri(
      scheme: 'mailto',
      path: recipientEmail.trim(),
      query: _encodeQueryParameters({
        'subject': subject,
        'body': body,
      }),
    );

    try {
      final launched = await launchUrl(
        emailLaunchUri,
        mode: LaunchMode.externalApplication,
      );
      if (launched) return true;

      return await launchUrl(
        emailLaunchUri,
        mode: LaunchMode.platformDefault,
      );
    } catch (e) {
      debugPrint('Could not launch email app: $e');
      return false;
    }
  }

  /// Sends an automated notification email directly to the seller's inbox when a new order is placed.
  /// Uses a free transactional email endpoint (EmailJS / webhook) so no credit card is required.
  static Future<bool> sendAutomatedEmailNotification({
    required String toEmail,
    required String toName,
    required String fromName,
    required String subject,
    required String message,
  }) async {
    try {
      // Optional EmailJS integration: If configured with your EmailJS credentials, sends directly to inbox
      // https://www.emailjs.com/ (free 200 emails/month, zero credit card)
      const serviceId = 'default_service';
      const templateId = 'campus_connect_order';
      const userId = 'YOUR_EMAILJS_PUBLIC_KEY';

      final url = Uri.parse('https://api.emailjs.com/api/v1.0/email/send');
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'service_id': serviceId,
          'template_id': templateId,
          'user_id': userId,
          'template_params': {
            'to_email': toEmail,
            'to_name': toName,
            'from_name': fromName,
            'subject': subject,
            'message': message,
          },
        }),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        debugPrint('Automated email alert delivered to $toEmail');
        return true;
      }
    } catch (e) {
      debugPrint('Automated email notice: $e');
    }
    return false;
  }
}
