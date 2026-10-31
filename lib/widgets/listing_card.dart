import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../constants/app_constants.dart';
import '../models/listing_model.dart';
import '../providers/auth_provider.dart';
import '../services/marketplace_extension_service.dart';
import 'app_image_helper.dart';

class ListingCard extends StatefulWidget {
  final ListingModel listing;
  final VoidCallback onTap;

  const ListingCard({
    super.key,
    required this.listing,
    required this.onTap,
  });

  @override
  State<ListingCard> createState() => _ListingCardState();
}

class _ListingCardState extends State<ListingCard> {
  bool _isTogglingFav = false;

  @override
  Widget build(BuildContext context) {
    final currencyFormatter = NumberFormat.currency(
      symbol: AppConstants.currencySymbol,
      decimalDigits: 0,
    );
    final listing = widget.listing;
    final hasImages = listing.images.isNotEmpty;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final auth = Provider.of<AuthProvider>(context);
    final currentUser = auth.userModel;
    final isFavorite = currentUser != null && currentUser.favorites.contains(listing.id);

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark
              ? (listing.isBoostedActive ? Colors.amber.withOpacity(0.5) : const Color(0xFF334155))
              : (listing.isBoostedActive ? Colors.amber.shade300 : Colors.black.withOpacity(0.06)),
          width: listing.isBoostedActive ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: listing.isBoostedActive
                ? Colors.amber.withOpacity(0.18)
                : (isDark ? Colors.black45 : Colors.black.withOpacity(0.04)),
            blurRadius: listing.isBoostedActive ? 16 : 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: widget.onTap,
          borderRadius: BorderRadius.circular(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Image Stack with badges & quick favorite
              Expanded(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (hasImages)
                      AppImageHelper.buildImage(
                        imageUrl: listing.images.first,
                        fit: BoxFit.cover,
                        placeholder: Container(
                          color: isDark ? const Color(0xFF0F172A) : Colors.grey[200],
                          child: const Center(
                            child: SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          ),
                        ),
                        errorWidget: Container(
                          color: isDark ? const Color(0xFF0F172A) : Colors.grey[100],
                          child: const Icon(Icons.broken_image_rounded, size: 36, color: Colors.grey),
                        ),
                      )
                    else
                      Container(
                        color: isDark ? const Color(0xFF0F172A) : Colors.grey[100],
                        child: const Icon(Icons.shopping_bag_outlined, size: 42, color: Colors.grey),
                      ),

                    // Subtle Bottom Gradient Vignette for clear contrast
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      height: 50,
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              Colors.black.withOpacity(0.55),
                            ],
                          ),
                        ),
                      ),
                    ),

                    // VIP Featured Badge (Top-Left)
                    if (listing.isBoostedActive)
                      Positioned(
                        top: 8,
                        left: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFFF59E0B), Color(0xFFD97706)],
                            ),
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.2),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.bolt_rounded, size: 12, color: Colors.white),
                              SizedBox(width: 2),
                              Text(
                                'VIP',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                    // Quick Favorite Heart Button (Top-Right)
                    Positioned(
                      top: 6,
                      right: 6,
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: _isTogglingFav || currentUser == null
                              ? null
                              : () async {
                                  setState(() => _isTogglingFav = true);
                                  final newStatus = await MarketplaceExtensionService().toggleFavorite(
                                    uid: currentUser.uid,
                                    listingId: listing.id,
                                    isCurrentlyFavorite: isFavorite,
                                  );
                                  if (mounted) {
                                    setState(() {
                                      _isTogglingFav = false;
                                      if (newStatus) {
                                        if (!currentUser.favorites.contains(listing.id)) {
                                          currentUser.favorites.add(listing.id);
                                        }
                                      } else {
                                        currentUser.favorites.remove(listing.id);
                                      }
                                    });
                                  }
                                },
                          borderRadius: BorderRadius.circular(20),
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.4),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              isFavorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                              size: 16,
                              color: isFavorite ? Colors.redAccent : Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ),

                    // Category Frosted Tag (Bottom-Left)
                    Positioned(
                      bottom: 6,
                      left: 6,
                      right: 6,
                      child: Row(
                        children: [
                          Flexible(
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.6),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                listing.category,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Sold Overlay
                    if (listing.isSold)
                      Container(
                        color: Colors.black.withOpacity(0.65),
                        child: Center(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.redAccent,
                              borderRadius: BorderRadius.circular(8),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.3),
                                  blurRadius: 6,
                                ),
                              ],
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.check_circle_outline, size: 12, color: Colors.white),
                                SizedBox(width: 4),
                                Text(
                                  'SOLD',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 11,
                                    letterSpacing: 1.0,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),

              // Listing Details
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      listing.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13.5,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 5),

                    // Location tag if available
                    Row(
                      children: [
                        Icon(
                          Icons.location_on_outlined,
                          size: 11,
                          color: isDark ? Colors.grey[400] : Colors.grey[600],
                        ),
                        const SizedBox(width: 2),
                        Expanded(
                          child: Text(
                            'Campus Meetup',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 10.5,
                              color: isDark ? Colors.grey[400] : Colors.grey[600],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),

                    // Price and Date Row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFF059669).withOpacity(isDark ? 0.2 : 0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            currencyFormatter.format(listing.price),
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF059669),
                            ),
                          ),
                        ),
                        Text(
                          DateFormat('MMM d').format(listing.createdAt),
                          style: TextStyle(
                            fontSize: 10.5,
                            color: isDark ? Colors.grey[500] : Colors.grey[400],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
