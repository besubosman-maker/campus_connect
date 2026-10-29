import 'package:flutter/material.dart';
import '../../constants/app_constants.dart';
import '../../models/listing_model.dart';
import '../../models/offer_model.dart';
import '../../models/user_model.dart';
import '../../services/offer_service.dart';

class MakeOfferDialog extends StatefulWidget {
  final ListingModel listing;
  final UserModel currentUser;
  final UserModel seller;

  const MakeOfferDialog({
    super.key,
    required this.listing,
    required this.currentUser,
    required this.seller,
  });

  @override
  State<MakeOfferDialog> createState() => _MakeOfferDialogState();
}

class _MakeOfferDialogState extends State<MakeOfferDialog> {
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _noteController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    // Default offer is 10% below listing price
    final defaultOffer = (widget.listing.price * 0.9).roundToDouble();
    _amountController.text = defaultOffer.toStringAsFixed(0);
  }

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  void _applyDiscount(double percentage) {
    final discounted = (widget.listing.price * (1 - percentage)).roundToDouble();
    setState(() {
      _amountController.text = discounted.toStringAsFixed(0);
    });
  }

  Future<void> _handleSubmit() async {
    final amountText = _amountController.text.trim();
    final amount = double.tryParse(amountText);

    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid offer amount in ETB')),
      );
      return;
    }

    if (amount >= widget.listing.price) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Your offer should be less than the current price to bargain')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final offer = OfferModel(
        id: '',
        listingId: widget.listing.id,
        listingTitle: widget.listing.title,
        listingPrice: widget.listing.price,
        listingImage: widget.listing.images.isNotEmpty ? widget.listing.images.first : null,
        buyerId: widget.currentUser.uid,
        buyerName: widget.currentUser.name,
        buyerEmail: widget.currentUser.email,
        sellerId: widget.seller.uid,
        sellerName: widget.seller.name,
        offerAmount: amount,
        buyerNote: _noteController.text.trim().isNotEmpty ? _noteController.text.trim() : null,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await OfferService().submitOffer(offer);

      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '🤝 Offer of ${AppConstants.currencySymbol}$amount submitted to ${widget.seller.name}!',
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to submit offer: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.handshake_rounded, color: AppConstants.secondaryColor, size: 24),
          SizedBox(width: 8),
          Text('Bargain / Make an Offer', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Item: "${widget.listing.title}"',
              style: const TextStyle(fontWeight: FontWeight.bold),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              'Listed Price: ${AppConstants.currencySymbol}${widget.listing.price.toStringAsFixed(2)}',
              style: const TextStyle(color: Colors.grey, fontSize: 13),
            ),
            const SizedBox(height: 14),

            // Quick Discount Chips
            const Text('Quick Bargain Presets:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              children: [
                _buildPresetChip('-5%', 0.05),
                _buildPresetChip('-10%', 0.10),
                _buildPresetChip('-15%', 0.15),
                _buildPresetChip('-20%', 0.20),
              ],
            ),
            const SizedBox(height: 14),

            // Custom Offer Input Field
            TextField(
              controller: _amountController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Your Offered Price (ETB)',
                prefixText: '${AppConstants.currencySymbol} ',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),

            // Optional Note to Seller
            TextField(
              controller: _noteController,
              decoration: const InputDecoration(
                labelText: 'Note to Seller (Optional)',
                hintText: 'e.g. Can meet in Bole today with cash',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSubmitting ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isSubmitting ? null : _handleSubmit,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppConstants.primaryColor,
            foregroundColor: Colors.white,
          ),
          child: _isSubmitting
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
              : const Text('Send Offer 🤝'),
        ),
      ],
    );
  }

  Widget _buildPresetChip(String label, double pct) {
    return ActionChip(
      label: Text(label, style: const TextStyle(fontSize: 11)),
      onPressed: () => _applyDiscount(pct),
      backgroundColor: Colors.amber.shade50,
      side: BorderSide(color: Colors.amber.shade300),
    );
  }
}
