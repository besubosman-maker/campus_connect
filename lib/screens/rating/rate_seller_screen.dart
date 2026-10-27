import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../constants/app_constants.dart';
import '../../models/listing_model.dart';
import '../../models/user_model.dart';
import '../../providers/auth_provider.dart';
import '../../services/chat_service.dart';
import '../../services/rating_service.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/custom_text_field.dart';
import '../../widgets/rating_stars.dart';

class RateSellerScreen extends StatefulWidget {
  final UserModel seller;
  final ListingModel listing;

  const RateSellerScreen({
    super.key,
    required this.seller,
    required this.listing,
  });

  @override
  State<RateSellerScreen> createState() => _RateSellerScreenState();
}

class _RateSellerScreenState extends State<RateSellerScreen> {
  final RatingService _ratingService = RatingService();
  final ChatService _chatService = ChatService();
  final TextEditingController _commentController = TextEditingController();

  double _stars = 5.0;
  bool _isSubmitting = false;
  bool _hasAlreadyRated = false;
  bool _isChecking = true;

  @override
  void initState() {
    super.initState();
    _checkRatingEligibility();
  }

  void _checkRatingEligibility() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final currentUserId = auth.userModel?.uid;
    if (currentUserId != null) {
      final alreadyRated = await _ratingService.hasUserRatedListing(
        fromUserId: currentUserId,
        listingId: widget.listing.id,
      );
      if (mounted) {
        setState(() {
          _hasAlreadyRated = alreadyRated;
          _isChecking = false;
        });
      }
    } else {
      if (mounted) {
        setState(() {
          _isChecking = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  String _getRatingLabel(double rating) {
    if (rating >= 5.0) return 'Excellent experience!';
    if (rating >= 4.0) return 'Very good experience';
    if (rating >= 3.0) return 'Average experience';
    if (rating >= 2.0) return 'Below expectations';
    return 'Poor experience';
  }

  void _submitRating() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final currentUser = auth.userModel;

    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please log in to submit a review')),
      );
      return;
    }

    if (_hasAlreadyRated) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You have already rated this transaction.')),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      // Validate chat requirement strictly
      final hasChat = await _chatService.hasChatBetweenUsers(
        currentUser.uid,
        widget.seller.uid,
      );

      if (!hasChat) {
        if (mounted) {
          setState(() {
            _isSubmitting = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('A chat message history is required before rating.'),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
        return;
      }

      await _ratingService.submitRating(
        fromUserId: currentUser.uid,
        toUserId: widget.seller.uid,
        listingId: widget.listing.id,
        stars: _stars,
        comment: _commentController.text.trim(),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Thank you! Your seller rating has been submitted.'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to submit rating: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isChecking) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Rate Seller'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Seller avatar
              CircleAvatar(
                radius: 40,
                backgroundColor: AppConstants.primaryColor.withOpacity(0.1),
                backgroundImage: widget.seller.photoUrl != null
                    ? CachedNetworkImageProvider(widget.seller.photoUrl!)
                    : null,
                child: widget.seller.photoUrl == null
                    ? const Icon(Icons.person, size: 44, color: AppConstants.primaryColor)
                    : null,
              ),
              const SizedBox(height: 12),
              Text(
                'How was your experience with ${widget.seller.name}?',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Item: "${widget.listing.title}"',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 28),

              if (_hasAlreadyRated) ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.amber.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.amber.shade900),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'You have already submitted a rating for this item.',
                          style: TextStyle(color: Colors.amber.shade900),
                        ),
                      ),
                    ],
                  ),
                ),
              ] else ...[
                // Star rating selector
                RatingStars(
                  rating: _stars,
                  starSize: 42,
                  isInteractive: true,
                  onRatingChanged: (newRating) {
                    setState(() {
                      _stars = newRating;
                    });
                  },
                ),
                const SizedBox(height: 8),
                Text(
                  _getRatingLabel(_stars),
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppConstants.secondaryColor,
                  ),
                ),
                const SizedBox(height: 28),

                // Review comment
                CustomTextField(
                  controller: _commentController,
                  label: 'Review & Comments (Optional)',
                  hint: 'Was the seller on time? Accurate item description? Polite communication?',
                  maxLines: 4,
                ),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Your honest review helps keep the campus marketplace reliable and trusted.',
                    style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                  ),
                ),
                const SizedBox(height: 32),

                // Submit button
                CustomButton(
                  text: 'Submit Rating',
                  icon: Icons.check_circle_rounded,
                  isLoading: _isSubmitting,
                  onPressed: _submitRating,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
