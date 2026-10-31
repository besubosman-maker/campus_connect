import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../constants/app_constants.dart';
import '../../models/user_model.dart';
import '../../providers/locale_provider.dart';
import '../../services/cloud_image_service.dart';
import '../../services/marketplace_extension_service.dart';
import '../../services/notification_service.dart';

class VerifyIdDialog extends StatefulWidget {
  final UserModel user;

  const VerifyIdDialog({super.key, required this.user});

  @override
  State<VerifyIdDialog> createState() => _VerifyIdDialogState();
}

class _VerifyIdDialogState extends State<VerifyIdDialog> {
  final ImagePicker _picker = ImagePicker();
  XFile? _selectedImage;
  String _idType = 'University / Student ID';
  final TextEditingController _idNumberController = TextEditingController();
  bool _isUploading = false;

  final List<String> _idTypes = [
    'University / Student ID',
    'Kebele ID Card',
    'National ID (Fayda / ዲጂታል መታወቂያ)',
    'Passport / Driver License',
  ];

  @override
  void dispose() {
    _idNumberController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final picked = await _picker.pickImage(
        source: source,
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 80,
      );
      if (picked != null) {
        setState(() {
          _selectedImage = picked;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to pick document image: $e')),
        );
      }
    }
  }

  Future<void> _submitVerification() async {
    if (_selectedImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select or capture a photo of your ID card.')),
      );
      return;
    }

    setState(() {
      _isUploading = true;
    });

    try {
      // Upload document image to cloud or base64 fallback
      final imageUrl = await CloudImageService.uploadImage(_selectedImage!);

      await MarketplaceExtensionService().submitIdVerification(
        uid: widget.user.uid,
        idDocumentUrl: imageUrl,
      );

      // In-app notification for the user
      await NotificationService().sendNotification(
        userId: widget.user.uid,
        title: '🛡️ ID Verification Submitted',
        body: 'Your $_idType has been submitted for review. An administrator will verify your profile shortly.',
        type: 'announcement',
      );

      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ ID Document submitted! Super Admin will review your profile shortly.'),
            backgroundColor: Color(0xFF059669),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isUploading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Verification submission failed: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final locale = Provider.of<LocaleProvider>(context);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppConstants.primaryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.verified_user_rounded, color: AppConstants.primaryColor, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          locale.isAmharic ? 'የመታወቂያ ማረጋገጫ' : 'Verify Identity (መታወቂያ)',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        Text(
                          locale.isAmharic
                              ? 'የተረጋገጠ ተማሪ/ሻጭ ባጅ ለማግኘት መታወቂያዎን ይላኩ'
                              : 'Earn a verified badge to build high buyer trust',
                          style: TextStyle(fontSize: 11.5, color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const Divider(height: 24),

              // ID Document Type Selector
              Text(
                locale.isAmharic ? 'የመታወቂያ ዓይነት' : 'Document Type',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    isExpanded: true,
                    value: _idType,
                    items: _idTypes.map((type) {
                      return DropdownMenuItem(
                        value: type,
                        child: Text(type, style: const TextStyle(fontSize: 13.5)),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) setState(() => _idType = val);
                    },
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // Document ID Number
              Text(
                locale.isAmharic ? 'የመታወቂያ ቁጥር (ከተፈለገ)' : 'ID / Student Number (Optional)',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _idNumberController,
                decoration: InputDecoration(
                  hintText: 'e.g. UGR/12345/14 or Kebele ID',
                  hintStyle: TextStyle(color: Colors.grey[400], fontSize: 13),
                  isDense: true,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                ),
              ),
              const SizedBox(height: 16),

              // Document Photo Upload Area
              Text(
                locale.isAmharic ? 'የመታወቂያ ፎቶ' : 'Photo of ID Card',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              const SizedBox(height: 8),

              if (_selectedImage != null)
                Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: kIsWeb
                          ? Image.network(
                              _selectedImage!.path,
                              height: 170,
                              width: double.infinity,
                              fit: BoxFit.cover,
                            )
                          : Image.file(
                              File(_selectedImage!.path),
                              height: 170,
                              width: double.infinity,
                              fit: BoxFit.cover,
                            ),
                    ),
                    Positioned(
                      top: 8,
                      right: 8,
                      child: InkWell(
                        onTap: () => setState(() => _selectedImage = null),
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.close, color: Colors.white, size: 16),
                        ),
                      ),
                    ),
                  ],
                )
              else
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.camera_alt_outlined, size: 18),
                        label: Text(locale.isAmharic ? 'ፎቶ አንሳ' : 'Camera'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppConstants.primaryColor,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: () => _pickImage(ImageSource.camera),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.photo_library_outlined, size: 18),
                        label: Text(locale.isAmharic ? 'ከጋለሪ ምረጥ' : 'Gallery'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppConstants.primaryColor,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: () => _pickImage(ImageSource.gallery),
                      ),
                    ),
                  ],
                ),
              const SizedBox(height: 14),

              // Trust statement
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.shield_outlined, color: AppConstants.primaryColor, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        locale.isAmharic
                            ? 'መረጃዎ የተጠበቀ ነው። ለሱፐር አድሚን ብቻ የሚታይ ሲሆን ለሕዝብ አይወጣም።'
                            : 'Documents are confidential and encrypted. Only platform admins review for verification.',
                        style: TextStyle(fontSize: 11, color: Colors.blue.shade900),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Action Buttons
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: _isUploading ? null : () => Navigator.pop(context),
                      child: Text(locale.isAmharic ? 'ተው' : 'Cancel'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppConstants.primaryColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: _isUploading ? null : _submitVerification,
                      child: _isUploading
                          ? const SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : Text(
                              locale.isAmharic ? 'መታወቂያ ላክ' : 'Submit Verification',
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
