import 'package:flutter/material.dart';
import '../../constants/app_constants.dart';
import '../../models/listing_model.dart';
import '../../services/marketplace_extension_service.dart';

class BoostListingDialog extends StatefulWidget {
  final ListingModel listing;

  const BoostListingDialog({super.key, required this.listing});

  @override
  State<BoostListingDialog> createState() => _BoostListingDialogState();
}

class _BoostListingDialogState extends State<BoostListingDialog> {
  int _selectedDays = 3;
  double _price = 50.0;
  String _paymentMethod = AppConstants.paymentChapa;
  bool _isLoading = false;

  void _updatePlan(int days, double price) {
    setState(() {
      _selectedDays = days;
      _price = price;
    });
  }

  Future<void> _handleBoost() async {
    setState(() {
      _isLoading = true;
    });

    try {
      await MarketplaceExtensionService().boostListing(
        listingId: widget.listing.id,
        days: _selectedDays,
        paymentMethod: _paymentMethod,
      );

      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '🎉 "${widget.listing.title}" is now BOOSTED for $_selectedDays days! It will appear in top VIP spots.',
            ),
            backgroundColor: Colors.amber.shade900,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to boost: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: Colors.amber.shade100,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.rocket_launch_rounded, color: Colors.amber, size: 22),
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'Boost Listing (VIP Promo)',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Promote "${widget.listing.title}" to the top VIP Carousel on the home screen to get up to 5x more buyers!',
              style: TextStyle(fontSize: 13, color: Colors.grey[700]),
            ),
            const SizedBox(height: 16),

            // Plan 1: 3 Days
            InkWell(
              onTap: () => _updatePlan(3, 50.0),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _selectedDays == 3 ? Colors.amber.shade800 : Colors.grey.shade300,
                    width: _selectedDays == 3 ? 2 : 1,
                  ),
                  color: _selectedDays == 3 ? Colors.amber.shade50 : null,
                ),
                child: Row(
                  children: [
                    Radio<int>(
                      value: 3,
                      groupValue: _selectedDays,
                      activeColor: Colors.amber.shade900,
                      onChanged: (v) => _updatePlan(3, 50.0),
                    ),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('3 Days Standard VIP Boost', style: TextStyle(fontWeight: FontWeight.bold)),
                          Text('Pinned to top VIP deals', style: TextStyle(fontSize: 11, color: Colors.grey)),
                        ],
                      ),
                    ),
                    Text(
                      '50 ETB',
                      style: TextStyle(fontWeight: FontWeight.bold, color: Colors.amber.shade900),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),

            // Plan 2: 7 Days
            InkWell(
              onTap: () => _updatePlan(7, 100.0),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _selectedDays == 7 ? Colors.amber.shade800 : Colors.grey.shade300,
                    width: _selectedDays == 7 ? 2 : 1,
                  ),
                  color: _selectedDays == 7 ? Colors.amber.shade50 : null,
                ),
                child: Row(
                  children: [
                    Radio<int>(
                      value: 7,
                      groupValue: _selectedDays,
                      activeColor: Colors.amber.shade900,
                      onChanged: (v) => _updatePlan(7, 100.0),
                    ),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('7 Days Mega VIP Boost (Best Value)', style: TextStyle(fontWeight: FontWeight.bold)),
                          Text('Top placement for a full week', style: TextStyle(fontSize: 11, color: Colors.grey)),
                        ],
                      ),
                    ),
                    Text(
                      '100 ETB',
                      style: TextStyle(fontWeight: FontWeight.bold, color: Colors.amber.shade900),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Payment Channel Selector
            const Text(
              'Payment Method (የክፍያ አማራጭ):',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            DropdownButtonFormField<String>(
              value: _paymentMethod,
              decoration: const InputDecoration(
                contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(
                  value: AppConstants.paymentChapa,
                  child: Text('Chapa Online (Telebirr / CBE / Card)', style: TextStyle(fontSize: 12)),
                ),
                DropdownMenuItem(
                  value: AppConstants.paymentTelebirr,
                  child: Text('Telebirr Direct (*127#)', style: TextStyle(fontSize: 12)),
                ),
                DropdownMenuItem(
                  value: AppConstants.paymentCBE,
                  child: Text('CBE Birr (*847#)', style: TextStyle(fontSize: 12)),
                ),
              ],
              onChanged: (v) {
                if (v != null) {
                  setState(() {
                    _paymentMethod = v;
                  });
                }
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _handleBoost,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFD97706),
            foregroundColor: Colors.white,
          ),
          child: _isLoading
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : Text('Pay ${_price.toStringAsFixed(0)} ETB & Boost 🚀'),
        ),
      ],
    );
  }
}
