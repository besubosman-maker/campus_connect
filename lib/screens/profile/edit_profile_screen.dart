import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../constants/app_constants.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/app_image_helper.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/custom_text_field.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _phoneController;
  late TextEditingController _telebirrController;
  late TextEditingController _cbeAccountController;
  late TextEditingController _cbeNameController;
  String _preferredPayment = AppConstants.paymentTelebirr;

  final ImagePicker _picker = ImagePicker();
  XFile? _selectedImage;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final user = auth.userModel;

    _nameController = TextEditingController(text: user?.name ?? '');
    _phoneController = TextEditingController(text: user?.phoneNumber ?? '');
    _telebirrController = TextEditingController(text: user?.telebirrNumber ?? '');
    _cbeAccountController = TextEditingController(text: user?.cbeAccount ?? '');
    _cbeNameController = TextEditingController(text: user?.cbeAccountName ?? '');

    if (user?.preferredPayment != null &&
        AppConstants.ethiopianPaymentMethods.contains(user!.preferredPayment)) {
      _preferredPayment = user.preferredPayment!;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _telebirrController.dispose();
    _cbeAccountController.dispose();
    _cbeNameController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final picked = await _picker.pickImage(
        source: source,
        maxWidth: 300,
        maxHeight: 300,
        imageQuality: 75,
      );
      if (picked != null) {
        setState(() {
          _selectedImage = picked;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to pick image: $e')),
        );
      }
    }
  }

  void _showImagePickerModal() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library, color: AppConstants.primaryColor),
              title: const Text('Choose from Gallery'),
              onTap: () {
                Navigator.pop(ctx);
                _pickImage(ImageSource.gallery);
              },
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt, color: AppConstants.primaryColor),
              title: const Text('Take a Photo'),
              onTap: () {
                Navigator.pop(ctx);
                _pickImage(ImageSource.camera);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSaving = true;
    });

    final auth = Provider.of<AuthProvider>(context, listen: false);

    bool photoSuccess = true;
    if (_selectedImage != null) {
      photoSuccess = await auth.uploadProfilePhoto(_selectedImage!);
    }

    final updateSuccess = await auth.updateProfile(
      name: _nameController.text.trim(),
      phoneNumber: _phoneController.text.trim(),
      telebirrNumber: _telebirrController.text.trim(),
      cbeAccount: _cbeAccountController.text.trim(),
      cbeAccountName: _cbeNameController.text.trim(),
      preferredPayment: _preferredPayment,
    );

    if (mounted) {
      setState(() {
        _isSaving = false;
      });

      if (photoSuccess && updateSuccess) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile and Ethiopian payment info updated! 🎉'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(auth.errorMessage ?? 'Failed to update profile. Please try again.'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final user = auth.userModel;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Edit Profile & Payment'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Avatar with Camera Overlay
                Center(
                  child: Stack(
                    children: [
                      CircleAvatar(
                        radius: 54,
                        backgroundColor: AppConstants.primaryColor.withOpacity(0.1),
                        backgroundImage: _selectedImage != null
                            ? (kIsWeb
                                ? NetworkImage(_selectedImage!.path) as ImageProvider
                                : FileImage(File(_selectedImage!.path)))
                            : (user?.photoUrl != null
                                ? AppImageHelper.getImageProvider(user!.photoUrl!)
                                : null),
                        child: (_selectedImage == null && user?.photoUrl == null)
                            ? const Icon(Icons.person, size: 60, color: AppConstants.primaryColor)
                            : null,
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: InkWell(
                          onTap: _showImagePickerModal,
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: const BoxDecoration(
                              color: AppConstants.primaryColor,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.camera_alt,
                              size: 18,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Personal Details Section
                const Text(
                  'Account Information',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 12),

                // Name field
                CustomTextField(
                  controller: _nameController,
                  label: 'Full Name',
                  prefixIcon: Icons.person_outline,
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) {
                      return 'Name cannot be empty';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 14),

                // Phone field
                CustomTextField(
                  controller: _phoneController,
                  label: 'Phone Number (Ethiopian e.g. 09...)',
                  prefixIcon: Icons.phone_outlined,
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 14),

                // Email field (read-only)
                TextFormField(
                  initialValue: user?.email ?? '',
                  readOnly: true,
                  decoration: InputDecoration(
                    labelText: 'Email Address',
                    prefixIcon: const Icon(Icons.email_outlined),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    filled: true,
                    fillColor: Colors.grey[100],
                    helperText: 'Account email cannot be changed',
                  ),
                ),
                const SizedBox(height: 28),

                // Ethiopian Payment Configuration Card
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade50.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.amber.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.payments_outlined, color: Colors.amber.shade900),
                          const SizedBox(width: 8),
                          Text(
                            'Ethiopian Payment Methods (ክፍያ)',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: Colors.amber.shade900,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Set your Telebirr and CBE details so buyers can pay you directly.',
                        style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                      ),
                      const Divider(height: 24),

                      // Preferred Payment Method
                      const Text(
                        'Preferred Payout Method',
                        style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                      ),
                      const SizedBox(height: 6),
                      DropdownButtonFormField<String>(
                        value: _preferredPayment,
                        isExpanded: true,
                        decoration: InputDecoration(
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          filled: true,
                          fillColor: Colors.white,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                        items: AppConstants.ethiopianPaymentMethods.map((m) {
                          return DropdownMenuItem(value: m, child: Text(m, style: const TextStyle(fontSize: 13)));
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) setState(() => _preferredPayment = val);
                        },
                      ),
                      const SizedBox(height: 14),

                      // Telebirr Phone Number
                      CustomTextField(
                        controller: _telebirrController,
                        label: 'Telebirr Phone Number (ቴሌብር ቁጥር)',
                        prefixIcon: Icons.phone_android,
                        keyboardType: TextInputType.phone,
                        helperText: 'e.g. 0912345678 - buyers send money to this number',
                      ),
                      const SizedBox(height: 14),

                      // CBE Account Number
                      CustomTextField(
                        controller: _cbeAccountController,
                        label: 'CBE Account Number (የኢትዮጵያ ንግድ ባንክ)',
                        prefixIcon: Icons.account_balance,
                        keyboardType: TextInputType.number,
                        helperText: 'Commercial Bank of Ethiopia 13-digit account',
                      ),
                      const SizedBox(height: 14),

                      // CBE Account Name
                      CustomTextField(
                        controller: _cbeNameController,
                        label: 'CBE Account Holder Name',
                        prefixIcon: Icons.badge_outlined,
                        helperText: 'Exact name registered on your CBE account',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),

                // Save button
                CustomButton(
                  text: 'Save Changes',
                  isLoading: _isSaving,
                  onPressed: _saveProfile,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
