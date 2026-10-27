import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../constants/app_constants.dart';
import '../../models/listing_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/listing_provider.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/custom_text_field.dart';

class CreateListingScreen extends StatefulWidget {
  final ListingModel? existingListing;

  const CreateListingScreen({super.key, this.existingListing});

  @override
  State<CreateListingScreen> createState() => _CreateListingScreenState();
}

class _CreateListingScreenState extends State<CreateListingScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _priceController = TextEditingController();
  final _descriptionController = TextEditingController();
  final ImagePicker _picker = ImagePicker();

  String _selectedCategory = 'Textbooks';
  final List<XFile> _newImages = [];
  List<String> _existingImageUrls = [];
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    if (widget.existingListing != null) {
      final listing = widget.existingListing!;
      _titleController.text = listing.title;
      _priceController.text = listing.price.toStringAsFixed(2);
      _descriptionController.text = listing.description;
      _selectedCategory = listing.category;
      _existingImageUrls = List<String>.from(listing.images);
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _priceController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickImages() async {
    try {
      final List<XFile> picked = await _picker.pickMultiImage(
        maxWidth: 1024,
        imageQuality: 80,
      );

      if (picked.isNotEmpty) {
        setState(() {
          _newImages.addAll(picked);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to pick images: $e')),
        );
      }
    }
  }

  Future<void> _takePhoto() async {
    try {
      final XFile? photo = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1024,
        imageQuality: 80,
      );

      if (photo != null) {
        setState(() {
          _newImages.add(photo);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Camera error: $e')),
        );
      }
    }
  }

  void _showImageSourceDialog() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined, color: AppConstants.primaryColor),
              title: const Text('Choose from Gallery'),
              onTap: () {
                Navigator.pop(ctx);
                _pickImages();
              },
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined, color: AppConstants.primaryColor),
              title: const Text('Take Photo with Camera'),
              onTap: () {
                Navigator.pop(ctx);
                _takePhoto();
              },
            ),
          ],
        ),
      ),
    );
  }

  void _submit() async {
    if (!_formKey.currentState!.validate()) return;

    if (_existingImageUrls.isEmpty && _newImages.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please add at least one photo of your item'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final auth = Provider.of<AuthProvider>(context, listen: false);
    final listingProvider = Provider.of<ListingProvider>(context, listen: false);

    if (auth.userModel == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You must be logged in to post')),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    final price = double.tryParse(_priceController.text.trim()) ?? 0.0;

    bool success;
    if (widget.existingListing != null) {
      success = await listingProvider.updateListing(
        id: widget.existingListing!.id,
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        price: price,
        category: _selectedCategory,
        images: _existingImageUrls,
        newImages: _newImages,
      );
    } else {
      success = await listingProvider.createListing(
        sellerId: auth.userModel!.uid,
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        price: price,
        category: _selectedCategory,
        images: _newImages,
      );
    }

    if (mounted) {
      setState(() {
        _isSubmitting = false;
      });

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.existingListing != null
                ? 'Listing updated successfully!'
                : 'Listing posted successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(listingProvider.errorMessage ?? 'Submission failed'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final availableCategories =
        AppConstants.categories.where((c) => c != 'All').toList();
    final isEditing = widget.existingListing != null;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(isEditing ? 'Edit Listing' : 'Post New Item'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Item Photos',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Upload clear photos (compressed to max 1024px width, 80% quality)',
                  style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                ),
                const SizedBox(height: 12),

                // Horizontal Image Previews
                SizedBox(
                  height: 110,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      // Add Image Button
                      InkWell(
                        onTap: _showImageSourceDialog,
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          width: 110,
                          height: 110,
                          decoration: BoxDecoration(
                            color: Colors.grey[100],
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: AppConstants.primaryColor.withOpacity(0.4),
                              style: BorderStyle.solid,
                            ),
                          ),
                          child: const Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.add_a_photo_outlined,
                                  size: 32, color: AppConstants.primaryColor),
                              SizedBox(height: 6),
                              Text(
                                'Add Photo',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppConstants.primaryColor,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      // Existing image thumbnails
                      ..._existingImageUrls.asMap().entries.map((entry) {
                        final idx = entry.key;
                        final url = entry.value;
                        return Container(
                          margin: const EdgeInsets.only(left: 10),
                          width: 110,
                          height: 110,
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: CachedNetworkImage(
                                  imageUrl: url,
                                  fit: BoxFit.cover,
                                ),
                              ),
                              Positioned(
                                top: 4,
                                right: 4,
                                child: GestureDetector(
                                  onTap: () {
                                    setState(() {
                                      _existingImageUrls.removeAt(idx);
                                    });
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: const BoxDecoration(
                                      color: Colors.black54,
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(Icons.close,
                                        size: 16, color: Colors.white),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }),

                      // New picked local image thumbnails
                      ..._newImages.asMap().entries.map((entry) {
                        final idx = entry.key;
                        final file = entry.value;
                        return Container(
                          margin: const EdgeInsets.only(left: 10),
                          width: 110,
                          height: 110,
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: kIsWeb
                                    ? Image.network(file.path, fit: BoxFit.cover)
                                    : Image.file(File(file.path), fit: BoxFit.cover),
                              ),
                              Positioned(
                                top: 4,
                                right: 4,
                                child: GestureDetector(
                                  onTap: () {
                                    setState(() {
                                      _newImages.removeAt(idx);
                                    });
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: const BoxDecoration(
                                      color: Colors.black54,
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(Icons.close,
                                        size: 16, color: Colors.white),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Title
                CustomTextField(
                  controller: _titleController,
                  label: 'Item Title',
                  hint: 'e.g., Intro to Algorithms Textbook 4th Ed.',
                  prefixIcon: Icons.title_rounded,
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) {
                      return 'Please provide a title';
                    }
                    if (val.trim().length < 4) {
                      return 'Title must be at least 4 characters';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Price and Category Row
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Price
                    Expanded(
                      flex: 4,
                      child: CustomTextField(
                        controller: _priceController,
                        label: 'Price (\$)',
                        hint: '25.00',
                        prefixIcon: Icons.attach_money_rounded,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) {
                            return 'Enter price';
                          }
                          final parsed = double.tryParse(val.trim());
                          if (parsed == null || parsed < 0) {
                            return 'Valid price';
                          }
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 10),

                    // Category Dropdown
                    Expanded(
                      flex: 5,
                      child: DropdownButtonFormField<String>(
                        isExpanded: true,
                        initialValue: _selectedCategory,
                        decoration: InputDecoration(
                          labelText: 'Category',
                          prefixIcon: const Icon(Icons.category_outlined, size: 20),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          filled: true,
                          fillColor: Colors.grey.shade50,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 14),
                        ),
                        items: availableCategories.map((cat) {
                          return DropdownMenuItem(
                            value: cat,
                            child: Text(
                              cat,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 13),
                            ),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setState(() {
                              _selectedCategory = val;
                            });
                          }
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Description
                CustomTextField(
                  controller: _descriptionController,
                  label: 'Description',
                  hint: 'Describe condition, course code, pickup location on campus, etc.',
                  maxLines: 5,
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) {
                      return 'Please provide a description';
                    }
                    if (val.trim().length < 10) {
                      return 'Description must be at least 10 characters';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 32),

                // Submit Button
                CustomButton(
                  text: isEditing ? 'Save Changes' : 'Publish Listing',
                  icon: isEditing ? Icons.save_rounded : Icons.cloud_upload_rounded,
                  isLoading: _isSubmitting,
                  onPressed: _submit,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
