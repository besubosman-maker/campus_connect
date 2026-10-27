import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

/// Free Cloud Image Service powered by ImgBB.
/// No credit card, no billing account, 100% free cloud image hosting.
class CloudImageService {
  // Replace with your free API key from https://api.imgbb.com/ (takes 10 seconds, zero card required)
  // You can also change this in the app settings or pass via config.
  static String apiKey = 'c906a241b3aa728796440f98be1b703e';

  /// Upload an image to real cloud hosting and return the public CDN URL.
  /// If the cloud API is unreachable, falls back to compressed Base64 Data URI.
  static Future<String> uploadImage(XFile file) async {
    try {
      if (apiKey.isNotEmpty && apiKey != 'YOUR_IMGBB_API_KEY') {
        final uri = Uri.parse('https://api.imgbb.com/1/upload?key=$apiKey');
        final request = http.MultipartRequest('POST', uri);

        if (kIsWeb) {
          final bytes = await file.readAsBytes();
          request.files.add(http.MultipartFile.fromBytes('image', bytes, filename: file.name));
        } else {
          request.files.add(await http.MultipartFile.fromPath('image', file.path));
        }

        final streamed = await request.send().timeout(const Duration(seconds: 15));
        final response = await http.Response.fromStream(streamed);

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          final String? cloudUrl = data['data']?['url'] ?? data['data']?['display_url'];
          if (cloudUrl != null && cloudUrl.isNotEmpty) {
            debugPrint('Cloud image uploaded successfully: $cloudUrl');
            return cloudUrl;
          }
        } else {
          debugPrint('Cloud upload response ${response.statusCode}: ${response.body}');
        }
      }
    } catch (e) {
      debugPrint('Cloud image upload error: $e. Falling back to local data URI.');
    }

    // Reliable fallback: Base64 Data URI stored directly in Firestore
    final bytes = await file.readAsBytes();
    final base64String = base64Encode(bytes);
    return 'data:image/jpeg;base64,$base64String';
  }
}
